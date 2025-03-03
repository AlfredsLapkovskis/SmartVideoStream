//
//  LaunchView.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 06/01/2025.
//

import SwiftUI

struct LaunchView: View {
    
    @ObservedObject var sessionManager: SessionManager
    
    private var hasFailedToConnect: Binding<Bool> {
        Binding {
            sessionManager.state == .connectionFailed
        } set: { _ in
        }
    }
    
    var body: some View {
        let appName = Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? ""
        
        Group {
            if sessionManager.state == .connecting {
                ProgressView("Connecting...")
                    .scaleEffect(2)
                    .font(.system(size: 8))
            } else {
                Button {
                    sessionManager.connect()
                } label: {
                    ZStack {
                        Text("Connect")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .padding()
                    }
                }
                .buttonStyle(.bordered)
                .alert("An error occurred", isPresented: hasFailedToConnect, actions: {
                    Button {
                        sessionManager.resetError()
                    } label: {
                        Text("OK")
                    }
                }, message: {
                    Text("Failed to connect to the server")
                })
            }
        }
        .navigationTitle(Text(appName))
    }
}

#Preview {
    NavigationView {
        LaunchView(sessionManager: SessionManager(Config.backendUrl))
    }
}
