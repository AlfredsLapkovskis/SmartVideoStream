//
//  ContentView.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 03/01/2025.
//

import SwiftUI
import AVFoundation


struct ContentView: View {
    
    @StateObject private var sessionManager = SessionManager(Config.backendUrl)
    
    var body: some View {
        NavigationView {
            if sessionManager.state < .connected {
                LaunchView(sessionManager: sessionManager)
            } else {
                SessionView(sessionManager: sessionManager)
            }
        }
        
    }
}

#Preview {
    ContentView()
}
