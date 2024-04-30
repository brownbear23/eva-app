
import Foundation
import UIKit
import Photos
import Accelerate
import Foundation

class LinearFilterModel: ObservableObject {
    
    var filteredImg: UIImage = UIImage()
    var va: Float = 0
    var cs: Float = 0
    var imgData: Data?
    var filteredImgName: String = "null"
    
    func addFilter(_ imgData: Data?, _ imgName: String, _ va: Float, _ cs: Float) -> (UIImage?, String) {
        
        guard let inputImgData = imgData else {
            print("Input image data is nil.")
            return (nil, "")
        }
        
        self.va = va
        self.cs = va
        self.imgData = imgData
        
        print("Applying Filter...")
        filteredImg = applyFilter(to: inputImgData, va: va, cs: cs)!
        print("Applying Filter DONE")

        let nameComponents = imgName.split(separator: ".")
        let vaStr: String = va.description.replacingOccurrences(of: ".", with: "-", options: .literal, range: nil)
        let csStr: String = cs.description.replacingOccurrences(of: ".", with: "-", options: .literal, range: nil)
        self.filteredImgName = "\(nameComponents[0])_va\(vaStr)_cs\(csStr)"
        
        return (filteredImg, filteredImgName)
    }
    
    
    func saveFilteredImg() {
        print("Saving Filtered Image...")

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filteredImgName).appendingPathExtension("png")
        
        do {
            //            try imgData?.write(to: fileURL)
            try self.filteredImg.heicData()?.write(to: fileURL)
        } catch {
            fatalError("Couldn't write DNG file to the URL.")
        }
        
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            
            // Don't continue unless the user granted access.
            guard status == .authorized else { return }
            
            PHPhotoLibrary.shared().performChanges {
                
                let creationRequest = PHAssetCreationRequest.forAsset()
                
                // Save the RAW (DNG) file as the main resource for the Photos asset.
                let options = PHAssetResourceCreationOptions()
                options.shouldMoveFile = true
                creationRequest.addResource(with: .photo,
                                            fileURL: fileURL,
                                            options: options)
            } completionHandler: { success, error in
                // Process the Photos library error.
            }
        }
        print("Saving Filtered Image DONE")
    }
    

    
    func shifting(image: UIImage, serialImagePixels: UnsafeMutableBufferPointer<LinearFilterModel.Pixel>, va: Float, cs: Float){
        var horShift: Float = 0
        var verShift: Float = 0
        (horShift, verShift) = findShift(va, cs)
        
        horShift = 1 / 0.157 //TODO: for testing purpose
        verShift = 1
        
        
        print("HSHIFT: " + horShift.description)
        print("VSHIFT: " + verShift.description)
        
        horShift = 1/horShift
        
        
        let image = image.cgImage
        let height = image!.height
        let width = image!.width
        print("ORIGINAL serialImagePixels[0].red: " + String(serialImagePixels[0].red))
//        print("ORIGINAL serialImagePixels[0].green: " + String(serialImagePixels[0].green))
//        print("ORIGINAL serialImagePixels[0].blue: " + String(serialImagePixels[0].blue))

        
        print("Vertical Shift processing...")
        // Vertical Shift
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                var pixel = serialImagePixels[index]
                if pixel.red != 255 {
                    let redValue = Float(pixel.red)  // Convert the red component to Float
                    let adjustedValue = 255 - redValue // Invert the red value
                    let scaledValue = adjustedValue * verShift // Apply the vertical shift scaling
                    let finalValue = 255 - scaledValue // Invert the value back
                    // Ensure the final value is within the 0-255 range and convert it to UInt8
                    pixel.red = UInt8(max(0, min(255, finalValue)))
                }
                if pixel.green != 255 {
                    let greenValue = Float(pixel.green)
                    let adjustedValue = 255 - greenValue
                    let scaledValue = adjustedValue * verShift
                    let finalValue = 255 - scaledValue
                    
                    pixel.green = UInt8(max(0, min(255, finalValue)))
                }
                if pixel.blue != 255 {
                    let blueValue = Float(pixel.blue)
                    let adjustedValue = 255 - blueValue
                    let scaledValue = adjustedValue * verShift
                    let finalValue = 255 - scaledValue
                    
                    pixel.blue = UInt8(max(0, min(255, finalValue)))
                }
                serialImagePixels[index] = pixel
            }
        }
        print("Vertical Shift DONE")

        
        
        
        
        print("Horizontal Shift processing...")
        // Horizontal Shift
        let FOCAL_LENGTH: Float = 6.86
//        let horAoV = angleOfView(9.8, FOCAL_LENGTH)
//        let vertAoV = angleOfView(7.3, FOCAL_LENGTH)
        let horAoV: Float = 6.0 //TODO: for testing purpose
        let vertAoV: Float = 6.0
        let imgAngSize = horAoV * vertAoV
        print("horAoV: " + String(horAoV))
        print("vertAoV: " + String(vertAoV))
//        print("imgAngSize: " + String(imgAngSize))

        var ux: [[Float]]?
        var uy: [[Float]]?
        (ux, uy) = createMeshGrid(height, width, vertAoV, horAoV)
        
        var meanR: Float = 0
        var meanG: Float = 0
        var meanB: Float = 0
        (meanR, meanG, meanB) = meanLum(image: image!, pixels: serialImagePixels)
        
        let sSF0: [[Float]] = sSF0(ux: ux!, uy: uy!)
        let sSF: [[Float]] = sSF(sSF0: sSF0, horShift: horShift)
        
        
        
        
        
        var singleChannelPixels = [[Float]](repeating: [Float](repeating: 0, count:width * height), count: 3)

        for i in 0..<width * height {
            singleChannelPixels[0][i] = Float(serialImagePixels[i].red)
            singleChannelPixels[1][i] = Float(serialImagePixels[i].green)
            singleChannelPixels[2][i] = Float(serialImagePixels[i].blue)
        }
        
        var colorChannelIdx = 0;
        
