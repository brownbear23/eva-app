//
//  ProfileView.swift
//  EVALabel
//
//  Created by Bill Han on 1/11/24.
//

import SwiftUI

struct ProfileView: View {
    
    @State var profileImage : String = "profile_0"
    @State var nickName : String = "no name"
    @State var emailAddress : String = "no email"

    
    var body: some View {
        VStack(){
            Image(profileImage)
                .resizable() // 이미지 사이즈 조절
                .frame(width: 100, height: 100)
                .border(.black, width: 1) // 테두리 추가
            
            Text(nickName)
            Text(emailAddress)

            
            Button(action: {
            }, label: {
                Text("Logout")
                    .foregroundColor(.white)
            })
            .padding([.vertical])
            .frame(maxWidth: .infinity)
            .background(Color.blue)
//            .padding([.top], 100)
        }
        .padding()
    }
}

#Preview {
    ProfileView()
}
