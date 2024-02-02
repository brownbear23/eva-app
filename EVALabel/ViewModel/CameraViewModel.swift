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
    private var isCameraBusy = false
    let cameraPreview: AnyView
    let hapticImact = UIImpactFeedbackGenerator()
    

    
    @Published var recentImage: UIImage?
    
    
    @Published var showSetting : Bool = false
    @Published var isSilentModeOn : Bool = false
    @Published var shutterEffect = false
    @Published var showPreview = false

    var hazards: [String]?
    var distances: [Int]?
    var levels: [String]?
    
    @Published var selectedHazard: String = "" //TODO: update
    @Published var selectedDistance: Int = 0
    @Published var selectedLevel: String = ""
    @Published var selectedId: String = ""
    @Published var selectedAngle: String = ""
    @Published var selectedLux: String = "999"
    
    
    
    @Published var searchText: String = ""
    
    
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
        
        
        
        model.$levels.sink { [weak self] (result) in
            self?.levels = result
        }
        .store(in: &self.subscriptions)
        
        
        
        model.$hazards.sink { [weak self] (result) in
            self?.hazards = result
        }
        .store(in: &self.subscriptions)



        model.$distances.sink { [weak self] (result) in
            self?.distances = result
        }
        .store(in: &self.subscriptions)
        
    
    }
}