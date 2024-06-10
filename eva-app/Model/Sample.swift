
import Foundation
import UIKit
import Photos



func applyFilter(to image: UIImage) -> UIImage? {
//        guard let cgImage = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .up).cgImage else { return nil }
       guard let cgImage = image.cgImage else { return nil }
               
//        switch image.imageOrientation {
//            case .right, .rightMirrored:
//                print("RIGHT")
//            case .left, .leftMirrored:
//                print("LEFT")
//            case .down, .downMirrored:
//                print("DOWN")
//            default:
//                break
//            }
               

       
       // Redraw image for correct pixel format
       var colorSpace = CGColorSpaceCreateDeviceRGB()
       
       var bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Big.rawValue
       bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
       

       let width = Int(image.size.width)
       let height = Int(image.size.height)
       var bytesPerRow = width * 4
       
       let imageData = UnsafeMutablePointer<Pixel>.allocate(capacity: width * height)
       
       guard let imageContext = CGContext(
           data: imageData,
           width: width,
           height: height,
           bitsPerComponent: 8,
           bytesPerRow: bytesPerRow,
           space: colorSpace,
           bitmapInfo: bitmapInfo
       ) else { return nil }
       
       
       
//        switch image.imageOrientation {
//            case .right, .rightMirrored:
//                imageContext.rotate(by: -CGFloat.pi / 2)
//                imageContext.translateBy(x: -CGFloat(height), y: 0)
//            case .left, .leftMirrored:
//                imageContext.rotate(by: CGFloat.pi / 2)
//                imageContext.translateBy(x: 0, y: -CGFloat(width))
//            case .down, .downMirrored:
//                imageContext.rotate(by: CGFloat.pi)
//                imageContext.translateBy(x: -CGFloat(width), y: -CGFloat(height))
//            default:
//                break
//            }
       
       
       
       
       imageContext.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
       
       let pixels = UnsafeMutableBufferPointer<Pixel>(start: imageData, count: width * height)
       
//        var totalRed = 0
//        var totalGreen = 0
//        var totalBlue = 0
//        let pixelArea = width * height
       
//        for y in 0..<height {
//            for x in 0..<width {
//                let index = y * width + x
//                let pixel = pixels[index]
//
//                totalRed += Int(pixel.red)
//                totalGreen += Int(pixel.green)
//                totalBlue += Int(pixel.blue)
//            }
//        }
          

       
//        let avgRed = totalRed / pixelArea
//        let avgGreen = totalGreen / pixelArea
//        let avgBlue = totalBlue / pixelArea
       
//        for y in 0..<height {
//            for x in 0..<width {
//                let index = x * width + y
//                var pixel = pixels[index]
               
               
               
//                let redDelta = Int(pixel.red) - avgRed
//                let greenDelta = Int(pixel.green) - avgGreen
//                let blueDelta = Int(pixel.blue) - avgBlue
               
               
               
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
   
               
//                pixels[index] = pixel
//            }
//        }
       

       
       
       colorSpace = CGColorSpaceCreateDeviceRGB()
       bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue
       bitmapInfo |= CGImageAlphaInfo.premultipliedLast.rawValue & CGBitmapInfo.alphaInfoMask.rawValue
       
       bytesPerRow = width * 4
       
       guard let context = CGContext(
           data: pixels.baseAddress,
           width: width,
           height: height,
           bitsPerComponent: 8,
           bytesPerRow: bytesPerRow,
           space: colorSpace,
           bitmapInfo: bitmapInfo,
           releaseCallback: nil,
           releaseInfo: nil
       ) else { return nil }
       
       
       guard let newCGImage = context.makeImage() else { return nil }
       return UIImage(cgImage: newCGImage)
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



//func performFFT(serialImagePixels: inout [Float], width: Int, height: Int, inverse: Bool) -> [Float] {
//    let realWidth = width
//    let realHeight = height
//    let complexValuesWidth = realWidth / 2 + 1
//    let complexValuesHeight = realHeight
//    
//    let complexElementCount = complexValuesWidth * complexValuesHeight
//    var complexReals = [Float](repeating: 0, count: complexElementCount)
//    var complexImaginaries = [Float](repeating: 0, count: complexElementCount)
//
//    serialImagePixels.withUnsafeBufferPointer { bufferPtr in
//        var splitComplex = DSPSplitComplex(realp: &complexReals, imagp: &complexImaginaries)
//        
//        bufferPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: complexElementCount) { complexPtr in
//            vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(complexElementCount))
//        }
//        
//        let rowCountLog2n = vDSP_Length(log2(Float(realHeight)))
//        let columnCountLog2n = vDSP_Length(log2(Float(complexValuesWidth)))
//        
//        if let fftSetup = vDSP_create_fftsetup(max(rowCountLog2n, columnCountLog2n), FFTRadix(kFFTRadix2)) {
//            vDSP_fft2d_zrip(fftSetup, &splitComplex, 1, 0, rowCountLog2n, columnCountLog2n, FFTDirection(kFFTDirection_Forward))
//            vDSP_destroy_fftsetup(fftSetup)
//        }
//    }
//    
//    return complexReals
//}
