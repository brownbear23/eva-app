
import Foundation
import UIKit
import Photos

class LinearFilterModel: ObservableObject {
    
    var filteredImg: UIImage = UIImage()
    var va: CGFloat = 0
    var cs: CGFloat = 0
    var imgData: Data?
    var filteredImgName: String = "null"
    
    func addFilterSample(_ imgData: Data?, _ imgName: String, _ va: CGFloat, _ cs: CGFloat) -> (UIImage?, String) {
        
        guard let inputImgData = imgData else {
            print("Input image data is nil.")
            return (nil, "")
        }
        
        self.va = va
        self.cs = va
        self.imgData = imgData
        
        filteredImg = applyFilter(to: inputImgData, va: va, cs: cs)!
        
        let nameComponents = imgName.split(separator: ".")
        let vaStr: String = va.description.replacingOccurrences(of: ".", with: "-", options: .literal, range: nil)
        let csStr: String = cs.description.replacingOccurrences(of: ".", with: "-", options: .literal, range: nil)
        self.filteredImgName = "\(nameComponents[0])_va\(vaStr)_cs\(csStr)"
        
        return (filteredImg, filteredImgName)
    }
    
    
    func saveFilteredImg() {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filteredImgName).appendingPathExtension("dng")
        
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
        
    }
    
    
    
    
    func readCSV(fromFilePath filePath: String) -> String? {
        do {
            let contents = try String(contentsOfFile: filePath)
            return contents
        } catch {
            print("Error reading file: \(error)")
            return nil
        }
    }
    
    
    func parseCSV(data: String) -> [CSVRow] {
        var rows: [CSVRow] = []
        let lines = data.components(separatedBy: CharacterSet.newlines)
        for line in lines.dropFirst() {
            let columns = line.split(separator: ",")
            if columns.count == 4,
               let va = Double(columns[0]),
               let cs = Double(columns[1]),
               let a = Double(columns[2]),
               let b = Double(columns[3]) {
                let row = CSVRow(va: va, cs: cs, a: a, b: b)
                rows.append(row)
            }
        }
        return rows
    }
    
    
    func findShift(_ va: CGFloat, _ cs: CGFloat) -> (hor: CGFloat, ver: CGFloat) {
        if let data = readCSV(fromFilePath: Bundle.main.path(forResource: "va_cs_matrix", ofType: "csv")!) {
            let rows = parseCSV(data: data)
            for row in rows {
                if row.va == va && row.cs == cs {
                    return (row.a, row.b)
                }
            }
        }
        return (0, 0)
    }
    
    private func angleOfView(_ sensorSize: CGFloat, _ focalLength: CGFloat) -> CGFloat {
        return 2 * atan(sensorSize / (2 * focalLength)) * (180 / Double.pi)
    }
    
    
    
    
    
    func createMeshGrid(_ imgHeight: Int, _ imgWidth: Int, _ vertAoV: Double, _ horAoV: Double) -> (ux: [[Double]], uy: [[Double]]) {
        let fx = stride(from: -CGFloat(imgWidth)/2, to: CGFloat(imgWidth)/2, by: 1).map { $0 / horAoV }
        let fy = stride(from: -CGFloat(imgHeight)/2, to: CGFloat(imgHeight)/2, by: 1).map { $0 / vertAoV }
        
        var ux = [[Double]](repeating: [Double](repeating: 0.0, count: fx.count), count: fy.count)
        var uy = [[Double]](repeating: [Double](repeating: 0.0, count: fx.count), count: fy.count)
        
        for (i, y) in fy.enumerated() {
            for (j, x) in fx.enumerated() {
                ux[i][j] = x
                uy[i][j] = y
            }
        }
        return (ux, uy)
    }
    
    
    
    
    func meanLum(image: CGImage, pixels: UnsafeMutableBufferPointer<Pixel>) -> (CGFloat, CGFloat, CGFloat) {
        let height = image.height
        let width = image.width
        let totalPixels = height * width
        var totalR: UInt64 = 0
        var totalG: UInt64 = 0
        var totalB: UInt64 = 0
        
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                var pixel = pixels[index]
                totalR += UInt64(pixel.red)
                totalG += UInt64(pixel.green)
                totalB += UInt64(pixel.blue)
            }
        }
        
        
        return (CGFloat(totalR)/CGFloat(totalPixels), CGFloat(totalG)/CGFloat(totalPixels), CGFloat(totalB)/CGFloat(totalPixels))
    }
    
    
    
    func shifting(image: UIImage, pixels: UnsafeMutableBufferPointer<Pixel>, va: CGFloat, cs: CGFloat){
        var horShift: CGFloat = 0
        var verShift: CGFloat = 0
        (horShift, verShift) = findShift(va, cs)
        print("HSHIFT: " + horShift.description)
        print("VSHIFT: " + verShift.description)
        
        let FOCAL_LENGTH = 6.86
        let horAoV = angleOfView(9.8, FOCAL_LENGTH)
        let vertAoV = angleOfView(7.3, FOCAL_LENGTH)
        let imgAngSize = horAoV * vertAoV
        
        let image = image.cgImage
        
        var ux: [[Double]]?
        var uy: [[Double]]?
        
        let height = image!.height
        let width = image!.width
        
//        (ux, uy) = createMeshGrid(height, width, vertAoV, horAoV)
//        
//        
//        var meanR: CGFloat = 0
//        var meanG: CGFloat = 0
//        var meanB: CGFloat = 0
//        (meanR, meanG, meanB) = meanLum(image: image!, pixels: pixels)
        
        
        // Vertical Shift
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                var pixel = pixels[index]
                if pixel.red != 255 {
                    let redValue = CGFloat(pixel.red)  // Convert the red component to CGFloat
                    let adjustedValue = 255 - redValue // Invert the red value
                    let scaledValue = adjustedValue * verShift // Apply the vertical shift scaling
                    let finalValue = 255 - scaledValue // Invert the value back
                    // Ensure the final value is within the 0-255 range and convert it to UInt8
                    pixel.red = UInt8(max(0, min(255, finalValue)))
                }
                if pixel.green != 255 {
                    let greenValue = CGFloat(pixel.green)
                    let adjustedValue = 255 - greenValue
                    let scaledValue = adjustedValue * verShift
                    let finalValue = 255 - scaledValue

                    pixel.green = UInt8(max(0, min(255, finalValue)))
                }
                if pixel.blue != 255 {
                    let blueValue = CGFloat(pixel.blue)
                    let adjustedValue = 255 - blueValue
                    let scaledValue = adjustedValue * verShift
                    let finalValue = 255 - scaledValue

                    pixel.blue = UInt8(max(0, min(255, finalValue)))
                }
                pixels[index] = pixel
            }
        }
        
        
        // Horizontal Shift
        
        
        
        
        
        //        let cgImage = image.cgImage
        //
        //        let width = cgImage!.width
        //        let height = cgImage!.height
        //
        //        for y in 0..<height {
        //            for x in 0..<width {
        //                let index = y * width + x
        //                var pixel = pixels[index]
        //
        //
        // Contrast
        //                pixel.red = UInt8(max(min(255, avgRed + 2 * redDelta), 0))
        //                pixel.blue = UInt8(max(min(255, avgBlue + 2 * blueDelta), 0))
        //                pixel.green = UInt8(max(min(255, avgGreen + 2 * greenDelta), 0))
        
        
        //Greyscale
        //                    let avg = Int(Double(Int(pixel.red) + Int(pixel.blue) + Int(pixel.green))/3.0)
        //                    let pixelColor = UInt8(avg)
        //                    pixel.red = pixelColor
        //                    pixel.blue = pixelColor
        //                    pixel.green = pixelColor
        //
        //
        //                pixels[index] = pixel
        //
        //            }
        //        }
        
        
        
        
    }
    
    
    
    
    func applyFilter(to imgData: Data, va: CGFloat, cs: CGFloat) -> UIImage? {
        
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
        
        let pixels = UnsafeMutableBufferPointer<Pixel>(start: imageData, count: width * height)
        print(pixels[4563454].red)
        print(pixels[4563454].green)
        print(pixels[4563454].blue)
        shifting(image: image, pixels: pixels, va: va, cs: cs)
        print("----")
        print(pixels[4563454].red)
        print(pixels[4563454].green)
        print(pixels[4563454].blue)
        
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
    
    
    
    struct CSVRow {
        let va: CGFloat
        let cs: CGFloat
        let a: CGFloat
        let b: CGFloat
    }
    
    
}
