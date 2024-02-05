//
//  Camera.swift
//  EVALabel
//
//  Created by Bill Han on 1/15/24.
//

import Foundation
import AVFoundation
import UIKit
import Photos



class Camera: NSObject, ObservableObject {
    
    var hazards: [String]? //Publish not necessary
    var distances = [1, 3, 5] //Publish not necessary
    var levels = ["eye", "waist"] //Publish not necessary

    var session = AVCaptureSession()
    var videoDeviceInput: AVCaptureDeviceInput!
    let photoOutput = AVCapturePhotoOutput()
    
    
    var isSilentModeOn = false
    
    private var rawFileURL: URL?
    private var compressedData: Data?
    
    
    @Published var recentImage: UIImage?
    @Published var isCameraBusy = false
    @Published var isIp15Pro = true

    var selectedHazard: String = ""
    var selectedDistance: Int = 0
    var selectedLevel: String = ""
    var selectedId: String = ""
    var selectedAngle: String = ""
    var selectedLux: String = "999"
    
    
    
    
    private func parseCSVAt(url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let dataEncoded = String(data: data, encoding: .utf8)
            if let dataArr = dataEncoded?.components(separatedBy: "\n") {
                self.hazards = dataArr.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
        } catch {
            print("Error reading CSV file")
        }
    }
    
    func loadHazardsFromCSV() {
            let path = Bundle.main.path(forResource: "hazards", ofType: "csv")!
            parseCSVAt(url: URL(fileURLWithPath: path))

    }
    
    
    
    func setUpCameraSession() {
        
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                for: .video, position: .back) {
            
            // Start the capture session configuration.
            self.session.beginConfiguration()
            // Configure the session for photo capture.
            self.session.sessionPreset = .photo
            
            do {
                // Connect the default video device.
                videoDeviceInput = try AVCaptureDeviceInput(device: device)
                if session.canAddInput(videoDeviceInput) {
                    session.addInput(videoDeviceInput)
                } else {
                    fatalError("[Camera]: setupFailed")
                }
                
                // Connect and configure the capture output.
                if session.canAddOutput(photoOutput) {
                    session.addOutput(photoOutput)
                    // Use the Apple ProRAW format when the environment supports it.
                    photoOutput.isAppleProRAWEnabled = true
                    photoOutput.maxPhotoDimensions = .init(width: 8064, height: 6048)
//                    photoOutput.maxPhotoDimensions = .init(width: 4032, height: 3024)
                    photoOutput.maxPhotoQualityPrioritization = .quality
                } else {
                    fatalError("[Camera]: setupFailed")
                }
                
                // Session configuration is complete. Commit the configuration.
                self.session.commitConfiguration()
                
                session.startRunning()
            } catch {
                print(error)
            }
        }
        
    }
    
    func requestAndCheckPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) {
                [weak self] authStatus in
                if authStatus {
                    DispatchQueue.main.async {
                        self?.setUpCameraSession()
                    }
                }
            }
        case .restricted:
            break
        case . authorized:
            setUpCameraSession()
        default:
            print("Permission declined")
        }
        
    }
    
    
    func capturePhoto() { // Photo taking function
        print("[Camera]: capturePhoto start")
        
        let query = photoOutput.isAppleProRAWEnabled ?
        { AVCapturePhotoOutput.isAppleProRAWPixelFormat($0) } :
        { AVCapturePhotoOutput.isBayerRAWPixelFormat($0) }
        
        
        // Retrieve the RAW format, favoring the Apple ProRAW format when it's in an enabled state.
        guard let rawFormat =
                photoOutput.availableRawPhotoPixelFormatTypes.first(where: query) else {
            fatalError("No RAW format found.")
        }
        
        // Capture a RAW format photo, along with a processed format photo.
        let processedFormat = [AVVideoCodecKey: AVVideoCodecType.hevc]
        
        let photoSettings = AVCapturePhotoSettings(rawPixelFormatType: rawFormat,
                                                   processedFormat: processedFormat)
        
  
        photoSettings.maxPhotoDimensions = .init(width: 8064, height: 6048)

//        photoSettings.maxPhotoDimensions = .init(width: 8064, height: 6048)

   
        

        photoSettings.photoQualityPrioritization = photoOutput.maxPhotoQualityPrioritization
        
        print("[Camera]: MAX width Support " + String(photoOutput.maxPhotoDimensions.width))
        print("[Camera]: MAX height Support " + String(photoOutput.maxPhotoDimensions.height))
        
        
        // Tell the output to capture the photo.
        photoOutput.capturePhoto(with: photoSettings, delegate: self)
        
        print("[Camera]: Photo's taken")
        
    }
    
    
    
    //    func savePhoto(_ imageData: Data) {
    //        print("[Camera]: savePhoto entered")
    //        guard let image = UIImage(data: imageData) else {
    //            fatalError("[Camera] Cannot be parsed to an UIImage")
    //        }
    //        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    //
    //
    //        print("[Camera]: Photo's saved")
    //    }
    
}

extension Camera: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, willBeginCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        self.isCameraBusy = true
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, willCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if isSilentModeOn {
            print("[Camera]: Silent sound activated")
            AudioServicesDisposeSystemSoundID(1108)
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didCapturePhotoFor resolvedSettings: AVCaptureResolvedPhotoSettings) {
        if isSilentModeOn {
            AudioServicesDisposeSystemSoundID(1108)
        }
    }
    
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let photoData = photo.fileDataRepresentation() else {
            fatalError("[Camera]: No photo data to write.")
            return
        }
        
        
        if photo.isRawPhoto {
            // Generate a unique URL to write the RAW file.
            rawFileURL = makeUniqueDNGFileURL()
            do {
                // Write the RAW (DNG) file data to a URL.
                try photoData.write(to: rawFileURL!)
                self.recentImage = UIImage(data: photoData)
                //                self.savePhoto(photoData)
            } catch {
                fatalError("Couldn't write DNG file to the URL.")
            }
            self.isCameraBusy = false
        } else {
            // Store compressed bitmap data.
            compressedData = photoData
        }
    }
    
    
    private func makeUniqueDNGFileURL() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        //        let fileName = ProcessInfo.processInfo.globallyUniqueString

        
        let fileName = selectedHazard + "_ID" + selectedId + "_" + String(selectedDistance) + "m_" + selectedLevel + "_ANGLE" + selectedAngle + "_" + selectedLux  + "lux"
        
        
        return tempDir.appendingPathComponent(fileName).appendingPathExtension("dng")
    }
    
    
    
    // After both RAW and compressed versions are complete, add them to the Photos library.
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        
        
        guard error == nil else {
            print("Error capturing photo: \(error!)")
            return
        }
        
        // Ensure the RAW and processed photo data exists.
        guard let rawFileURL = rawFileURL,
              let compressedData = compressedData else {
            print("The expected photo data isn't available.")
            return
        }
        
        // Request add-only access to the user's Photos library (if the user hasn't already granted that access).
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            
            // Don't continue unless the user granted access.
            guard status == .authorized else { return }
            
            PHPhotoLibrary.shared().performChanges {
                
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                // Save the RAW (DNG) file as the main resource for the Photos asset.
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                creationRequest.addResource(with: .photo,
                                            fileURL: rawFileURL,
                                            options: options)
                
                
                //                // Add the compressed (HEIF) data as an alternative resource.
                //                creationRequest.addResource(with: .alternatePhoto,
                //                                            data: compressedData,
                //                                            options: nil)
                
            } completionHandler: { success, error in
                // Process the Photos library error.
            }
        }
    }
}
