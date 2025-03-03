//
//  VideoStream.swift
//  SmartVideoStream
//
//  Created by Alfreds Lapkovskis on 03/01/2025.
//

import SwiftUI
import Combine


class VideoStream : ObservableObject {
    @Published private(set) var image: UIImage?
    
    let stream: Int
    
    init(stream: Int) {
        self.stream = stream
    }
    
    func didReceiveFrameMessage(_ message: InMessageFrame) {
        image = UIImage(data: message.frame)
    }
}
