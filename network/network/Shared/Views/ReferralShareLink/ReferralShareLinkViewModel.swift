//
//  ReferSheetViewModel.swift
//  URnetwork
//
//  Created by Stuart Kuentzel on 2025/01/03.
//

import Foundation
import URnetworkSdk


    
extension ReferralShareLink {
 
    @MainActor
    class ViewModel: ObservableObject {
        
        @Published private(set) var referralCode: String?
        @Published private(set) var isLoading: Bool = false
        
        let domain = "ReferSheetViewModel"
        
        init(api: SdkBringYourApi) {
            self.fetchReferralLink(api)
        }
        
        func fetchReferralLink(_ api: SdkBringYourApi) {
            
            if isLoading {
                return
            }
            
            self.isLoading = true
            
            Task {
                
                do {
                    
                    let result: SdkGetNetworkReferralCodeResult = try await withCheckedThrowingContinuation { [weak self] continuation in
                        
                        guard let self = self else { return }
                        
                        let callback = GetNetworkReferralCodeCallback { result, err in
                            
                            if let err = err {
                                continuation.resume(throwing: err)
                                return
                            }
                            
                            if let result = result {
                                
                                if let resultErr = result.error {
                                    continuation.resume(throwing: NSError(domain: self.domain, code: -1, userInfo: [NSLocalizedDescriptionKey: resultErr.message]))
                                    return
                                }
                                
                                continuation.resume(returning: result)
                                return
                                
                            } else {
                                continuation.resume(throwing: NSError(domain: self.domain, code: 0, userInfo: [NSLocalizedDescriptionKey: "result is nil"]))
                            }
                        }
                        
                        api.getNetworkReferralCode(callback)
                    }
                    
                    self.referralCode = result.referralCode
                    self.isLoading = false
                    
                } catch(let error) {
                    self.isLoading = false
                    print("error fetching referral link: \(error.localizedDescription)")
                }
            }
            
        }
        
    }
    
}

private class GetNetworkReferralCodeCallback: SdkCallback<SdkGetNetworkReferralCodeResult, SdkGetNetworkReferralCodeCallbackProtocol>, SdkGetNetworkReferralCodeCallbackProtocol {
    func result(_ result: SdkGetNetworkReferralCodeResult?, err: Error?) {
        handleResult(result, err: err)
    }
}

