
import Foundation
import SwiftUI

class LinearFilterViewModel: ObservableObject {
    
    private let model: LinearFilterModel
    
    @Published var showFilteredImg : Bool = false
    
    @Published var filteredImg: UIImage?
    @Published var va: String = "0.31"
    @Published var cs: String = "1.78"
    @Published var filteredImgName = "null"
    
    init(_ model: LinearFilterModel) {
        self.model = model
    }
    
    
    func filterImage(_ originalImgData: Data?, _ imgName: String) {
        if (imgName != "null") {
            showFilteredImg = true
            
            var va_f: Float = 0
            var cs_f: Float = 0
            
            if originalImgData != nil {
                if let n = NumberFormatter().number(from: va) {
                    va_f = Float(truncating: n)
                }
                if let n = NumberFormatter().number(from: cs) {
                    cs_f = Float(truncating: n)
                }
                
                (filteredImg, filteredImgName)  = model.addFilter(originalImgData, imgName, va_f, cs_f)
            }
            
        }
    }
    
    
    func saveFilteredImage() {
        model.saveFilteredImg()
    }
    
    
    
}
