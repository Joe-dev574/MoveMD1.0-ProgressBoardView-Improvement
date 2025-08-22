import SwiftUI
import SwiftData
import OSLog

// Note: Ensure User.swift and AuthenticationManager.swift are in your project and target.

struct OnboardingFlowView: View {
    @Bindable var user: User
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.modelContext) private var modelContext
    @AppStorage("selectedThemeColorData") private var selectedThemeColorData: String = "#0096FF" 
    private var themeColor: Color { Color(hex: selectedThemeColorData) ?? .blue }

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.movemd.default.subsystem", category: "OnboardingFlowView")

    var body: some View {
        let _ = logger.debug("[OnboardingFlowView] Body evaluating for user: \(user.appleUserId?.prefix(8) ?? "N/A")")
        ZStack {
            themeColor.opacity(0.1).ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                HStack(spacing: 15) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 50))
                        .foregroundColor(themeColor.opacity(0.8))
                    Image(systemName: "figure.highintensity.intervaltraining")
                        .font(.system(size: 60))
                        .foregroundColor(themeColor)
                    Image(systemName: "figure.walk")
                        .font(.system(size: 50))
                        .foregroundColor(themeColor.opacity(0.8))
                }
                .padding(.bottom, 20)

                Text("Welcome to MoveMD!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .foregroundColor(themeColor)

                VStack(alignment: .leading, spacing: 15) {
                    HStack(alignment: .top) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .foregroundColor(themeColor)
                            .font(.title3)
                        Text("MoveMD is designed to help you effectively log your workouts, monitor your fitness metrics, and visualize your activity patterns over time.")
                            .font(.body)
                    }
                    
                    HStack(alignment: .top) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(themeColor)
                            .font(.title3)
                        Text("Your feedback is invaluable! Help us grow by sharing your thoughts and feature requests via the 'Send Feedback' option in Settings.")
                            .font(.body)
                    }
                }
                .padding(.horizontal, 30)

                Spacer()
                Spacer()

                Button {
                    logger.info("[OnboardingFlowView] 'Complete Onboarding' tapped for user: \(user.appleUserId?.prefix(8) ?? "N/A")")
                    user.isOnboardingComplete = true
                    do {
                        logger.debug("[OnboardingFlowView] Attempting to save onboarding status to SwiftData.")
                        try modelContext.save()
                        logger.info("[OnboardingFlowView] Onboarding complete status saved for user: \(user.appleUserId?.prefix(8) ?? "N/A")")
                    } catch {
                        logger.error("[OnboardingFlowView] Failed to save onboarding status: \(error.localizedDescription)")
                    }
                } label: {
                    Text("Let's Get Started!")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(themeColor)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
            }
            .padding(.top, 50)
        }
        .onAppear {
            logger.debug("[OnboardingFlowView] onAppear for user: \(user.appleUserId?.prefix(8) ?? "N/A")")
        }
    }
}
