//
//  CameraPreviewView.swift
//  EVALabel
//
//  Created by Bill Han on 1/15/24.
//

import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    
    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
    
    
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            return layer as! AVCaptureVideoPreviewLayer
        }
    }
    
    
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        
        view.backgroundColor = .black
//        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        view.videoPreviewLayer.videoGravity = .resizeAspect

        view.videoPreviewLayer.cornerRadius = 0
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.connection?.videoOrientation = .portrait
        
        return view
    }
    
    func updateUIView(_ uiView: VideoPreviewView, context: Context) {
        
    }
    
    
    
}

//#Preview {
//    CameraPreviewView(session: <#AVCaptureSession#>)
//}
