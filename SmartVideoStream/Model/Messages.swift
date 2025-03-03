//
//  Messages.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 05/01/2025.
//

import Foundation


// Message Types

enum OutMessageType : Int {
    case connect = 1
    case disconnect = 2
    case updateSettings = 3
    case updateSlos = 4
    case metrics = 5
}

enum InMessageType : Int {
    case connect = 1
    case disconnect = 2
    case error = 3
    case frame = 4
    case suggestSettings = 5
}


// Abstract Messages

protocol OutMessage {
    var type: OutMessageType { get }
    func encodeContent() -> Data
}

protocol InMessage {
    var type: InMessageType { get }
    init(content: Data)
}


// Outbound Messages

struct OutMessageConnect : OutMessage {
    
    let settings: StreamSettings
    let slos: ServicesLevelObjectives
    
    var type: OutMessageType {
        .connect
    }
    
    func encodeContent() -> Data {
        let settings = self.settings.serialize()
        let slos = self.slos.serialize()
        
        return try! JSONSerialization.data(withJSONObject: [
            "stream_settings": settings,
            "slos": slos,
        ])
    }
}

struct OutMessageDisconnect : OutMessage {
    var type: OutMessageType {
        .disconnect
    }
    
    func encodeContent() -> Data {
        Data()
    }
}

struct OutMessageUpdateSettings : OutMessage {
    let settings: StreamSettings
    
    var type: OutMessageType {
        .updateSettings
    }
    
    func encodeContent() -> Data {
        return try! JSONSerialization.data(withJSONObject: [
            "stream_settings": settings.serialize(),
        ])
    }
}

struct OutMessageUpdateSlos : OutMessage {
    let slos: ServicesLevelObjectives
    
    var type: OutMessageType {
        .updateSlos
    }
    
    func encodeContent() -> Data {
        return try! JSONSerialization.data(withJSONObject: [
            "slos": slos.serialize(),
        ])
    }
}

struct OutMessageMetrics : OutMessage {
    let batchOfMetrics: [Metrics]
    
    var type: OutMessageType {
        .metrics
    }
    
    func encodeContent() -> Data {
        return try! JSONSerialization.data(
            withJSONObject: [
                "metrics": batchOfMetrics.map { $0.serialize() }
            ]
        )
    }
}


// Inbound Messages

struct InMessageConnect : InMessage {
    let streamSettingsId: Int?
    
    var type: InMessageType {
        .connect
    }
    
    init(content: Data) {
        if let json = try? JSONSerialization.jsonObject(with: content) as? [String : Any],
            let streamSettingsId = json["stream_settings_id"] as? Int {
            self.streamSettingsId = streamSettingsId
        } else {
            self.streamSettingsId = nil
        }
    }
}

struct InMessageDisconnect : InMessage {
    var type: InMessageType {
        .disconnect
    }
    
    init(content: Data) {
    }
}

struct InMessageError : InMessage {
    enum Code : Int {
        case generic = 1
        case wrongMessage = 2
    }
    
    var type: InMessageType {
        .error
    }
    
    let code: Code
    let message: String
    
    init(content: Data) {
        if let json = try? JSONSerialization.jsonObject(with: content) as? [String : Any],
            let code = json["code"] as? Int,
            let message = json["message"] as? String {
            self.code = Code(rawValue: code) ?? .generic
            self.message = message
        } else {
            self.code = .generic
            self.message = ""
        }
    }
}

struct InMessageFrame : InMessage {
    var type: InMessageType {
        .frame
    }
    
    let isValid: Bool
    let stream: Int
    let frame: Data
    let settingId: Int
    
    private static var divider = "_".data(using: .utf8)!
    
    init(content: Data) {
        guard let div1 = content.range(of: Self.divider),
            let div2 = content.range(of: Self.divider, in: div1.upperBound..<content.endIndex) else {
            isValid = false
            stream = -1
            frame = Data()
            settingId = -1
            return
        }
        
        isValid = true
        stream = content[..<div1.lowerBound].withUnsafeBytes {
            Int($0.load(as: UInt8.self).bigEndian)
        }
        settingId = content[div1.upperBound..<div2.lowerBound].withUnsafeBytes {
            var value = 0
            memcpy(&value, $0.baseAddress!, MemoryLayout<Int>.size)
            return Int(bigEndian: value)
        }
        frame = content[div2.upperBound...]
    }
}

struct InMessageSuggestSettings : InMessage {
    var type: InMessageType {
        .suggestSettings
    }
    
    let settings: StreamSettings?
    
    init(content: Data) {
        if let json = try? JSONSerialization.jsonObject(with: content) as? [String: Any],
           let settings = json["stream_settings"] as? [String : Any] {
            self.settings = StreamSettings.from(json: settings)
        } else {
            self.settings = nil
        }
    }
}
