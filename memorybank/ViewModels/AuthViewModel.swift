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
            // 토큰 갱신 시도
            Task {
                await refreshTokenIfNeeded()
            }
        }
    }

    // MARK: - Token Refresh
    private func refreshTokenIfNeeded() async {
        do {
            _ = try await api.refreshToken()
            await MainActor.run {
                // Access token has been refreshed
                isLoggedIn = true
            }
        } catch {
            // 토큰 갱신 실패 시 로그아웃
            await MainActor.run {
                logout()
            }
        }
    }

    // MARK: - Login
    func login(email: String, password: String) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let response = try await api.login(email: email, password: password)

            await MainActor.run {
                currentUser = response.user
                isLoggedIn = true
                isLoading = false
            }
            return true
        } catch let error as APIError {
            await MainActor.run {
                switch error {
                case .httpError(401):
                    errorMessage = "이메일 또는 비밀번호가 올바르지 않습니다."
                default:
                    errorMessage = error.errorDescription
                }
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

    // MARK: - Google Auth
    func loginWithGoogle(token: String) async -> Bool {
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let response = try await api.googleAuth(idToken: token)

            await MainActor.run {
                currentUser = response.user
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
                errorMessage = "Google 로그인에 실패했습니다."
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
            let response = try await api.register(email: email, password: password, name: name)

            await MainActor.run {
                currentUser = response.user
                isLoggedIn = true
                isLoading = false
            }
            return true
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
