import Accelerate
 
func performFFT(imageBuffer: UnsafeMutableBufferPointer<Pixel>, width: Int, height: Int) {
    // Assuming `imageBuffer` contains your image data.
    
    // Convert image data to grayscale float values.
    var grayscaleFloats = [Float](repeating: 0, count: width * height)
    for i in 0..<width * height {
        let pixel = imageBuffer[i]
        let grayscaleValue = 0.299 * Float(pixel.red) + 0.587 * Float(pixel.green) + 0.114 * Float(pixel.blue)
        grayscaleFloats[i] = grayscaleValue
    }
    
    // Prepare complex buffer for FFT.
    var forwardInputReal = [Float](grayscaleFloats)
    var forwardInputImag = [Float](repeating: 0, count: width * height)
    var forwardOutput = DSPSplitComplex(realp: &forwardInputReal, imagp: &forwardInputImag)
    
    let log2n = UInt(log2(Float(width * height)))
    let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))!
    
    // Perform FFT.
    vDSP_fft2d_zip(fftSetup, &forwardOutput, 1, 0, log2n, log2n, FFTDirection(FFT_FORWARD))
    
    // At this point, `forwardOutput` contains the FFT result.
    
    // Perform IFFT (optional, depends on your need).
    var inverseOutputReal = [Float](repeating: 0, count: width * height)
    var inverseOutputImag = [Float](repeating: 0, count: width * height)
    var inverseOutput = DSPSplitComplex(realp: &inverseOutputReal, imagp: &inverseOutputImag)
    
    vDSP_fft2d_zop(fftSetup, &forwardOutput, 1, 0, &inverseOutput, 1, 0, log2n, log2n, FFTDirection(FFT_INVERSE))
    
    // Normalize the IFFT result.
    var scale = Float(width * height)
    vDSP_vsdiv(inverseOutput.realp, 1, &scale, inverseOutput.realp, 1, vDSP_Length(width * height))
    vDSP_vsdiv(inverseOutput.imagp, 1, &scale, inverseOutput.imagp, 1, vDSP_Length(width * height))
    
    // `inverseOutput` now contains the IFFT result.
    // You might want to convert this back to your desired image format.
    
    vDSP_destroy_fftsetup(fftSetup)
}
