//
//  AuthViewModel.swift
//  memorybank
//
//  Created by cher1shRXD on 12/4/25.
//


// ViewModels/AuthViewModel.swift
import SwiftUI
import Combine

class AuthViewModel: ObservableObject {
    @Published var isLoggedIn = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var currentUser: UserResponse?
    
    private let api = APIService.shared
    private let keychain = KeychainService.shared
    
    init() {
        checkLoginStatus()
    }
    
    // MARK: - Check Login Status
    func checkLoginStatus() {
        if keychain.accessToken != nil {
            isLoggedIn = true
        }
    }
    
    // MARK: - Login
    func login(email: String, password: String) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            let user  = try await api.login(email: email, password: password).user
            
            await MainActor.run {
                currentUser = user
                isLoggedIn = true
                isLoading = false
            }
            return true
        } catch let error as APIError {
            await MainActor.run {
                errorMessage = error.errorDescription
                isLoading = false
            }
            return false
        } catch {
            await MainActor.run {
                errorMessage = "로그인에 실패했습니다."
                isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Register
    func register(email: String, password: String, name: String) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        do {
            _ = try await api.register(email: email, password: password, name: name)
            
            // 회원가입 후 자동 로그인
            return await login(email: email, password: password)
        } catch let error as APIError {
            await MainActor.run {
                switch error {
                case .httpError(409):
                    errorMessage = "이미 사용 중인 이메일입니다."
                case .validationError:
                    errorMessage = "입력 정보를 확인해주세요."
                default:
                    errorMessage = error.errorDescription
                }
                isLoading = false
            }
            return false
        } catch {
            await MainActor.run {
                errorMessage = "회원가입에 실패했습니다."
                isLoading = false
            }
            return false
        }
    }
    
    // MARK: - Logout
    func logout() {
        api.logout()
        currentUser = nil
        isLoggedIn = false
    }
}
