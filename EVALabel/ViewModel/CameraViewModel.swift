//
//  CameraViewModel.swift
//  EVALabel
//
//  Created by Bill Han on 1/15/24.
//

import Foundation
import AVFoundation
import SwiftUI
import Combine

class CameraViewModel: ObservableObject {
    
    private let model: Camera
    
    private let session: AVCaptureSession
    private var subscriptions = Set<AnyCancellable>()
    private var isCameraBusy = false // Camera model data (original from the model)
    let cameraPreview: AnyView
    let hapticImact = UIImpactFeedbackGenerator()
    
    @Published var recentImage: UIImage? // Camera model data (original from the model)
    
    
    @Published var showSetting : Bool = false
    @Published var isSilentModeOn : Bool = false
    @Published var shutterEffect = false
    @Published var showPreview = false

    var hazards: [String]? // Camera model data (original from the model)
    var distances: [Int]? // Camera model data (original from the model)
    var levels: [String]? // Camera model data (original from the model)
    
    @Published var selectedHazard: String = "" // Camera model data
    @Published var selectedDistance: Int = 0 // Camera model data
    @Published var selectedLevel: String = "" // Camera model data
    @Published var selectedId: String = "" // Camera model data
    @Published var selectedAngle: String = "" // Camera model data
    @Published var selectedLux: String = "999" // Camera model data
    
    
    @Published var searchText: String = ""
    
    @Published var lowResolutionWarning = false // Camera model data (original from the model)

    
    var filteredHazards: [String]? {
            guard !searchText.isEmpty else { return hazards }
            return hazards!.filter { hazard in
                hazard.lowercased().contains(searchText.lowercased())
            }
        }

    
    func configure() {
        model.requestAndCheckPermissions()
    }
    
//ID - meter - height - angle - lux. 
    
    func switchSilent() {
        isSilentModeOn.toggle()
        print("[CameraViewModel]: Switch silence!")
        model.isSilentModeOn = isSilentModeOn
        
    }
    
    func saveLabel() {
        self.showSetting = false
        model.selectedHazard = self.selectedHazard
        model.selectedDistance = self.selectedDistance
        model.selectedLevel = self.selectedLevel
        
        model.selectedId = self.selectedId
        model.selectedAngle = self.selectedAngle
        model.selectedLux = self.selectedLux
    }
    
    func capturePhoto() {
        if isCameraBusy == false {
            //Haptic
            hapticImact.impactOccurred()
            
            //Shutter animation
            withAnimation(.easeInOut(duration: 0.1)) {
                shutterEffect = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) {
                    self.shutterEffect = false
                }
            }
            
            model.capturePhoto()
            print("[CameraViewModel]: Photo captured!")
        } else {
            print("[CameraViewModel]: Camera is busy!")
        }
        
        
    }
    

    
    init() {
        self.model = Camera()
        self.session = model.session
        self.cameraPreview = AnyView(CameraPreviewView(session: session))
        
        
        model.loadHazardsFromCSV()
        
        model.$recentImage.sink { [weak self] (photo) in
            guard let pic = photo else { return }
            self?.recentImage = pic
        }
        .store(in: &self.subscriptions)

        model.$isCameraBusy.sink { [weak self] (result) in
            self?.isCameraBusy = result
        }
        .store(in: &self.subscriptions)        
        
        
        model.$lowResolutionWarning.sink { [weak self] (result) in
            self?.lowResolutionWarning = result
        }
        .store(in: &self.subscriptions)
        
        self.levels = model.levels
        self.hazards = model.hazards
        self.distances = model.distances

                

    }
}
