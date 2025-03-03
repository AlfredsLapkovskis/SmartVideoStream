//
//  SessionManager.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 05/01/2025.
//

import Foundation
import Combine


@MainActor
class SessionManager : ObservableObject {

    @Published private(set) var state: State = .disconnected
    @Published private(set) var streamSettings = Config.initialStreamSettings
    @Published private(set) var slos = Config.initialSlos
    @Published private(set) var streams: [Int : VideoStream] = [:]
    
    private var task: URLSessionWebSocketTask?
    
    private let url: URL
    private let messageCoder = MessageCoder()
    private let metricsManager = MetricsManager()
    
    private var cancellables: Set<AnyCancellable> = []
    
    enum State : Int, Comparable {
        case disconnected
        case connecting
        case connectionFailed
        case connected
        case disconnecting
        
        static func < (lhs: SessionManager.State, rhs: SessionManager.State) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    init(_ url: URL) {
        self.url = url
        
        metricsManager.setSettings(streamSettings)
        beginSendingMetrics()
    }

    func connect() {
        guard state == .disconnected else { return }
        
        state = .connecting
        
        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        
        Task {
            do {
                try await send(OutMessageConnect(
                    settings: streamSettings,
                    slos: slos
                ))
            } catch {
                cancelTask(failed: true)
            }
        }
        Task {
            await listen()
        }
    }
    
    func disconnect() {
        guard state == .connected else { return }
        
        if let task {
            Task {
                try? await send(OutMessageDisconnect())
                try? await Task.sleep(for: .seconds(5))
                if task === self.task {
                    cancelTask()
                }
            }
        } else {
            print("No task found to disconnect")
            state = .disconnected
        }
    }
    
    func notifyStreamSizesChanged(_ sizes: [CGFloat]) {
        metricsManager.setStreamSizes(sizes)
    }
    
    func resetError() {
        guard state == .connectionFailed else { return }
        
        state = .disconnected
    }

    private func listen() async {
        guard let task else { return }
        
        while true {
            do {
                let rawMessage = try await task.receive()
                
                switch rawMessage {
                case .data(let data):
                    if let message = messageCoder.decodeInMessage(data) {
                        handleMessage(message)
                    } else {
                        print("Failed to decode an inbound message: data=\(data)")
                    }
                case .string(let string):
                    print("Unsupported message type: string=\(string)")
                @unknown default:
                    print("Unsupported message type: \(rawMessage)")
                }
            } catch {
                cancelTask(failed: state == .connecting)
                break
            }
        }
    }
    
    private func handleMessage(_ message: InMessage) {
        if let message = message as? InMessageConnect {
            handleConnect(message)
        } else if let message = message as? InMessageDisconnect {
            handleDisconnect(message)
        } else if let message = message as? InMessageError {
            handleError(message)
        } else if let message = message as? InMessageFrame {
            handleFrame(message)
        } else if let message = message as? InMessageSuggestSettings {
            handleSuggestSettings(message)
        } else {
            print("Unhandled message: \(message)")
        }
    }
    
    private func beginSendingMetrics() {
        metricsManager.computedMetrics
            .collect(.byTime(DispatchQueue.main, .seconds(1)))
            .filter { !$0.isEmpty }
            .map { metrics in
                var metricsSplitBySettings = [[Metrics]]()
                var currentSplit = [Metrics]()
                for metric in metrics {
                    if currentSplit.isEmpty || metric.settingId == currentSplit.last!.settingId {
                        currentSplit.append(metric)
                    } else {
                        metricsSplitBySettings.append(currentSplit)
                        currentSplit = [metric]
                    }
                }
                metricsSplitBySettings.append(currentSplit)
                return metricsSplitBySettings.map { m in
                    let count = Double(m.count)
                    return Metrics(
                        settingId: m.last!.settingId,
                        cpuUsage: m.reduce(into: 0.0) { $0 += $1.cpuUsage } / count,
                        memoryUsage: m.reduce(into: 0.0) { $0 += $1.memoryUsage } / count,
                        networkUsage: m.reduce(into: 0.0) { $0 += $1.networkUsage } / count,
                        averageActualFps: m.reduce(into: 0.0) { $0 += $1.averageActualFps } / count,
                        averageRenderScaleFactor: m.reduce(into: 0.0) { $0 += $1.averageRenderScaleFactor } / count,
                        thermalState: m.max(by: { $0.thermalState.rawValue < $1.thermalState.rawValue })!.thermalState
                    )
                }
            }
            .collect(Config.metricBatchSize)
            .map { $0.flatMap { $0 } }
            .sink { [weak self] metrics in
                Task {
                    do {
                        print("Send metrics=\(metrics)")
                        try await self?.send(OutMessageMetrics(batchOfMetrics: metrics))
                    } catch {
                        print("Failed to send metrics: \(error)")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleConnect(_ message: InMessageConnect) {
        if state == .connecting {
            state = .connected
            
            streams = (0..<streamSettings.numberOfStreams).reduce(into: [:]) { $0[$1] = VideoStream(stream: $1) }
        } else {
            print("Unexpected state for connect: \(state)")
        }
    }
    
    private func handleDisconnect(_ message: InMessageDisconnect) {
        if state == .connected || state == .disconnecting {
            cancelTask()
        } else {
            print("Unexpected state for disconnect: \(state)")
        }
    }
    
    private func handleError(_ message: InMessageError) {
        print("Server Error: code=\(message.code), message=\(message.message)")
    }
    
    private func handleFrame(_ message: InMessageFrame) {
        guard let stream = streams[message.stream] else { return }
        
        metricsManager.didReceiveFrameMessage(message)
        stream.didReceiveFrameMessage(message)
    }
    
    private func handleSuggestSettings(_ message: InMessageSuggestSettings) {
        guard let settings = message.settings?.copyWithId(),
            !settings.equalWithoutId(self.streamSettings) else { return }
        
        let prevNumberOfStreams = self.streamSettings.numberOfStreams
        let currentNumberOfStreams = settings.numberOfStreams
        
        if prevNumberOfStreams > currentNumberOfStreams {
            let diff = prevNumberOfStreams - currentNumberOfStreams
            for stream in (prevNumberOfStreams - diff)..<prevNumberOfStreams {
                self.streams.removeValue(forKey: stream)
            }
        } else if prevNumberOfStreams < currentNumberOfStreams {
            for stream in prevNumberOfStreams..<currentNumberOfStreams {
                self.streams[stream] = VideoStream(stream: stream)
            }
        }
        
        self.streamSettings = settings
        metricsManager.setSettings(settings)
        
        Task {
            try? await send(OutMessageUpdateSettings(settings: settings))
        }
    }
    
    private func send(_ message: OutMessage) async throws {
        guard let task else { return }
        
        let data = messageCoder.encodeOutMessage(message)
        
        do {
            try await task.send(.data(data))
        } catch {
            print("Failed to send a message: error=\(error), message=\(message)")
            throw error
        }
    }
    
    private func cancelTask(_ closeCode: URLSessionWebSocketTask.CloseCode = .normalClosure, failed: Bool = false) {
        task?.cancel(with: closeCode, reason: nil)
        task = nil
        state = failed ? .connectionFailed : .disconnected
    }
}
