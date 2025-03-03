//
//  MetricsManager.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 08/01/2025.
//

import Foundation
import Combine


class MetricsManager {
    
    private var settings: StreamSettings?
    private var averageRenderScaleFactor: Double?
    
    private var streamStatistics: [Int : [StreamStatistic]] = [:]
    
    private var latestTimeStep = 0
    private var cpuUsages: [Double] = []
    private var memoryUsages: [Double] = []
    private var thermalStates: [ProcessInfo.ThermalState] = []
    
    private var computedMetricsSubject = PassthroughSubject<Metrics, Never>()
    
    var computedMetrics: AnyPublisher<Metrics, Never> {
        computedMetricsSubject.eraseToAnyPublisher()
    }
    
    struct StreamStatistic {
        let timestamp: TimeInterval
        let frameSize: Int
    }
    
    func setSettings(_ settings: StreamSettings) {
        computeMetrics()
        
        if let currentSettings = self.settings, !currentSettings.equalWithoutId(settings) {
            latestTimeStep = 0
            streamStatistics.removeAll()
            cpuUsages.removeAll()
            memoryUsages.removeAll()
            thermalStates.removeAll()
        }
        
        let streamsDiffer = settings.numberOfStreams != self.settings?.numberOfStreams
            || settings.resolution != self.settings?.resolution
        
        self.settings = settings
        
        if streamsDiffer {
            averageRenderScaleFactor = nil
        }
    }
    
    func setStreamSizes(_ sizes: [CGFloat]) {
        assert(settings != nil)
        
        computeAverageRenderScaleFactor(sizes)
        computeMetrics()
    }
    
    func didReceiveFrameMessage(_ message: InMessageFrame) {
        guard let settings else { return }
        
        guard settings.id == message.settingId else { return }
        
        let stream = message.stream
        let statistic = StreamStatistic(
            timestamp: Date().timeIntervalSince1970,
            frameSize: message.frame.count
        )
        
        if streamStatistics.keys.contains(stream) {
            streamStatistics[stream]!.append(statistic)
        } else {
            streamStatistics[stream] = [statistic]
        }
        
        let timestep = streamStatistics[stream]!.count
        if latestTimeStep < timestep {
            assert(latestTimeStep == timestep - 1)
            
            latestTimeStep = timestep
            cpuUsages.append(ProcessInfo.processInfo.getCpuUsage())
            memoryUsages.append(ProcessInfo.processInfo.getMemoryUsage())
            thermalStates.append(ProcessInfo.processInfo.thermalState)
        }
        
        computeMetrics()
    }
    
    private func computeAverageRenderScaleFactor(_ sizes: [CGFloat]) {
        guard let settings else { return }
        
        assert(sizes.count == settings.numberOfStreams)
        
        let sizes = sizes.map { Double($0) }
        let resolution = Double(settings.resolution)
        let factors = sizes.map { sqrt(($0 * $0) / (resolution * resolution)) }
        
        averageRenderScaleFactor = factors.reduce(into: 0.0) { $0 += $1 } / Double(sizes.count)
    }
    
    private func computeMetrics() {
        guard let settings, let averageRenderScaleFactor else { return }
        
        var timestep = 0
        var prevStatistics: [StreamStatistic]?
        
        outer: while true {
            var statistics = [StreamStatistic]()
            for stream in 0..<settings.numberOfStreams {
                if let st = streamStatistics[stream], st.count >= (timestep == 0 ? 2 : 1) {
                    statistics.append(st[0])
                } else {
                    break outer
                }
            }
            
            let cpuUsage = cpuUsages.first!
            let memoryUsage = memoryUsages.first!
            let thermalState = thermalStates.first!
            
            if let prevStatistics {
                let allActualFps = zip(prevStatistics, statistics).map { 1 / ($0.1.timestamp - $0.0.timestamp) }
                let averageActualFps = allActualFps.reduce(into: 0.0) { $0 += $1 } / Double(allActualFps.count)
                let allFrameSizes = statistics.map { $0.frameSize }
                let networkUsage = zip(allActualFps, allFrameSizes).reduce(into: 0.0) { $0 += $1.0 * Double($1.1) }

                computedMetricsSubject.send(Metrics(
                    settingId: settings.id,
                    cpuUsage: cpuUsage,
                    memoryUsage: memoryUsage,
                    networkUsage: networkUsage,
                    averageActualFps: averageActualFps,
                    averageRenderScaleFactor: averageRenderScaleFactor,
                    thermalState: thermalState
                ))
            }
            
            prevStatistics = statistics
            
            var breakEarly = false
            for stream in 0..<settings.numberOfStreams {
                if streamStatistics[stream]?.count == 1 {
                    breakEarly = true
                } else {
                    streamStatistics[stream]?.remove(at: 0)
                }
            }
            if breakEarly {
                break
            }
            
            cpuUsages.removeFirst()
            memoryUsages.removeFirst()
            thermalStates.removeFirst()
            
            timestep += 1
        }
        
        latestTimeStep -= timestep
    }
}
