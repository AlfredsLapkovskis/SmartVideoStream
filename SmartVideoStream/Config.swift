//
//  Environment.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 06/01/2025.
//


import Foundation


enum Config {
    static let backendUrl = URL(string: "ws://0.0.0.0:8888")!
    
    static let maxPreferredCpuUsage: Double = 2.0
    static let maxPreferredMemoryUsage: Int = 200 * 1024 * 1024
    
    static let initialStreamSettings = StreamSettings.withId(
        numberOfStreams: 5,
        fps: 15,
        resolution: 720
    )
    static let initialSlos = ServicesLevelObjectives(
        maxNetworkUsage: 10 * 1024 * 1024,
        minAverageFps: 15,
        minStreams: 5,
        maxAverageRenderScaleFactor: 1.6,
        maxThermalState: .fair
    )
    static let metricBatchSize = 32 // 32 for AIF, 1 for RL
}
