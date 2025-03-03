//
//  ServicesLevelObjectives.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 08/01/2025.
//

import Foundation


struct ServicesLevelObjectives {
    let maxNetworkUsage: Int
    let minAverageFps: Double
    let minStreams: Int
    let maxAverageRenderScaleFactor: Double
    let maxThermalState: ProcessInfo.ThermalState
    
    func serialize() -> [String : Any] {
        return [
            "max_network_usage": maxNetworkUsage,
            "min_avg_fps": minAverageFps,
            "min_streams": minStreams,
            "max_avg_render_scale_factor": maxAverageRenderScaleFactor,
            "max_thermal_state": maxThermalState.rawValue,
        ]
    }
}
