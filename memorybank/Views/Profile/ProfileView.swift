//
//  ProfileView.swift
//  memorybank
//
//  Created by cher1shRXD on 12/4/25.
//


// Views/Profile/ProfileView.swift
import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showingLogoutAlert = false
    
    var body: some View {
        NavigationStack {
            List {
                // 사용자 정보
                Section {
                    if let user = authViewModel.currentUser {
                        HStack(spacing: 16) {
                            // 아바타
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 60, height: 60)
                                
                                Text(String(user.name.prefix(1)))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.white)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.headline)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 8)
                    } else {
                        HStack {
                            ProgressView()
                            Text("사용자 정보 로딩 중...")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // 앱 정보
                Section("앱 정보") {
                    HStack {
                        Label("버전", systemImage: "info.circle")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://memorybank.example.com/terms")!) {
                        Label("이용약관", systemImage: "doc.text")
                    }
                    
                    Link(destination: URL(string: "https://memorybank.example.com/privacy")!) {
                        Label("개인정보 처리방침", systemImage: "hand.raised")
                    }
                }
                
                // 계정
                Section("계정") {
                    Button(role: .destructive) {
                        showingLogoutAlert = true
                    } label: {
                        Label("로그아웃", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .navigationTitle("프로필")
            .alert("로그아웃", isPresented: $showingLogoutAlert) {
                Button("취소", role: .cancel) {}
                Button("로그아웃", role: .destructive) {
                    authViewModel.logout()
                }
            } message: {
                Text("정말 로그아웃 하시겠습니까?")
            }
        }
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
