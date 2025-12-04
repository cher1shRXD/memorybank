//
//  AuthContainerView.swift
//  memorybank
//
//  Created by cher1shRXD on 12/4/25.
//


// Views/Auth/AuthContainerView.swift
import SwiftUI

struct AuthContainerView: View {
    @State private var showingLogin = true
    
    var body: some View {
        if showingLogin {
            LoginView(showingLogin: $showingLogin)
        } else {
            RegisterView(showingLogin: $showingLogin)
        }
    }
}

#Preview {
    AuthContainerView()
        .environmentObject(AuthViewModel())
}