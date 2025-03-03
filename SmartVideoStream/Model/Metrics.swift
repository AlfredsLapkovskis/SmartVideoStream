//
//  Metrics.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 08/01/2025.
//

import Foundation


struct Metrics {
    let settingId: Int
    let cpuUsage: Double
    let memoryUsage: Double
    let networkUsage: Double
    let averageActualFps: Double
    let averageRenderScaleFactor: Double
    let thermalState: ProcessInfo.ThermalState
    
    func serialize() -> [String : Any] {
        return [
            "setting_id": settingId,
            "cpu_usage": cpuUsage,
            "memory_usage": memoryUsage,
            "network_usage": networkUsage,
            "avg_actual_fps": averageActualFps,
            "avg_render_scale_factor": averageRenderScaleFactor,
            "thermal_state": thermalState.rawValue,
        ]
    }
}
