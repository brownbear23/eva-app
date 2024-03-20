
import Foundation
import UIKit
import Photos
import Accelerate

class LinearFilterModel: ObservableObject {
    
    var filteredImg: UIImage = UIImage()
    var va: Double = 0
    var cs: Double = 0
    var imgData: Data?
    var filteredImgName: String = "null"
    
    func addFilterSample(_ imgData: Data?, _ imgName: String, _ va: Double, _ cs: Double) -> (UIImage?, String) {
        
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
    
    
    func findShift(_ va: Double, _ cs: Double) -> (hor: Double, ver: Double) {
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
    
    private func angleOfView(_ sensorSize: Double, _ focalLength: Double) -> Double {
        return 2 * atan(sensorSize / (2 * focalLength)) * (180 / Double.pi)
    }
    
    
    
    
    
    func createMeshGrid(_ imgHeight: Int, _ imgWidth: Int, _ vertAoV: Double, _ horAoV: Double) -> (ux: [[Double]], uy: [[Double]]) {
        let fx = stride(from: -Double(imgWidth)/2, to: Double(imgWidth)/2, by: 1).map { $0 / horAoV }
        let fy = stride(from: -Double(imgHeight)/2, to: Double(imgHeight)/2, by: 1).map { $0 / vertAoV }
        
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
    
    
    
    
    func meanLum(image: CGImage, pixels: UnsafeMutableBufferPointer<Pixel>) -> (Double, Double, Double) {
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
        
        
        return (Double(totalR)/Double(totalPixels), Double(totalG)/Double(totalPixels), Double(totalB)/Double(totalPixels))
    }
    
    
    func sSF0(ux: [[Double]], uy: [[Double]]) -> [[Double]] {
        let yCount = ux.count
        let xCount = ux[0].count
        var retSSF0 = [[Double]](repeating: [Double](repeating: 0.0, count: xCount), count: yCount)
        for y in 0..<yCount {
            for x in 0..<xCount {
                retSSF0[y][x] = sqrt(ux[y][x]*ux[y][x] + uy[y][x]*uy[y][x] + 0.0001)
            }
        }
        return retSSF0
    }
    
    func sSF(sSF0: [[Double]], horShift: Double) -> [[Double]] {
        let yCount = sSF0.count
        let xCount = sSF0[0].count
        var retSSF = [[Double]](repeating: [Double](repeating: 0.0, count: xCount), count: yCount)
        
        for y in 0..<yCount {
            for x in 0..<xCount {
                retSSF[y][x] = sSF0[y][x] * horShift
            }
        }
        return retSSF
    }
    
    func csf(meanLum: Double, sSF_0: [[Double]], imgAngSize: Double) -> [[Double]] {
        let yCount = sSF_0.count
        let xCount = sSF_0[0].count
        var retCsf = [[Double]](repeating: [Double](repeating: 0.0, count: xCount), count: yCount)
        for y in 0..<yCount {
            for x in 0..<xCount {
                var sSFEl = sSF_0[y][x]
                retCsf[y][x] = 5200 * exp(-0.0016*pow((100/meanLum+1), 0.08) * pow(sSFEl, 2)) / sqrt((0.64 * pow(sSFEl, 2) + 144/imgAngSize + 1) * (1/(1-exp(-0.02 * pow(sSFEl, 2)))) + 63/pow(meanLum, 0.83)) //TODO: GT again
            }
        }
        return retCsf
    }
    
    func nCSF(CSF: [[Double]], CSF0: [[Double]]) -> [[Double]] {
        let yCount = CSF.count
        let xCount = CSF[0].count
        var retNCsf = [[Double]](repeating: [Double](repeating: 0.0, count: xCount), count: yCount)
        for y in 0..<yCount {
            for x in 0..<xCount {
                retNCsf[y][x] = CSF[y][x] / CSF0[y][x]
                }
        }
        retNCsf = fftshift(retNCsf)
        
        
        for i in 0..<retNCsf.count {
            for j in 0..<retNCsf[i].count {
                if retNCsf[i][j] > 1 {
                    retNCsf[i][j] = 1
                }
            }
        }
        retNCsf[0][0] = 1
        return retNCsf
    }
    
    

    func fftshift(_ matrix: [[Double]]) -> [[Double]] {
        let rowCount = matrix.count
        let columnCount = matrix.first?.count ?? 0

        // Check for empty matrix or non-rectangular input
        guard rowCount > 0, columnCount > 0, matrix.allSatisfy({ $0.count == columnCount }) else {
            return [[]]
        }

        // Calculate midpoints
        let midRow = rowCount / 2
        let midColumn = columnCount / 2

        // Initialize a new matrix with the same size
        var shiftedMatrix = Array(repeating: Array(repeating: 0.0, count: columnCount), count: rowCount)

        for i in 0..<rowCount {
            for j in 0..<columnCount {
                // Calculate new positions
                let newI = (i + midRow) % rowCount
                let newJ = (j + midColumn) % columnCount

                // Swap elements
                shiftedMatrix[newI][newJ] = matrix[i][j]
            }
        }

        return shiftedMatrix
    }
    
    
    
    func fft(image: CGImage, pixels: UnsafeMutableBufferPointer<Pixel>) -> UnsafeMutableBufferPointer<Pixel> {
        return pixels
    }

    
    
    


    
    
    func shifting(image: UIImage, pixels: UnsafeMutableBufferPointer<Pixel>, va: Double, cs: Double){
        var horShift: Double = 0
        var verShift: Double = 0
        (horShift, verShift) = findShift(va, cs)
        print("HSHIFT: " + horShift.description)
        print("VSHIFT: " + verShift.description)
        
        
        let image = image.cgImage
        let height = image!.height
        let width = image!.width
        
        
        
        // Vertical Shift
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x
                var pixel = pixels[index]
                if pixel.red != 255 {
                    let redValue = Double(pixel.red)  // Convert the red component to Double
                    let adjustedValue = 255 - redValue // Invert the red value
                    let scaledValue = adjustedValue * verShift // Apply the vertical shift scaling
                    let finalValue = 255 - scaledValue // Invert the value back
                    // Ensure the final value is within the 0-255 range and convert it to UInt8
                    pixel.red = UInt8(max(0, min(255, finalValue)))
                }
                if pixel.green != 255 {
                    let greenValue = Double(pixel.green)
                    let adjustedValue = 255 - greenValue
                    let scaledValue = adjustedValue * verShift
                    let finalValue = 255 - scaledValue
                    
                    pixel.green = UInt8(max(0, min(255, finalValue)))
                }
                if pixel.blue != 255 {
                    let blueValue = Double(pixel.blue)
                    let adjustedValue = 255 - blueValue
                    let scaledValue = adjustedValue * verShift
                    let finalValue = 255 - scaledValue
                    
                    pixel.blue = UInt8(max(0, min(255, finalValue)))
                }
                pixels[index] = pixel
            }
        }
        
        // Horizontal Shift
        
        let FOCAL_LENGTH = 6.86
        let horAoV = angleOfView(9.8, FOCAL_LENGTH)
        let vertAoV = angleOfView(7.3, FOCAL_LENGTH)
        let imgAngSize = horAoV * vertAoV
        
        var ux: [[Double]]?
        var uy: [[Double]]?
        (ux, uy) = createMeshGrid(height, width, vertAoV, horAoV)
        
        
        
        
        
        var meanR: Double = 0
        var meanG: Double = 0
        var meanB: Double = 0
        (meanR, meanG, meanB) = meanLum(image: image!, pixels: pixels)
        
        
        let sSF0: [[Double]] = sSF0(ux: ux!, uy: uy!)
        let sSF: [[Double]] = sSF(sSF0: sSF0, horShift: horShift)
        
        
        
        
        var count = 0;
        for meanLum in [meanR, meanG, meanB] {
            let CSF0: [[Double]] = csf(meanLum: meanLum, sSF_0: sSF0, imgAngSize: imgAngSize)
            let CSF: [[Double]] = csf(meanLum: meanLum, sSF_0: sSF, imgAngSize: imgAngSize)
            
            let nCSF: [[Double]] = nCSF(CSF: CSF, CSF0: CSF0)
              
            
            //Y = np.fft.fft2(thisimage)
            //filtImg = np.fft.ifft2(nCSF*Y)
            //finalImg[:,:,j] = filtImg.astype(np.uint8)
            let filtImg: [[Double]] = [[0, 1, 2]]
            
            
            for y in 0..<height {
                for x in 0..<width {
                    let index = y * width + x
                    var pixel = pixels[index]
                    if count == 0 {
                        pixel.red = UInt8(filtImg[y][x])
                        pixels[index] = pixel
                    } else if count == 1 {
                        pixel.green = UInt8(filtImg[y][x])
                        pixels[index] = pixel
                    } else {
                        pixel.blue = UInt8(filtImg[y][x])
                        pixels[index] = pixel
                    }
                    
                }
            }
            count+=1
        }
        
        
    }
    
    
    
    
    func applyFilter(to imgData: Data, va: Double, cs: Double) -> UIImage? {
        
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
        
        shifting(image: image, pixels: pixels, va: va, cs: cs)
        
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
        let va: Double
        let cs: Double
        let a: Double
        let b: Double
    }
    
    
}
