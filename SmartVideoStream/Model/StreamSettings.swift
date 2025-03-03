//
//  StreamSettings.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 05/01/2025.
//

import Foundation


struct StreamSettings {
    
    private static var idGenerator = 0
    private static let idLock = NSLock()
    
    let id: Int
    let numberOfStreams: Int
    let fps: Int
    let resolution: Int
    
    init(_ id: Int = 0, numberOfStreams: Int, fps: Int, resolution: Int) {
        self.id = id
        self.numberOfStreams = numberOfStreams
        self.fps = fps
        self.resolution = resolution
    }
    
    static func withId(numberOfStreams: Int, fps: Int, resolution: Int) -> StreamSettings {
        .init(Self.getNextId(), numberOfStreams: numberOfStreams, fps: fps, resolution: resolution)
    }
    
    static func from(json: [String : Any]) -> StreamSettings? {
        guard let id = json["id"] as? Int,
              let numberOfStreams = json["n_streams"] as? Int,
              let fps = json["fps"] as? Int,
              let resolution = json["resolution"] as? Int else {
            return nil
        }
        
        return .init(id, numberOfStreams: numberOfStreams, fps: fps, resolution: resolution)
    }
    
    func copyWithId() -> StreamSettings {
        .withId(
            numberOfStreams: self.numberOfStreams,
            fps: self.fps,
            resolution: self.resolution
        )
    }
    
    func equalWithoutId(_ other: StreamSettings) -> Bool {
        numberOfStreams == other.numberOfStreams &&
        fps == other.fps &&
        resolution == other.resolution
    }

    func serialize() -> [String : Any] {
        return [
            "id": id,
            "n_streams": numberOfStreams,
            "fps": fps,
            "resolution": resolution
        ]
    }
    
    private static func getNextId() -> Int {
        idLock.lock()
        defer {
            idLock.unlock()
        }
        
        idGenerator += 1
        return idGenerator
    }
}
