//
//  VideoStreamView.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 03/01/2025.
//


import SwiftUI

struct VideoStreamView : View {

    @ObservedObject var videoStream: VideoStream
    
    var body: some View {
        Group {
            if let image = videoStream.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
            }
        }
    }
}


#Preview {
    let videoStream = VideoStream(stream: 0)
    
    VideoStreamView(videoStream: videoStream)
        .frame(width: 300, height: 300, alignment: .center)
        .clipped()
}
