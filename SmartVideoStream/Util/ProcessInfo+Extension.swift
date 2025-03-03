//
//  Process.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 09/01/2025.
//

import Foundation


extension ProcessInfo {
    
    func getCpuUsage() -> Double {
        var threadsList: thread_act_array_t?
        var threadCount: mach_msg_type_number_t = 0
        let kerr: kern_return_t = task_threads(mach_task_self_, &threadsList, &threadCount)

        if kerr != KERN_SUCCESS {
            return -1
        }

        var totalCPUUsage: Double = 0

        if let threads = threadsList {
            for i in 0..<threadCount {
                var threadInfo = thread_basic_info()
                var threadInfoCount = mach_msg_type_number_t(THREAD_INFO_MAX)

                let kr: kern_return_t = withUnsafeMutablePointer(to: &threadInfo) {
                    $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                        thread_info(threads[Int(i)], thread_flavor_t(THREAD_BASIC_INFO), $0, &threadInfoCount)
                    }
                }

                if kr == KERN_SUCCESS {
                    let threadBasicInfo = threadInfo as thread_basic_info
                    if threadBasicInfo.flags & TH_FLAGS_IDLE == 0 {
                        totalCPUUsage += Double(threadBasicInfo.cpu_usage) / Double(TH_USAGE_SCALE)
                    }
                }
            }
        }

        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threadsList), vm_size_t(threadCount))

        return totalCPUUsage / Config.maxPreferredCpuUsage
    }
    
    func getMemoryUsage() -> Double {
        let TASK_VM_INFO_COUNT = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let TASK_VM_INFO_REV1_COUNT = mach_msg_type_number_t(MemoryLayout.offset(of: \task_vm_info_data_t.min_address)! / MemoryLayout<integer_t>.size)
        var info = task_vm_info_data_t()
        var count = TASK_VM_INFO_COUNT

        let kerr = withUnsafeMutablePointer(to: &info) { infoPtr in
            infoPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }

        if kerr == KERN_SUCCESS, count >= TASK_VM_INFO_REV1_COUNT {
            return Double(info.phys_footprint) / Double(Config.maxPreferredMemoryUsage)
        }
        
        return 0
    }
}
