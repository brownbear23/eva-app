//
//  FilterUtility.swift
//  EVALabel
//
//  Created by Bill Han on 3/30/24.
//

import Foundation

import Accelerate

struct CSVRow {
    let va: Float
    let cs: Float
    let a: Float
    let b: Float
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
           let va = Float(columns[0]),
           let cs = Float(columns[1]),
           let a = Float(columns[2]),
           let b = Float(columns[3]) {
            let row = CSVRow(va: va, cs: cs, a: a, b: b)
            rows.append(row)
        }
    }
    return rows
}


func findShift(_ va: Float, _ cs: Float) -> (hor: Float, ver: Float) {
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


func createMeshGrid(_ imgHeight: Int, _ imgWidth: Int, _ vertAoV: Float, _ horAoV: Float) -> (ux: [[Float]], uy: [[Float]]) {
    let fx = stride(from: -Float(imgWidth)/2, to: Float(imgWidth)/2, by: 1).map { $0 / horAoV }
    let fy = stride(from: -Float(imgHeight)/2, to: Float(imgHeight)/2, by: 1).map { $0 / vertAoV }
    
    var ux = [[Float]](repeating: [Float](repeating: 0.0, count: fx.count), count: fy.count)
    var uy = [[Float]](repeating: [Float](repeating: 0.0, count: fx.count), count: fy.count)
    
    for (i, y) in fy.enumerated() {
        for (j, x) in fx.enumerated() {
            ux[i][j] = x
            uy[i][j] = y
        }
    }
    return (ux, uy)
}



func angleOfView(_ sensorSize: Float, _ focalLength: Float) -> Float {
    return 2 * atan(sensorSize / (2 * focalLength)) * (180 / Float.pi)
}


func meanLum(image: CGImage, pixels: UnsafeMutableBufferPointer<LinearFilterModel.Pixel>) -> (Float, Float, Float) {
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
    
    
    return (Float(totalR)/Float(totalPixels), Float(totalG)/Float(totalPixels), Float(totalB)/Float(totalPixels))
}



func sSF0(ux: [[Float]], uy: [[Float]]) -> [[Float]] {
    let yCount = ux.count
    let xCount = ux[0].count
    var retSSF0 = [[Float]](repeating: [Float](repeating: 0.0, count: xCount), count: yCount)
    for y in 0..<yCount {
        for x in 0..<xCount {
            retSSF0[y][x] = sqrt(ux[y][x]*ux[y][x] + uy[y][x]*uy[y][x] + 0.0001)
        }
    }
    return retSSF0
}

func sSF(sSF0: [[Float]], horShift: Float) -> [[Float]] {
    let yCount = sSF0.count
    let xCount = sSF0[0].count
    var retSSF = [[Float]](repeating: [Float](repeating: 0.0, count: xCount), count: yCount)
    
    for y in 0..<yCount {
        for x in 0..<xCount {
            retSSF[y][x] = sSF0[y][x] * horShift
        }
    }
    return retSSF
}

func csf(meanLum: Float, sSF_0: [[Float]], imgAngSize: Float) -> [[Float]] {
    let yCount = sSF_0.count
    let xCount = sSF_0[0].count
    var retCsf = [[Float]](repeating: [Float](repeating: 0.0, count: xCount), count: yCount)
    for y in 0..<yCount {
        for x in 0..<xCount {
            let sSFEl = sSF_0[y][x]
            retCsf[y][x] = 5200 * exp(-0.0016*pow((100/meanLum+1), 0.08) * pow(sSFEl, 2)) / sqrt((0.64 * pow(sSFEl, 2) + 144/imgAngSize + 1) * (1/(1-exp(-0.02 * pow(sSFEl, 2)))) + 63/pow(meanLum, 0.83)) 
        }
    }
    return retCsf
}

func nCSF(CSF: [[Float]], CSF0: [[Float]]) -> [[Float]] {
    let yCount = CSF.count
    let xCount = CSF[0].count
    var retNCsf = [[Float]](repeating: [Float](repeating: 0.0, count: xCount), count: yCount)
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



func fftshift(_ matrix: [[Float]]) -> [[Float]] {
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
    var shiftedMatrix: [[Float]] = Array(repeating: Array(repeating: 0.0, count: columnCount), count: rowCount)
    
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









func performFFT(serialImagePixels: inout [Float], width: Int, height: Int) -> (real: [Float], imag: [Float]) {
    
    // Initialize the arrays for the real and imaginary parts of the complex numbers
    var complexReals = [Float](repeating: 0, count: width * height)
    var complexImaginaries = [Float](repeating: 0, count: width * height)
    
    complexReals = serialImagePixels
    
    complexReals.withUnsafeMutableBufferPointer { realPtr in
        complexImaginaries.withUnsafeMutableBufferPointer { imagPtr in
              
            var splitComplex = DSPSplitComplex(
                realp: realPtr.baseAddress!,
                imagp: imagPtr.baseAddress!)
            
            var output = Array(UnsafeBufferPointer(start: splitComplex.realp, count: width * height))
            printValues("before FFT", realPart: output, width: width, height: height)
            
            // The binary logarithm of `max(rowCount, columnCount)`.
            let setupLog2n = vDSP_Length(log2(Float(max(width, height))))

            let widthLog2n = vDSP_Length(log2(Float(width)))
            let heightLog2n = vDSP_Length(log2(Float(height)))
            
//            let widthLog2n = vDSP_Length(Float(width))
//            let heightLog2n = vDSP_Length(Float(height))
 
            
            
            if let fft = vDSP_create_fftsetup(setupLog2n, FFTRadix(kFFTRadix2)) {
                
                vDSP_fft2d_zip(fft, &splitComplex,
                               1, 0,
                               widthLog2n, heightLog2n,
                               FFTDirection(kFFTDirection_Forward))
                
                vDSP_destroy_fftsetup(fft)
            }
            
            output = Array(UnsafeBufferPointer(start: splitComplex.realp, count: width * height))
            printValues("after FFT", realPart: output, width: width, height: height)
        }
    }
    return (complexReals, complexImaginaries)
}



func performIFFT(inputPixels: inout (real: [Float], imag: [Float]), width: Int, height: Int) -> (real: [Float], imag: [Float]) {
    
    // Initialize the arrays for the real and imaginary parts of the complex numbers
    var complexReals = [Float](repeating: 0, count: width * height)
    var complexImaginaries = [Float](repeating: 0, count: width * height)
    
    complexReals = inputPixels.real
    complexImaginaries = inputPixels.imag
    
    
    complexReals.withUnsafeMutableBufferPointer { realPtr in
        complexImaginaries.withUnsafeMutableBufferPointer { imagPtr in
            
            var splitComplex = DSPSplitComplex(
                realp: realPtr.baseAddress!,
                imagp: imagPtr.baseAddress!)
            
            var output = Array(UnsafeBufferPointer(start: splitComplex.realp, count: width * height))
//            printValues("before ifft", realPart: output, width: width, height: height)
            
            // The binary logarithm of `max(rowCount, columnCount)`.
            let widthLog2n = vDSP_Length(log2(Float(width)))
            let heightLog2n = vDSP_Length(log2(Float(height)))
            
            
            if let fft = vDSP_create_fftsetup(max(widthLog2n, heightLog2n), FFTRadix(kFFTRadix2)) {
                
                vDSP_fft2d_zip(fft, &splitComplex,
                               1, 0,
                               widthLog2n, heightLog2n,
                               FFTDirection(kFFTDirection_Inverse))
                
                vDSP_destroy_fftsetup(fft)
            }
            
            output = Array(UnsafeBufferPointer(start: splitComplex.realp, count: width * height))
//            printValues("post ifft", realPart: output, width: width, height: height)
        }
    }
    return (complexReals, complexImaginaries)
}





func printValues(_ stage: String, realPart: [Float], width: Int, height: Int) {
    print("---Pixels \(stage)---")
    print("[0][0]: \(realPart[0])")
    print("[0][1]: \(realPart[1])")
    print("[1][0]: \(realPart[width])")
    print("[1][1]: \(realPart[width + 1])")
    
    print("[height-2][0]: \(realPart[width*(height-2)])")
    print("[height-2][width-2]: \(realPart[width*(height-2)+width-2])")
    print("[height-2][width-1]: \(realPart[width*(height-2)+width-1])")
    print("[height-1][width-2]: \(realPart[width*(height-1)+width-2])")
    print("[height-1][width-1]: \(realPart[width*(height-1)+width-1])")
}




func arrayEleMul(nCSF: [[Float]], Y: (real: [Float], imag: [Float]), width: Int, height: Int) -> (real: [Float], imag: [Float]) {
    // Flatten the 2D array 'nCSF' and create a complex array with imaginary parts set to zero
    let flattenedReal = nCSF.flatMap { $0 }
    let imaginaryZeros = [Float](repeating: 0, count: width * height)
    
    // Check dimensions
    guard Y.real.count == width * height, Y.imag.count == width * height else {
        fatalError("Dimensions of Y do not match the provided width and height")
    }
    
    // Prepare memory for DSPSplitComplex structures for nCSF and Y
    let nCSFReal = flattenedReal.withUnsafeBufferPointer { $0.baseAddress! }
    let nCSFImag = imaginaryZeros.withUnsafeBufferPointer { $0.baseAddress! }
    var nCSFComplex = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: nCSFReal), imagp: UnsafeMutablePointer(mutating: nCSFImag))
    
    let YReal = Y.real.withUnsafeBufferPointer { $0.baseAddress! }
    let YImag = Y.imag.withUnsafeBufferPointer { $0.baseAddress! }
    var YComplex = DSPSplitComplex(realp: UnsafeMutablePointer(mutating: YReal), imagp: UnsafeMutablePointer(mutating: YImag))
    
    // Prepare arrays for the result
    var resultReal = [Float](repeating: 0, count: width * height)
    var resultImag = [Float](repeating: 0, count: width * height)
    
    // Perform element-wise multiplication
    resultReal.withUnsafeMutableBufferPointer { realPtr in
        resultImag.withUnsafeMutableBufferPointer { imagPtr in
            var resultComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
            vDSP_zvmul(&nCSFComplex, 1, &YComplex, 1, &resultComplex, 1, vDSP_Length(width * height), 1)
        }
    }
    
    // Return the results as a tuple of real and imaginary parts
    return (real: resultReal, imag: resultImag)
}









func scaleOutput(_ data: inout DSPSplitComplex, height: Int, width: Int) {
    let totalElements = vDSP_Length(height * width)
    var scaleFactor: Float = 0.0000156  // Adjust the scale factor according to your needs
    //    scaleFactor = 1 / sqrt(Float(height * width))  // Adjust the scale factor according to your needs
    
    // Scale the real part
    vDSP_vsmul(data.realp, 1, [scaleFactor], data.realp, 1, totalElements)
    
    // Scale the imaginary part
    //        vDSP_vsmul(data.imagp, 1, [scaleFactor], data.imagp, 1, totalElements)
}



func convertTo2DMatrixAndSaveToFile(serialImagePixels: UnsafeMutableBufferPointer<LinearFilterModel.Pixel>, width: Int, height: Int) {
    // Initialize 2D arrays for each color channel
    var redChannel = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)
    var greenChannel = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)
    var blueChannel = [[UInt8]](repeating: [UInt8](repeating: 0, count: width), count: height)

    // Iterate over each pixel and assign color values to the 2D arrays
    for y in 0..<height {
        for x in 0..<width {
            let index = y * width + x
            let pixel = serialImagePixels[index]
            redChannel[y][x] = pixel.red
            greenChannel[y][x] = pixel.green
            blueChannel[y][x] = pixel.blue
        }
    }

    // Convert the 2D arrays into strings
    let redString = redChannel.map { $0.map(String.init).joined(separator: ", ") }.joined(separator: "\n")
    let greenString = greenChannel.map { $0.map(String.init).joined(separator: ", ") }.joined(separator: "\n")
    let blueString = blueChannel.map { $0.map(String.init).joined(separator: ", ") }.joined(separator: "\n")

    // Write the color channel data to text files
    saveToTextFile(content: redString, fileName: "redChannel.txt")
    saveToTextFile(content: greenString, fileName: "greenChannel.txt")
    saveToTextFile(content: blueString, fileName: "blueChannel.txt")
}

func saveToTextFile(content: String, fileName: String) {
    guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("Failed to access document directory")
        return
    }
    let fileURL = documentDirectory.appendingPathComponent(fileName)

    do {
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        print("File saved successfully at \(fileURL)")
    } catch {
        print("Failed to write to file: \(error)")
    }
}

