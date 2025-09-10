//
//  AccountView.swift
//  URnetwork
//
//  Created by Stuart Kuentzel on 2024/12/13.
//

import SwiftUI
import URnetworkSdk

struct AccountRootView: View {
    
    @Environment(\.openURL) private var openURL
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var deviceManager: DeviceManager
    @EnvironmentObject var snackbarManager: UrSnackbarManager
    @EnvironmentObject var subscriptionBalanceViewModel: SubscriptionBalanceViewModel
    @EnvironmentObject var subscriptionManager: AppStoreSubscriptionManager
    @Environment(\.requestReview) private var requestReview
    @EnvironmentObject var connectViewModel: ConnectViewModel
    
    var navigate: (AccountNavigationPath) -> Void
    var logout: () -> Void
    var api: SdkApi
    var networkName: String?
    
    @StateObject private var viewModel: ViewModel = ViewModel()
    
    @ObservedObject var referralLinkViewModel: ReferralLinkViewModel
    @ObservedObject var accountPaymentsViewModel: AccountPaymentsViewModel
    
    init(
        navigate: @escaping (AccountNavigationPath) -> Void,
        logout: @escaping () -> Void,
        api: SdkApi,
        referralLinkViewModel: ReferralLinkViewModel,
        accountPaymentsViewModel: AccountPaymentsViewModel,
        networkName: String?
    ) {
        self.navigate = navigate
        self.logout = logout
        self.api = api
        
        self.referralLinkViewModel = referralLinkViewModel
        self.accountPaymentsViewModel = accountPaymentsViewModel
        self.networkName = networkName
    }
    
    
    var body: some View {
        
        let isGuest = deviceManager.parsedJwt?.guestMode ?? true

        ScrollView {
            
            HStack {
                Text("Account")
                    .font(themeManager.currentTheme.titleFont)
                    .foregroundColor(themeManager.currentTheme.textColor)
                
                Spacer()

                #if os(iOS)
                AccountMenu(
                    isGuest: isGuest,
                    logout: logout,
                    networkName: networkName,
                    isPresentedCreateAccount: $viewModel.isPresentedCreateAccount,
                    referralLinkViewModel: referralLinkViewModel
                )
                #endif
                
            }
            .frame(height: 32)
            .padding()
            // .padding(.vertical, 12)
            
            Spacer().frame(height: 16)
            
            VStack(spacing: 0) {
                
                HStack {
                    Text("Plan")
                        .font(themeManager.currentTheme.secondaryBodyFont)
                        .foregroundColor(themeManager.currentTheme.textMutedColor)
                    Spacer()
                }
                
                HStack(alignment: .firstTextBaseline) {
                    
                    if (isGuest) {
                        Text("Guest")
                            .font(themeManager.currentTheme.titleCondensedFont)
                            .foregroundColor(themeManager.currentTheme.textColor)
                    } else {
                     
                        Text(subscriptionBalanceViewModel.currentPlan == .none ? "Free" : "Supporter")
                            .font(themeManager.currentTheme.titleCondensedFont)
                            .foregroundColor(themeManager.currentTheme.textColor)
                        
                    }
                    
                    Spacer()
  
                    /**
                     * Upgrade subscription button
                     * if user is
                     */
                    if (subscriptionBalanceViewModel.currentPlan != .supporter && !isGuest) {
                     
                        Button(action: {
                            viewModel.isPresentedUpgradeSheet = true
                        }) {
                            Text("Upgrade")
                                .font(themeManager.currentTheme.secondaryBodyFont)
                        }
                        
                    }
                    
                }
                
                Spacer().frame(height: 8)
                
                UsageBar(
                    availableByteCount: subscriptionBalanceViewModel.availableByteCount,
                    pendingByteCount: subscriptionBalanceViewModel.pendingByteCount,
                    usedByteCount: subscriptionBalanceViewModel.usedBalanceByteCount
                )
                
                Divider()
                    .background(themeManager.currentTheme.borderBaseColor)
                    .padding(.vertical, 16)
                
                HStack {
                    Text("Network earnings")
                        .font(themeManager.currentTheme.secondaryBodyFont)
                        .foregroundColor(themeManager.currentTheme.textMutedColor)
                    Spacer()
                }
                
                HStack(alignment: .firstTextBaseline) {
                    
                    let totalPayouts = accountPaymentsViewModel.totalPayoutsUsdc
                    
                    Text(totalPayouts > 0 ? String(format: "%.4f", totalPayouts) : "0")
                        .font(themeManager.currentTheme.titleCondensedFont)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    Text("USDC")
                        .font(themeManager.currentTheme.secondaryBodyFont)
                        .foregroundColor(themeManager.currentTheme.textMutedColor)
                    
                    Spacer()
                    
//                    Button(action: {}) {
//                        Text("Start earning")
//                            .font(themeManager.currentTheme.secondaryBodyFont)
//                    }
                    
                }
                
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(themeManager.currentTheme.tintedBackgroundBase)
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer().frame(height: 16)
            
            /**
             * Navigation items
             */
            VStack(spacing: 0) {
                AccountNavLink(
                    name: "Profile",
                    iconPath: "ur.symbols.user.circle",
                    action: {
                        
                        if isGuest {
                            viewModel.isPresentedCreateAccount = true
                        } else {
                            navigate(.profile)
                        }
                        
                    }
                )
                AccountNavLink(
                    name: "Settings",
                    iconPath: "ur.symbols.sliders",
                    action: {
                        if isGuest {
                            viewModel.isPresentedCreateAccount = true
                        } else {
                            navigate(.settings)
                        }
                    }
                )
                AccountNavLink(
                    name: "Wallet",
                    iconPath: "ur.symbols.wallet",
                    action: {
                        if isGuest {
                            viewModel.isPresentedCreateAccount = true
                        } else {
                            navigate(.wallets)
                        }
                    }
                )
                
                ReferralShareLink(referralLinkViewModel: referralLinkViewModel) {
                    
                    VStack(spacing: 0) {
                        HStack {
                            
                            Image("ur.symbols.heart")
                                .foregroundColor(themeManager.currentTheme.textMutedColor)
                            
                            Spacer().frame(width: 16)
                            
                            Text("Refer friends")
                                .font(themeManager.currentTheme.bodyFont)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        
                        Divider()
                            .background(themeManager.currentTheme.borderBaseColor)
                        
                    }
                    
                }
                
                /**
                 * Review
                 */
                Button(action: {
                    requestReview()
                }) {
                    
                    VStack(spacing: 0) {
                        HStack {
                            
                            Image(systemName: "pencil")
                                .foregroundColor(themeManager.currentTheme.textMutedColor)
                                .frame(width: 24)
                            
                            Spacer().frame(width: 16)
                            
                            Text("Review URnetwork")
                                .font(themeManager.currentTheme.bodyFont)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        
                        Divider()
                            .background(themeManager.currentTheme.borderBaseColor)
                        
                    }
                    .contentShape(Rectangle())
                    
                }
                .buttonStyle(.plain)
                
                /**
                 * Check IP
                 */
                Button(action: {
                    if let url = URL(string: "https://ur.io/ip") {
                        
                        #if canImport(UIKit)
                        UIApplication.shared.open(url, options: [:], completionHandler: nil)
                        #endif
                        
                        #if canImport(AppKit)
                        NSWorkspace.shared.open(url)
                        #endif
                        
                    }
                }) {
                    
                    VStack(spacing: 0) {
                        HStack {
                            
                            Image(systemName: "dot.scope")
                                .foregroundColor(themeManager.currentTheme.textMutedColor)
                                .frame(width: 24)
                            
                            Spacer().frame(width: 16)
                            
                            Text("Check my IP")
                                .font(themeManager.currentTheme.bodyFont)
                                .foregroundColor(themeManager.currentTheme.textColor)
                            
                            Spacer()
                            
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal)
                        
                        Divider()
                            .background(themeManager.currentTheme.borderBaseColor)
                        
                    }
                    .contentShape(Rectangle())
                    
                }
                .buttonStyle(.plain)
                
                /**
                 * URnode Carousel
                 */
                URNodeCarousel()
                
                Spacer().frame(height: 16)
            }
            
            Spacer()
            
            if isGuest {
                UrButton(
                    text: "Create an account",
                    action: {
                        viewModel.isPresentedCreateAccount = true
                    }
                )
            }
            
        }
        .refreshable {
            await subscriptionBalanceViewModel.fetchSubscriptionBalance()
        }
//        .padding()
        .frame(maxWidth: 600)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            Task {
                await subscriptionBalanceViewModel.fetchSubscriptionBalance()
            }
        }
        .sheet(isPresented: $viewModel.isPresentedUpgradeSheet) {
            UpgradeSubscriptionSheet(
                subscriptionProduct: subscriptionManager.products.first,
                purchase: { product in
                    
                    let initiallyConnected = deviceManager.device?.getConnected() ?? false
                    
                    #if os(macOS)
                    if (initiallyConnected) {
                        connectViewModel.disconnect()
                    }
                    #endif
                    
                    Task {
                        do {
                            try await subscriptionManager.purchase(
                                product: product,
                                onSuccess: {
                                    subscriptionBalanceViewModel.setCurrentPlan(.supporter)
                                }
                            )
    
                        } catch(let error) {
                            print("error making purchase: \(error)")
                        }
                        
                        #if os(macOS)
                        if (initiallyConnected) {
                            connectViewModel.connect()
                        }
                        #endif

                    }

                },
                isPurchasing: subscriptionManager.isPurchasing,
                purchaseSuccess: subscriptionManager.purchaseSuccess,
                dismiss: {
                    viewModel.isPresentedUpgradeSheet = false
                }
            )
        }
        #if os(iOS)
        .fullScreenCover(isPresented: $viewModel.isPresentedCreateAccount) {
            LoginNavigationView(
                api: api,
                cancel: {
                    viewModel.isPresentedCreateAccount = false
                },
                
                handleSuccess: { jwt in
                    Task {
                        // viewModel.isPresentedCreateAccount = false
                        await handleSuccessWithJwt(jwt)
                    }
                }
            )
        }
        #endif
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button(action: {
                    Task {
                        await accountPaymentsViewModel.fetchPayments()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(accountPaymentsViewModel.isLoadingPayments)
            }
        }
        #endif
    }
    
    private func handleSuccessWithJwt(_ jwt: String) async {
        
        do {
            
            deviceManager.logout()
            
            try await deviceManager.waitUntilDeviceUninitialized()
            
            await deviceManager.initializeNetworkSpace()
            
            try await deviceManager.waitUntilDeviceInitialized()
            
            let result = await deviceManager.authenticateNetworkClient(jwt)
            
            if case .failure(let error) = result {
                print("[AccountRootView] handleSuccessWithJwt: \(error.localizedDescription)")
                
                snackbarManager.showSnackbar(message: "There was an error creating your network. Please try again later.")
                
                return
            }
            
            // TODO: fade out login flow
            // TODO: create navigation view model and switch to main app instead of checking deviceManager.device
            
        } catch {
            print("handleSuccessWithJwt error is \(error)")
        }

        
    }
    
}

private struct AccountNavLink: View {
    
    var name: LocalizedStringKey
    var iconPath: String
    var action: () -> Void
    
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: action) {
            
            VStack(spacing: 0) {
                HStack {
                    
                    Image(iconPath)
                        .foregroundColor(themeManager.currentTheme.textMutedColor)
                    
                    Spacer().frame(width: 16)
                    
                    Text(name)
                        .font(themeManager.currentTheme.bodyFont)
                        .foregroundColor(themeManager.currentTheme.textColor)
                    
                    Spacer()
                    
                    Image("ur.symbols.caret.right")
                        .foregroundColor(themeManager.currentTheme.textMutedColor)
                    
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
                
                Divider()
                    .background(themeManager.currentTheme.borderBaseColor)
                
            }
            .contentShape(Rectangle())
            
        }
        .buttonStyle(.plain)
        // .contentShape(Rectangle())
        
    }
}

//#Preview {
//    
//    let themeManager = ThemeManager.shared
//    
//    VStack {
//        AccountRootView(
//            navigate: {_ in},
//            logout: {},
//            api: SdkBringYourApi()
//        )
//    }
//    .environmentObject(themeManager)
//    .background(themeManager.currentTheme.backgroundColor)
//    .frame(maxHeight: .infinity)
//    
//}
