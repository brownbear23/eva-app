//
//  PhotoCaptureLabelView.swift
//  EVALabel
//
//  Created by Bill Han on 1/15/24.
//

import SwiftUI
import Foundation

struct PhotoCaptureLabelView: View {
    @ObservedObject var viewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            Color.yellow.ignoresSafeArea()
            
            viewModel.cameraPreview.ignoresSafeArea().onAppear {
                viewModel.configure()
            }
            .alert(isPresented: $viewModel.lowResolutionWarning) {
                Alert(
                    title: Text("Warning"),
                    message: Text("This device does not support \n8064 x 6048 resolution."),
                    dismissButton: .default(Text("OK"))
                )
            }
            
                
            
            VStack {
                HStack(alignment: .top) {
                    // Shutter sound btn
                    Button(action: {viewModel.switchSilent()}) { //Label btn
                        Image(systemName: viewModel.isSilentModeOn ? "speaker.fill" : "speaker").foregroundColor(viewModel.isSilentModeOn ? .yellow : .white)
                    }
                    Spacer()
                    Text("\(viewModel.selectedHazard) _ ID\(viewModel.selectedId) _ \(viewModel.selectedDistance)m _ \(viewModel.selectedLevel) _ ANGLE\(viewModel.selectedAngle) _ \(viewModel.selectedLux)lux.DNG").font(.system(size: 12)).padding(.horizontal)
                    Spacer()
                    Button(action: {viewModel.showSetting = true}) { //Photo collection view
                        Image(systemName: "gear")
                            .foregroundColor(.white)
                            .font(.system(size: 25))
                    }
                    
                    
                }
                .padding(.horizontal, 10)
                .padding(.top, 20)
                .font(.system(size: 25))
                
                Spacer()
                
                HStack {
                    
                    Button(action: {viewModel.showPreview = true}) { //Photo collection view
                        if let previewImage = viewModel.recentImage {
                            Image(uiImage: previewImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 70, height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 15))
                                .aspectRatio(1, contentMode: .fit)
                                .padding()
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(lineWidth: 3)
                                .frame(width: 70, height: 70)
                                .padding()
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {viewModel.capturePhoto()}) {
                        Circle()
                            .stroke(lineWidth: 5)
                            .frame(width: 75, height: 75)
                            .padding()
                    }
                    
                    Spacer()
                    Spacer()
                    Spacer()
                    
                    
                }
                
            }
            .foregroundColor(.white)
        }
        .opacity(viewModel.shutterEffect ? 0 : 1)
        .fullScreenCover(isPresented: $viewModel.showPreview) {
            Image(uiImage: viewModel.recentImage ?? UIImage())
                .resizable()
                .scaledToFit()
                .frame(width: UIScreen.main.bounds.width,
                       height: UIScreen.main.bounds.height)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.showPreview = false
                }
        }
        .fullScreenCover(isPresented: $viewModel.showSetting) {
            VStack {
                HStack {
                    Button(action: {viewModel.saveLabel()}) { //Photo collection view
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.black)
                            .font(.system(size: 25))
                    }
                    .padding(.leading, 15)
                    
                    // Button(action: {UIApplication.shared.windows.filter {$0.isKeyWindow}.first?.endEditing(true)}) {
                    Button(action: {
                        if let mainWindow = UIApplication.shared.connectedScenes
                            .compactMap({ $0 as? UIWindowScene })
                            .first(where: { $0.activationState == .foregroundActive })?
                            .windows
                            .first(where: { $0.isKeyWindow }) {
                            mainWindow.endEditing(true)
                        }
                    }) {
                        Image(systemName: "keyboard.chevron.compact.down")
                            .foregroundColor(.black)
                            .font(.system(size: 20))
                    }
                    .padding(.leading, 15)
                    
                    Spacer()
                }.padding(.bottom, 10)
                
                
                
                VStack {
                    
                    Text("\(viewModel.selectedHazard) _ ID\(viewModel.selectedId) _ \(viewModel.selectedDistance)m _ \(viewModel.selectedLevel) _ ANGLE\(viewModel.selectedAngle) _ \(viewModel.selectedLux)lux.DNG").font(.system(size: 12)).padding(.horizontal)
                    
                    Divider().padding(.horizontal)
                    
                    HStack{
                        Text("ID:         ")
                        TextField(
                            "Enter the ID",
                            text: $viewModel.selectedId
                        ).padding(.horizontal).textFieldStyle(.roundedBorder).foregroundColor(Color(UIColor.lightGray)).keyboardType(.numberPad)
                    }.padding(.horizontal)
                    
                    
                    Divider().padding(.horizontal)
                    
                    
                    Text("Distance (m)")
                    if let distanceList = viewModel.distances {
                        Picker("Distances", selection: $viewModel.selectedDistance) {
                            ForEach(0 ..< distanceList.count, id: \.self) { index in
                                Text(String(distanceList[index])).tag(distanceList[index])
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                    }
                    
                    
                    Divider().padding(.horizontal)
                    
                    Text("Height")
                    if let levelList = viewModel.levels {
                        Picker("Height", selection: $viewModel.selectedLevel) {
                            ForEach(0 ..< levelList.count, id: \.self) { index in
                                Text(String(levelList[index])).tag(levelList[index])
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 20)
                        
                    }
                    
                    
                    Divider().padding(.horizontal)
                    
                    HStack{
                        Text("Angle #:")
                        TextField(
                            "Enter the angle",
                            text: $viewModel.selectedAngle
                        ).padding(.horizontal).textFieldStyle(.roundedBorder).foregroundColor(Color(UIColor.lightGray)).keyboardType(.numberPad)
                    }.padding(.horizontal)
                    
                    
                    
                    
                    
                    Divider().padding(.horizontal)
                    
                    HStack{
                        Text("Lux:       ")
                        TextField(
                            "Enter the lux",
                            text: $viewModel.selectedLux
                        ).padding(.horizontal).textFieldStyle(.roundedBorder).foregroundColor(Color(UIColor.lightGray)).keyboardType(.numberPad)
                    }.padding(.horizontal)
                    
                    
                    
                    Divider().padding(.horizontal)
                    
                    
                    Text("Hazards")
                    if let hazardList = viewModel.filteredHazards {
                        NavigationStack {
                            List {
                                
                                ForEach(0 ..< hazardList.count, id: \.self) { index in
                                    Text(String(hazardList[index]))
                                        .onTapGesture {
                                            viewModel.selectedHazard = hazardList[index]
                                        }
                                }
                                
                            }
                            .listStyle(.plain)
                            .searchable(text: $viewModel.searchText)
                        }
                    }
                }
            }
        }
    }
}


#Preview {
    PhotoCaptureLabelView()
}
