// Views/Auth/RegisterView.swift
import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @Binding var showingLogin: Bool
    
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var agreedToTerms = false
    @FocusState private var focusedField: Field?
    
    enum Field {
        case name, email, password, confirmPassword
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // 헤더
                    headerView
                    
                    // 입력 폼
                    formView
                    
                    // 약관 동의
                    termsView
                    
                    // 회원가입 버튼
                    registerButton
                    
                    // 구분선
                    divider
                    
                    // 로그인 링크
                    loginLink
                }
                .padding(.horizontal, 24)
                .padding(.top, 40)
                .padding(.bottom, 32)
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
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            VStack(spacing: 8) {
                Text("회원가입")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("MemoryBank와 함께 지식을 관리하세요")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Form
    private var formView: some View {
        VStack(spacing: 16) {
            // 이름
            VStack(alignment: .leading, spacing: 8) {
                Text("이름")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "person")
                        .foregroundStyle(.secondary)
                    
                    TextField("이름을 입력하세요", text: $name)
                        .textContentType(.name)
                        .focused($focusedField, equals: .name)
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            
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
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(emailValidationColor, lineWidth: email.isEmpty ? 0 : 1)
                )
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
                        TextField("8자 이상 입력", text: $password)
                            .focused($focusedField, equals: .password)
                    } else {
                        SecureField("8자 이상 입력", text: $password)
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
                
                // 비밀번호 강도
                if !password.isEmpty {
                    passwordStrengthView
                }
            }
            
            // 비밀번호 확인
            VStack(alignment: .leading, spacing: 8) {
                Text("비밀번호 확인")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    
                    SecureField("비밀번호를 다시 입력하세요", text: $confirmPassword)
                        .focused($focusedField, equals: .confirmPassword)
                    
                    if !confirmPassword.isEmpty {
                        Image(systemName: passwordsMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundStyle(passwordsMatch ? .green : .red)
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
    
    // MARK: - Password Strength
    private var passwordStrengthView: some View {
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < passwordStrength ? passwordStrengthColor : Color(.separator))
                    .frame(height: 4)
            }
            
            Text(passwordStrengthText)
                .font(.caption)
                .foregroundStyle(passwordStrengthColor)
        }
    }
    
    private var passwordStrength: Int {
        var strength = 0
        if password.count >= 8 { strength += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { strength += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { strength += 1 }
        if password.rangeOfCharacter(from: .punctuationCharacters) != nil ||
           password.rangeOfCharacter(from: .symbols) != nil { strength += 1 }
        return strength
    }
    
    private var passwordStrengthColor: Color {
        switch passwordStrength {
        case 0...1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .green
        }
    }
    
    private var passwordStrengthText: String {
        switch passwordStrength {
        case 0...1: return "약함"
        case 2: return "보통"
        case 3: return "강함"
        default: return "매우 강함"
        }
    }
    
    // MARK: - Terms
    private var termsView: some View {
        Button {
            agreedToTerms.toggle()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: agreedToTerms ? "checkmark.square.fill" : "square")
                    .foregroundStyle(agreedToTerms ? .blue : .secondary)
                    .font(.title3)
                
                Text("이용약관 및 개인정보 처리방침에 동의합니다")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.leading)
            }
        }
    }
    
    // MARK: - Register Button
    private var registerButton: some View {
        Button {
            Task {
                await authViewModel.register(email: email, password: password, name: name)
            }
        } label: {
            HStack {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("회원가입")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: isFormValid ? [.purple, .blue] : [.gray],
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
    
    // MARK: - Login Link
    private var loginLink: some View {
        HStack {
            Text("이미 계정이 있으신가요?")
                .foregroundStyle(.secondary)
            
            Button {
                withAnimation {
                    showingLogin = true
                }
            } label: {
                Text("로그인")
                    .fontWeight(.semibold)
                    .foregroundStyle(.blue)
            }
        }
        .font(.subheadline)
    }
    
    // MARK: - Validation
    private var isFormValid: Bool {
        !name.isEmpty &&
        !email.isEmpty &&
        email.contains("@") &&
        password.count >= 8 &&
        passwordsMatch &&
        agreedToTerms
    }
    
    private var passwordsMatch: Bool {
        !confirmPassword.isEmpty && password == confirmPassword
    }
    
    private var emailValidationColor: Color {
        if email.isEmpty { return .clear }
        return email.contains("@") && email.contains(".") ? .green : .red
    }
}

#Preview {
    RegisterView(showingLogin: .constant(false))
        .environmentObject(AuthViewModel())
}
