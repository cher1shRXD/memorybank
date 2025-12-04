// Views/MainTabView.swift
import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    @State private var showingProfile = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            NoteListView()
                .tabItem {
                    Label("노트", systemImage: "note.text")
                }
                .tag(0)
            
            GraphView()
                .tabItem {
                    Label("그래프", systemImage: "circle.grid.cross")
                }
                .tag(1)
            
            ChatView()
                .tabItem {
                    Label("채팅", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(2)
            
            ProfileView()
                .tabItem {
                    Label("프로필", systemImage: "person.circle")
                }
                .tag(3)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthViewModel())
        .environmentObject(NoteStore())
        .environmentObject(GraphViewModel())
        .environmentObject(ChatViewModel())
}
