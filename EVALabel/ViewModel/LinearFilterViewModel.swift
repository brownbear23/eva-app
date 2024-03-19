
import Foundation
import SwiftUI

class LinearFilterViewModel: ObservableObject {
    
    private let model: LinearFilterModel
    
    @Published var showFilteredImg : Bool = false
    
    @Published var filteredImg: UIImage?
    @Published var va: String = "1.38"
    @Published var cs: String = "0.7"
    @Published var filteredImgName = "null"
    
    init(_ model: LinearFilterModel) {
        self.model = model
    }
    
    
    func filterImage(_ originalImgData: Data?, _ imgName: String) {
        if (imgName != "null") {
            showFilteredImg = true
            
            var va_f: CGFloat = 0
            var cs_f: CGFloat = 0
            
            if originalImgData != nil {
                if let n = NumberFormatter().number(from: va) {
                    va_f = CGFloat(truncating: n)
                }
                if let n = NumberFormatter().number(from: cs) {
                    cs_f = CGFloat(truncating: n)
                }
                
                (filteredImg, filteredImgName)  = model.addFilterSample(originalImgData, imgName, va_f, cs_f)
            }
            
        }
    }
    
    
    func saveFilteredImage() {
        model.saveFilteredImg()
    }
    
    
    
}
