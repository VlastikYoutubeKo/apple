//
//  CreateNetworkViewModel.swift
//  URnetwork
//
//  Created by Stuart Kuentzel on 2024/11/21.
//

import Foundation
import URnetworkSdk
import SwiftUICore

private class NetworkCheckCallback: SdkCallback<SdkNetworkCheckResult, SdkNetworkCheckCallbackProtocol>, SdkNetworkCheckCallbackProtocol {
    func result(_ result: SdkNetworkCheckResult?, err: Error?) {
        handleResult(result, err: err)
    }
}

private class NetworkCreateCallback: SdkCallback<SdkNetworkCreateResult, SdkNetworkCreateCallbackProtocol>, SdkNetworkCreateCallbackProtocol {
    func result(_ result: SdkNetworkCreateResult?, err: Error?) {
        handleResult(result, err: err)
    }
}

private class UpgradeGuestCallback: SdkCallback<SdkUpgradeGuestResult, SdkUpgradeGuestCallbackProtocol>, SdkUpgradeGuestCallbackProtocol {
    func result(_ result: SdkUpgradeGuestResult?, err: Error?) {
        handleResult(result, err: err)
    }
}

enum AuthType {
    case password
    case apple
}

extension CreateNetworkView {
    
    @MainActor
    class ViewModel: ObservableObject {
        
        private var api: SdkBringYourApi
        private var networkNameValidationVc: SdkNetworkNameValidationViewController?
        private static let networkNameTooShort: LocalizedStringKey = "Network names must be 6 characters or more"
        private static let networkNameUnavailable: LocalizedStringKey = "This network name is already taken"
        private static let networkNameCheckError: LocalizedStringKey = "There was an error checking the network name"
        private static let networkNameAvailable: LocalizedStringKey = "Nice! This network name is available"
        private static let minPasswordLength = 12
        private let domain = "CreateNetworkView.ViewModel"
        
        private var authType: AuthType
        
        init(api: SdkBringYourApi, authType: AuthType) {
            self.api = api
            self.authType = authType
            
            networkNameValidationVc = SdkNetworkNameValidationViewController(api)
            
            setNetworkNameSupportingText(ViewModel.networkNameTooShort)
        }
        
        @Published var networkName: String = "" {
            didSet {
                if oldValue != networkName {
                    checkNetworkName()
                }
            }
        }
        
        @Published private(set) var networkNameValidationState: ValidationState = .notChecked
        
        
        @Published var password: String = "" {
            didSet {
                validateForm()
            }
        }
        
        @Published private(set) var formIsValid: Bool = false
        
        @Published private(set) var networkNameSupportingText: LocalizedStringKey = ""
        
        @Published var termsAgreed: Bool = false {
            didSet {
                validateForm()
            }
        }
        
        @Published private(set) var isCreatingNetwork: Bool = false
        
        private func setNetworkNameSupportingText(_ text: LocalizedStringKey) {
            networkNameSupportingText = text
        }
        
        // for debouncing calls to check network name availability
        private var networkCheckWorkItem: DispatchWorkItem?
        
        private func validateForm() {
            // todo - need to update validation to handle jwtAuth too (no password)
            formIsValid = networkNameValidationState == .valid &&
                            (
                                // if auth type is password, check password length
                                (authType == .password && password.count >= ViewModel.minPasswordLength)
                                // otherwise, no need to check password length
                                || authType == .apple
                            ) &&
                            termsAgreed
        }
        
        private func checkNetworkName() {
            
            networkCheckWorkItem?.cancel()
            
            if networkName.count < 6 {
                
                if networkNameSupportingText != ViewModel.networkNameTooShort {
                    setNetworkNameSupportingText(ViewModel.networkNameTooShort)
                }
    
                return
            }
            
            DispatchQueue.main.async {
                self.networkNameValidationState = .validating
            }
            
            if networkNameValidationVc != nil {
                
                let callback = NetworkCheckCallback { [weak self] result, error in
                    
                    DispatchQueue.main.async {
                        
                        guard let self = self else { return }
                        
                        if let error = error {
                            print("error checking network name: \(error.localizedDescription)")
                            
                            
                            self.setNetworkNameSupportingText(ViewModel.networkNameCheckError)
                            self.networkNameValidationState = .invalid
                            self.validateForm()
                            
                            
                            return
                        }
                        
                        if let result = result {
                            print("result checking network name \(self.networkName): \(result.available)")
                            self.networkNameValidationState = result.available ? .valid : .invalid
                            
                            
                            if (result.available) {
                                self.setNetworkNameSupportingText(ViewModel.networkNameAvailable)
                            } else {
                                self.setNetworkNameSupportingText(ViewModel.networkNameUnavailable)
                            }
                        }
                        
                        self.validateForm()
                    }
            
                }
                
                networkCheckWorkItem = DispatchWorkItem { [weak self] in
                    guard let self = self else { return }
                    
                    self.networkNameValidationVc?.networkCheck(networkName, callback: callback)
                }
                
                if let workItem = networkCheckWorkItem {
                    // delay .5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
                }
                
            }
            
        }
        
