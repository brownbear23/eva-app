//
//  ContentView.swift
//  EVALabel
//
//  Created by Bill Han on 1/8/24.
//

import SwiftUI

enum StackViewType {
    case profileView
    case luminanceTestView
}

struct IntroView: View {
    
    @State var path: [StackViewType] = []
    
    var body: some View {
        
        NavigationStack(path: $path) {
            Group {
                HStack (alignment: .center) {
                    Text("JHU EVA Lab")
                        .font(.system(size: 24, weight: .bold))
                        .padding(.leading, 15)
                        .padding(.bottom, 8)
                    
                    Spacer()
                    
                    Button(
                        action: {path.append(.profileView)},
                        label: {
                            Text("My")
                                .padding(7)
                        }
                    )
                    .foregroundColor(.white)
                    .font(.system(size: 18))
                    .background(Circle().fill(Color.orange))
                    .padding(.trailing, 15)
                    .padding(.bottom, 8)
                    
                    
                }
                .background(Color.blue)
                
                
                VStack () {
                    
                    Button(
                        action: {path.append(.luminanceTestView)},
                        label: {
                            Text("Luminance Contrast Test")
                                .foregroundColor(.white)
                        })
                    .padding([.vertical])
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    
                    
                    Button(
                        action: {},
                        label: {
                            Text("LiDar Test")
                                .foregroundColor(.white)
                        })
                    .padding([.vertical])
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                }
                .padding()
                Spacer()
            }
            .navigationDestination(for: StackViewType.self) { stackViewType in
                switch stackViewType {
                case .profileView:
                    ProfileView()
                case .luminanceTestView:
                    LuminanceTestView()
                }
            }
            .background(Color.white)
        }

    }
}



#Preview {
    IntroView()
}
