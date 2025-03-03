//
//  VideoStreamGrid.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 03/01/2025.
//

import SwiftUI


struct VideoStreamGrid : View {
    
    @ObservedObject var sessionManager: SessionManager
    
    @Environment(\.displayScale) private var displayScale
    
    var body: some View {
        Group {
            GeometryReader { geometry in
                let numberOfStreams = sessionManager.streams.count
                
                let availableWidth = geometry.size.width
                let availableHeight = geometry.size.height
                
                // Fix corner cases
                let effectiveColumns = Int(ceil(sqrt(CGFloat(numberOfStreams) * availableWidth / availableHeight)))
                let effectiveRows = Int(ceil(CGFloat(numberOfStreams) / Double(effectiveColumns)))
                
                let regularSlotSize: CGFloat = min(
                    availableWidth / CGFloat(effectiveColumns),
                    availableHeight / CGFloat(effectiveRows)
                )
                
                let lastRowItems = numberOfStreams - effectiveColumns * (effectiveRows - 1)
                let remainingSlotSize: CGFloat = min(
                    availableWidth / CGFloat(lastRowItems),
                    availableHeight - regularSlotSize * CGFloat(effectiveRows - 1)
                )
                
                let regularSizes = [CGFloat](
                    repeating: regularSlotSize * displayScale,
                    count: effectiveColumns * (effectiveRows - 1)
                )
                let lastRowSizes = [CGFloat](
                    repeating: remainingSlotSize * displayScale,
                    count: lastRowItems
                )
                let allSizes = regularSizes + lastRowSizes
                
                VStack(spacing: 0) {
                    ForEach(0..<effectiveRows, id: \.self) { row in
                        HStack(spacing: 0) {
                            let (size, count) = if row == effectiveRows - 1 {
                                (remainingSlotSize, lastRowItems)
                            } else {
                                (regularSlotSize, effectiveColumns)
                            }
                            
                            ForEach(0..<count, id: \.self) { column in
                                let index = row * effectiveColumns + column
                                let stream = sessionManager.streams[index]!
                                    
                                VideoStreamView(videoStream: stream)
                                    .frame(width: size, height: size)
                                    .clipped()
                            }
                        }
                    }
                }
                .frame(width: availableWidth, height: availableHeight)
                .background(Color.black)
                .onChange(of: geometry.size) {
                    sessionManager.notifyStreamSizesChanged(allSizes)
                }
                .onChange(of: sessionManager.streams.count) {
                    sessionManager.notifyStreamSizesChanged(allSizes)
                }
                .onChange(of: sessionManager.streamSettings.resolution) {
                    sessionManager.notifyStreamSizesChanged(allSizes)
                }
            }
        }
    }
}


#Preview {
    VideoStreamGrid(sessionManager: SessionManager(Config.backendUrl))
}
