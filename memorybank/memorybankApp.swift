// memorybankApp.swift
import SwiftUI

@main
struct memorybankApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var noteStore = NoteStore()
    @StateObject private var graphViewModel = GraphViewModel()
    @StateObject private var chatViewModel = ChatViewModel()
    
    var body: some Scene {
        WindowGroup {
            Group {
                if authViewModel.isLoggedIn {
                    MainTabView()
                        .environmentObject(noteStore)
                        .environmentObject(graphViewModel)
                        .environmentObject(chatViewModel)
                } else {
                    AuthContainerView()
                }
            }
            .environmentObject(authViewModel)
        }
    }
}
