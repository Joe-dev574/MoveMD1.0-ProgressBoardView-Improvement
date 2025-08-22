//
//  PurchaseView.swift
//  MoveMD1.0
//
//  Created by Grok on 5/7/25.
//

import SwiftUI
import StoreKit

struct PurchaseView: View {
    @ObservedObject var purchaseManager: PurchaseManager
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var errorManager: ErrorManager
    @State private var isPurchasing: Bool = false

    private var appProduct: Product? {
        purchaseManager.getMainAppProduct()
    }

    private var purchaseButtonText: String {
        if let product = appProduct {
            return "Unlock Full Access - \(product.displayPrice)"
        }
        return "Unlock Full Access" // Fallback if product info not yet loaded
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Unlock Full Access")
                    .font(.largeTitle.bold()) // Make title more prominent
                    .fontDesign(.serif)
                    .padding(.top)

                if purchaseManager.isTrialActive {
                    Text("Trial Active: \(purchaseManager.trialDaysRemaining) days remaining")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else if !purchaseManager.isAppPurchased { // If trial is over AND not purchased
                    Text("Trial Expired")
                        .font(.headline)
                        .foregroundStyle(.red)
                        .padding(.bottom, 5)
                    Text("Purchase full access to continue using MoveMD.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else if purchaseManager.isAppPurchased {
                    // Optional: Add a message if already purchased
                     Text("Thank you for purchasing MoveMD!")
                          .font(.headline)
                          .foregroundStyle(.green)
                }

                Spacer() // Pushes content up

                // Keep only the one-time purchase button
                VStack(spacing: 15) {
                    if !purchaseManager.isAppPurchased { // Only show purchase button if not purchased
                        Button {
                            Task {
                                isPurchasing = true // Show loading
                                do {
                                    guard appProduct != nil else {
                                        errorManager.presentAlert(title: "Purchase Error", message: "Product information is currently unavailable. Please try again in a moment.")
                                        isPurchasing = false
                                        return
                                    }
                                    try await purchaseManager.purchaseApp()
                                    // Optional: dismiss view automatically on success?
                                    // dismiss()
                                } catch let purchaseError as PurchaseError {
                                     errorManager.presentAlert(title: "Purchase Error", message: purchaseError.localizedDescription)
                                } catch {
                                    errorManager.presentAlert(title: "Purchase Error", message: "An unexpected error occurred: \(error.localizedDescription)")
                                }
                                isPurchasing = false // Hide loading
                            }
                        } label: {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue.opacity(0.7)) // Indicate loading
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                Text(purchaseButtonText)
                                    .font(.headline.bold())
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .disabled(isPurchasing || appProduct == nil) 
                        .accessibilityIdentifier("purchaseAppButton") // Add identifier for UI tests

                    }

                    // Keep Restore Purchases button
                    Button {
                        Task {
                            isPurchasing = true // Show loading (optional for restore)
                            do {
                                try await purchaseManager.restorePurchases()
                                // Maybe add a success message or dismiss if needed
                            } catch let purchaseError as PurchaseError {
                                errorManager.presentAlert(title: "Restore Error", message: purchaseError.localizedDescription)
                            } catch {
                                errorManager.presentAlert(title: "Restore Error", message: "An unexpected error occurred: \(error.localizedDescription)")
                            }
                             isPurchasing = false // Hide loading
                        }
                    } label: {
                        Text("Restore Purchases")
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                    }
                     .disabled(isPurchasing) // Disable while potentially processing
                     .padding(.top, 5) // Add a little space
                     .accessibilityIdentifier("restorePurchasesButton")

                }
                .padding(.horizontal)

                Text("Your purchase unlocks all current and future features of MoveMD.")
                    .font(.caption)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.bottom) // Add padding at the bottom

                Spacer() // Pushes content down
            }
            .padding()
            .navigationTitle("Unlock MoveMD")
            .navigationBarTitleDisplayMode(.inline)
            // Optional: Add a background color or gradient
            // .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
        }
    }
}
