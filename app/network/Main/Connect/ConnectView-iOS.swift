//
//  ConnectView-iOS.swift
//  URnetwork
//
//  Created by Stuart Kuentzel on 2025/02/11.
//

import SwiftUI
import URnetworkSdk

#if os(iOS)
struct ConnectView_iOS: View {
    
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var snackbarManager: UrSnackbarManager
    @Environment(\.requestReview) private var requestReview
    
    @EnvironmentObject var connectViewModel: ConnectViewModel
    
    @ObservedObject var referralLinkViewModel: ReferralLinkViewModel
    
    var logout: () -> Void
    var api: SdkApi
    @ObservedObject var providerListSheetViewModel: ProviderListSheetViewModel
    
    @StateObject var egressContractStatsViewModel: EgressContractStatsViewModel
    
    init(
        api: SdkApi,
        logout: @escaping () -> Void,
        device: SdkDeviceRemote?,
        providerListSheetViewModel: ProviderListSheetViewModel,
        referralLinkViewModel: ReferralLinkViewModel
    ) {
        self.logout = logout
        self.api = api
        self.providerListSheetViewModel = providerListSheetViewModel
        self.referralLinkViewModel = referralLinkViewModel
        
        _egressContractStatsViewModel = StateObject(wrappedValue: EgressContractStatsViewModel(device: device))
        
        // adds clear button to search providers text field
        UITextField.appearance().clearButtonMode = .whileEditing
    }
    
    var body: some View {
        
        let isGuest = deviceManager.parsedJwt?.guestMode ?? true
        
        VStack {
            
            HStack {
                Spacer()
                AccountMenu(
                    isGuest: isGuest,
                    logout: logout,
                    isPresentedCreateAccount: $connectViewModel.isPresentedCreateAccount,
                    referralLinkViewModel: referralLinkViewModel
                )
            }
            .frame(height: 32)
            
            Spacer()
            
            ConnectButtonView(
                gridPoints:
                    connectViewModel.gridPoints,
                gridWidth: connectViewModel.gridWidth,
                connectionStatus: connectViewModel.connectionStatus,
                windowCurrentSize: connectViewModel.windowCurrentSize,
                connect: connectViewModel.connect,
                disconnect: connectViewModel.disconnect,
                connectTunnel: {
                    deviceManager.vpnManager?.updateVpnService()
                },
                tunnelConnected: $connectViewModel.tunnelConnected
            )
            
            Spacer()
            
            Button(action: {
                providerListSheetViewModel.isPresented = true
            }) {
                
                SelectedProvider(
                    selectedProvider: connectViewModel.selectedProvider,
                    getProviderColor: connectViewModel.getProviderColor
                )
                
            }
            .background(themeManager.currentTheme.tintedBackgroundBase)
            .clipShape(.capsule)
            
        }
        .onAppear {
            
            /**
             * Create callback function for prompting rating
             */
            connectViewModel.requestReview = {
                Task {
                    
                    if let device = deviceManager.device {
                        
                        if device.getShouldShowRatingDialog() {
                            device.setCanShowRatingDialog(false)
                            try await Task.sleep(for: .seconds(2))
                            requestReview()
                        }
                        
                    }
                    
                }
            }
            
        }
        .padding()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $providerListSheetViewModel.isPresented) {
            
            NavigationStack {
    
                ProviderListSheetView(
                    selectedProvider: connectViewModel.selectedProvider,
                    connect: { provider in
                        connectViewModel.connect(provider)
                        providerListSheetViewModel.isPresented = false
                    },
                    connectBestAvailable: {
                        connectViewModel.connectBestAvailable()
                        providerListSheetViewModel.isPresented = false
                    },
                    providerCountries: connectViewModel.providerCountries,
                    providerPromoted: connectViewModel.providerPromoted,
                    providerDevices: connectViewModel.providerDevices,
                    providerRegions: connectViewModel.providerRegions,
                    providerCities: connectViewModel.providerCities,
                    providerBestSearchMatches: connectViewModel.providerBestSearchMatches
                )
                .navigationBarTitleDisplayMode(.inline)
    
    
                .searchable(
                    text: $connectViewModel.searchQuery,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "Search providers"
                )
                .toolbar {
    
                    ToolbarItem(placement: .principal) {
                        Text("Available providers")
                            .font(themeManager.currentTheme.toolbarTitleFont).fontWeight(.bold)
                    }
    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {
                            providerListSheetViewModel.isPresented = false
                        }) {
                            Image(systemName: "xmark")
                        }
                    }
                }
                .refreshable {
                    let _ = await connectViewModel.filterLocations(connectViewModel.searchQuery)
                }
                .onAppear {
                    Task {
                        let _ = await connectViewModel.filterLocations(connectViewModel.searchQuery)
                    }
                }
    
             }
            .background(themeManager.currentTheme.backgroundColor)
            
            
        }
        
        // upgrade guest account flow
        .fullScreenCover(isPresented: $connectViewModel.isPresentedCreateAccount) {
            LoginNavigationView(
                api: api,
                cancel: {
                    connectViewModel.isPresentedCreateAccount = false
                },
                
                handleSuccess: { jwt in
                    Task {
                        await handleSuccessWithJwt(jwt)
                        connectViewModel.isPresentedCreateAccount = false
                    }
                }
            )
        }
        
    }
    
    private func handleSuccessWithJwt(_ jwt: String) async {
        
        let result = await deviceManager.authenticateNetworkClient(jwt)
        
        if case .failure(let error) = result {
            print("[ContentView] handleSuccessWithJwt: \(error.localizedDescription)")
            
            snackbarManager.showSnackbar(message: "There was an error creating your network. Please try again later.")
            
            return
        }
        
        // TODO: fade out login flow
        // TODO: create navigation view model and switch to main app instead of checking deviceManager.device
        
    }
    
}

//#Preview {
//    ConnectView_iOS()
//}
#endif