        func upgradeGuestNetwork(
            userAuth: String?,
            authJwt: String?,
            authType: String?
        ) async -> LoginNetworkResult {
            
            if !formIsValid {
                return .failure(NSError(domain: domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Create network form is invalid"]))
            }
            
            if isCreatingNetwork {
                return .failure(NSError(domain: domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Network creation already in progress"]))
            }
                
            
            self.isCreatingNetwork = true
            
            do {
                
                let result: LoginNetworkResult = try await withCheckedThrowingContinuation { [weak self] continuation in
                    
                    guard let self = self else { return }
                    
                    let callback = UpgradeGuestCallback { result, err in
                        
                        if let err = err {
                            continuation.resume(throwing: err)
                            return
                        }
                        
                        if let result = result {
                            
                            if let resultError = result.error {

                                continuation.resume(throwing: NSError(domain: self.domain, code: -1, userInfo: [NSLocalizedDescriptionKey: resultError.message]))
                                
                                return
                                
                            }
                            
                            if result.verificationRequired != nil {
                                continuation.resume(returning: .successWithVerificationRequired)
                                return
                            }
                            
                            if let network = result.network {
                                
                                continuation.resume(returning: .successWithJwt(network.byJwt))
                                return
                                
                            } else {
                                continuation.resume(throwing: NSError(domain: self.domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "No network found in result"]))
                                return
                            }
                            
                        }
                        
                    }
                    
                    let args = SdkUpgradeGuestArgs()
                    args.networkName = networkName.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if let userAuth = userAuth {
                        args.userAuth = userAuth
                        args.password = password
                    }
                    
                    if let authJwt, let authType {
                        args.authJwt = authJwt
                        args.authJwtType = authType
                    }
                    
                    api.upgradeGuest(args, callback: callback)
                    
                }
                
                DispatchQueue.main.async {
                    self.isCreatingNetwork = false
                }
                
                return result
                
            } catch {
                self.isCreatingNetwork = false
                return .failure(error)
            }
            
            
        }
        
        func createNetwork(
            userAuth: String?,
            authJwt: String?,
            authType: String?
        ) async -> LoginNetworkResult {
            
            if !formIsValid {
                return .failure(NSError(domain: domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Create network form is invalid"]))
            }
            
            if isCreatingNetwork {
                return .failure(NSError(domain: domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "Network creation already in progress"]))
            }
            
            self.isCreatingNetwork = true
            
            do {
                
                let result: LoginNetworkResult = try await withCheckedThrowingContinuation { [weak self] continuation in
                    
                    guard let self = self else { return }
                    
                    let callback = NetworkCreateCallback { result, err in
                        
                        if let err = err {
                            continuation.resume(throwing: err)
                            return
                        }
                        
                        if let result = result {
                            
                            if let resultError = result.error {

                                continuation.resume(throwing: NSError(domain: self.domain, code: -1, userInfo: [NSLocalizedDescriptionKey: resultError.message]))
                                
                                return
                                
                            }
                            
                            if result.verificationRequired != nil {
                                continuation.resume(returning: .successWithVerificationRequired)
                                return
                            }
                            
                            if let network = result.network {
                                
                                continuation.resume(returning: .successWithJwt(network.byJwt))
                                return
                                
                            } else {
                                continuation.resume(throwing: NSError(domain: self.domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "No network object found in result"]))
                                return
                            }
                            
                        }
                        
                    }
                    
                    let args = SdkNetworkCreateArgs()
                    args.userName = ""
                    args.networkName = networkName.trimmingCharacters(in: .whitespacesAndNewlines)
                    args.terms = termsAgreed
                    
                    if let userAuth = userAuth {
                        args.userAuth = userAuth
                        args.password = password
                    }
                    
                    if let authJwt, let authType {
                        args.authJwt = authJwt
                        args.authJwtType = authType
                    }
                    
                    api.networkCreate(args, callback: callback)
                    
                }
                
                DispatchQueue.main.async {
                    self.isCreatingNetwork = false
                }
                
                return result
                
            } catch {
                
                self.isCreatingNetwork = false
                
                return .failure(error)
            }
            
        }
        
    }
    
}
