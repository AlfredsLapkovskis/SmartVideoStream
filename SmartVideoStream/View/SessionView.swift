//
//  SessionView.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 07/01/2025.
//

import SwiftUI


struct SessionView: View {
    
    @ObservedObject var sessionManager: SessionManager
    
    var body: some View {
        VStack {
            VideoStreamGrid(sessionManager: sessionManager)
            
            Button {
                sessionManager.disconnect()
            } label: {
                Text("Leave")
            }
        }
    }
}

#Preview {
    let sessionManager = SessionManager(Config.backendUrl)
    
    SessionView(sessionManager: sessionManager)
}
