//
//  LoginView.swift
//  memorybank
//
//  Created by cher1shRXD on 12/4/25.
//


// Views/Auth/LoginView.swift
import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var showingLogin: Bool
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case email, password
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // 로고 & 타이틀
                    headerView
                    
                    // 입력 폼
                    formView
                    
                    // 로그인 버튼
                    loginButton
                    
                    // 구분선
                    divider
                    
                    // 회원가입 링크
                    registerLink
                }
                .padding(.horizontal, 24)
                .padding(.top, 60)
            }
            .background(Color(.systemBackground))
            .onTapGesture {
                focusedField = nil
            }
        }
    }
    
    // MARK: - Header
    private var headerView: some View {
        VStack(spacing: 16) {
            // 앱 아이콘
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 8) {
                Text("MemoryBank")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("지식을 연결하는 스마트 노트")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    // MARK: - Form
    private var formView: some View {
        VStack(spacing: 16) {
            // 이메일
            VStack(alignment: .leading, spacing: 8) {
                Text("이메일")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "envelope")
                        .foregroundStyle(.secondary)
                    
                    TextField("example@email.com", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                        .focused($focusedField, equals: .email)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            // 비밀번호
            VStack(alignment: .leading, spacing: 8) {
                Text("비밀번호")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "lock")
                        .foregroundStyle(.secondary)
                    
                    if showPassword {
                        TextField("비밀번호 입력", text: $password)
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField("비밀번호 입력", text: $password)
                            .focused($focusedField, equals: .password)
                    }
                    
                    Button {
                        showPassword.toggle()
                    } label: {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
            // 에러 메시지
            if let error = authViewModel.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.circle")
                    Text(error)
                }
                .font(.subheadline)
                .foregroundStyle(.red)
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - Login Button
    private var loginButton: some View {
        Button {
            Task {
                await authViewModel.login(email: email, password: password)
            }
        } label: {
            HStack {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("로그인")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isFormValid ? [.blue, .purple] : [.gray],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundStyle(.white)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || authViewModel.isLoading)
    }
    
    // MARK: - Divider
    private var divider: some View {
        HStack {
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
            
            Text("또는")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 1)
        }
    }
    
    // MARK: - Register Link
    private var registerLink: some View {
        HStack {
            Text("계정이 없으신가요?")
                .foregroundStyle(.secondary)
            
            Button {
                withAnimation {
                    showingLogin = false
                }
            } label: {
                Text("회원가입")
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
        }
        .font(.subheadline)
    }
    
    // MARK: - Validation
    private var isFormValid: Bool {
        !email.isEmpty && email.contains("@") && password.count >= 8
    }
}

#Preview {
    LoginView(showingLogin: .constant(true))
        .environmentObject(AuthViewModel())
}