//        print("Horizontal Shift: Processing FFT...")
        
        // Usage example (replace 'pixels', 'width', and 'height' with actual values)
        convertTo2DMatrixAndSaveToFile(serialImagePixels: serialImagePixels, width: width, height: height)

        for meanLum in [meanR, meanG, meanB] {
            print("-------------------------------------------------------------------------------------------")
            let CSF0: [[Float]] = csf(meanLum: meanLum, sSF_0: sSF0, imgAngSize: imgAngSize)
            let CSF: [[Float]] = csf(meanLum: meanLum, sSF_0: sSF, imgAngSize: imgAngSize)
            let nCSF: [[Float]] = nCSF(CSF: CSF, CSF0: CSF0)
            
            
            
            
            
            
            
            
            //PRINT DEBUG START

            // Convert the 2D array into a string with newline characters for better readability
//            let nCSFString = nCSF.map { row in
//                row.map { String($0) }.joined(separator: ", ")
//            }.joined(separator: "\n")
//
//            // Specify the file path where you want to save the data
//            let fileURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!.appendingPathComponent("nCSF.txt")
//            print("File written at: \(fileURL)")
//
//            // Write the string to the text file
//            do {
//                try nCSFString.write(to: fileURL, atomically: true, encoding: .utf8)
//                print("Data was written to the file successfully.")
//            } catch {
//                print("An error occurred while writing to the file: \(error)")
//            }
            //PRINT DEBUG END
            
            
            
            

            
            
            let Y: (real: [Float], imag: [Float]) = performFFT(serialImagePixels: &singleChannelPixels[colorChannelIdx], width: width, height: height)
            var yNCSF = arrayEleMul(nCSF: nCSF, Y: Y, width: width, height: height)
            let filtImg: (real: [Float], imag: [Float]) = performIFFT(inputPixels: &yNCSF, width: width, height: height)
            
            for index in 0..<width*height {
                singleChannelPixels[colorChannelIdx][index] = filtImg.real[index]
            }
            colorChannelIdx += 1

        }
//        print("Horizontal Shift: Processing FFT DONE")

//        print("After horizontal singleChannelPixels[0][0]: " + String(singleChannelPixels[0][0]))

        print("------------------------------------")
        for index in 0..<width*height {
            
            let redValue = singleChannelPixels[0][index]
            let greenValue = singleChannelPixels[1][index]
            let blueValue = singleChannelPixels[2][index]

            // Check for values greater than UInt8.max and print them
            if redValue > 255 || greenValue > 255 || blueValue > 255 {
//                print("Out of bounds value found - Red: \(redValue), Green: \(greenValue), Blue: \(blueValue) at index \(index)")
            }

            serialImagePixels[index].red = UInt8(min(redValue, 255))
            serialImagePixels[index].green = UInt8(min(greenValue, 255))
            serialImagePixels[index].blue = UInt8(min(blueValue, 255))
            
            
        
//            serialImagePixels[index].red = UInt8(singleChannelPixels[0][index])
//            serialImagePixels[index].green = UInt8(singleChannelPixels[1][index])
//            serialImagePixels[index].blue = UInt8(singleChannelPixels[2][index])
            
//            serialImagePixels[index].red = UInt8(255)
//            serialImagePixels[index].green = UInt8(255)
//            serialImagePixels[index].blue = UInt8(255)
        }
        
        
//        for index in 62752..<62752+width {
//            serialImagePixels[index].red = UInt8(255)
//            serialImagePixels[index].green = UInt8(0)
//            serialImagePixels[index].blue = UInt8(0)
//        }
        print("Horizontal Shift DONE!")

        
    }
    
    
    
    
    func applyFilter(to imgData: Data, va: Float, cs: Float) -> UIImage? {
        
        //        guard let cgImage = image.cgImage else { return nil }
        let image = UIImage(data: imgData)!
        let cgImage = UIImage(data: imgData)?.cgImage
        
        let width = cgImage!.width
        let height = cgImage!.height
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
        
        let imageData = UnsafeMutablePointer<Pixel>.allocate(capacity: width * height)
        
        guard let imageContext = CGContext(
            data: imageData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        imageContext.draw(cgImage!, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        let pixels = UnsafeMutableBufferPointer<LinearFilterModel.Pixel>(start: imageData, count: width * height)
        
        shifting(image: image, serialImagePixels: pixels, va: va, cs: cs)
        
        guard let imageContext = CGContext(
            data: pixels.baseAddress,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        
        guard let newCGImage = imageContext.makeImage() else { return nil }
        return UIImage(cgImage: newCGImage, scale: image.scale, orientation: image.imageOrientation)
    }
    
    
    
    public struct Pixel {
        public var value: UInt32
        
        public var red: UInt8 {
            get {
                return UInt8(value & 0xFF)
            } set {
                value = UInt32(newValue) | (value & 0xFFFFFF00)
            }
        }
        
        public var green: UInt8 {
            get {
                return UInt8((value >> 8) & 0xFF)
            } set {
                value = (UInt32(newValue) << 8) | (value & 0xFFFF00FF)
            }
        }
        
        public var blue: UInt8 {
            get {
                return UInt8((value >> 16) & 0xFF)
            } set {
                value = (UInt32(newValue) << 16) | (value & 0xFF00FFFF)
            }
        }
        
        
    }
    
    
}
