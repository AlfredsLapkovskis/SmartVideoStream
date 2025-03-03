//
//  MessageCoder.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 05/01/2025.
//

import Foundation


class MessageCoder {
    
    private var inMessageTypes: [InMessageType : InMessage.Type] = [
        .connect: InMessageConnect.self,
        .disconnect: InMessageDisconnect.self,
        .error: InMessageError.self,
        .frame: InMessageFrame.self,
        .suggestSettings: InMessageSuggestSettings.self,
    ]
    
    private static var divider = "_".data(using: .utf8)!
    
    func decodeInMessage(_ rawBytes: Data) -> InMessage? {
        guard let range = rawBytes.range(of: Self.divider) else { return nil }
        
        let dividerIdx = range.lowerBound
        let contentIdx = range.upperBound
        
        let rawMessageType = rawBytes[..<dividerIdx].withUnsafeBytes {
            Int($0.load(as: UInt8.self).bigEndian)
        }
        let rawMessageContent = rawBytes[contentIdx...]
        
        guard let messageType = InMessageType(rawValue: rawMessageType) else { return nil }
        
        guard let messageClass = inMessageTypes[messageType] else { return nil }
        
        return messageClass.init(content: rawMessageContent)
    }
    
    func encodeOutMessage(_ message: OutMessage) -> Data {
        let typeBytes = withUnsafeBytes(of: message.type.rawValue.bigEndian) { Data($0) }
        let messageBytes = typeBytes + Self.divider + message.encodeContent()
        
        return messageBytes
    }
}
