import SwiftUI
import AuthenticationServices // For SignInWithAppleButton

struct AuthenticationView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Use the real app icon if present, otherwise fall back to a system symbol
            if let uiImage = UIImage(named: "AppIcon") {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 20)) // Optional styling
                    .shadow(radius: 5)
                    .padding(.bottom, 20)
            } else {
                Image(systemName: "figure.run") // simple placeholder
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(.accentColor)
                    .padding(.bottom, 20)
            }

            Text("Welcome to MoveMD")
                .font(.system(size: 32, weight: .bold, design: .serif))
                .multilineTextAlignment(.center)

            Text("Your personalized fitness journey starts here. Sign in to track your workouts and progress.")
                .font(.system(size: 18, weight: .regular, design: .serif))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            SignInWithAppleButton(
                onRequest: { request in
                    print("[AuthenticationView] SignInWithAppleButton - onRequest called.")
                    authManager.handleSignInWithAppleRequest(request)
                },
                onCompletion: { result in
                    print("[AuthenticationView] SignInWithAppleButton - onCompletion called with result: \(result)")
                    // UIWindow.current is our helper from AuthenticationManager's file
                    authManager.handleSignInWithAppleCompletion(result, window: UIWindow.current)
                }
            )
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            .frame(height: 50) // Standard height
            .padding(.horizontal, 50)
            .accessibilityIdentifier("signInWithAppleButtonAuthView")

            Spacer()
            Spacer()
            
            Text("By signing in, you agree to our Terms of Service and Privacy Policy.")
                 .font(.caption2)
                 .multilineTextAlignment(.center)
                 .padding(.horizontal, 40)
                 .foregroundColor(.gray)
                 .onTapGesture {
                     // Optionally link to your terms and privacy policy
                     // if let url = URL(string: "https://yourwebsite.com/terms") { UIApplication.shared.open(url) }
                 }
                 .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Or use a solid color that adapts, e.g., Color(UIColor.systemGroupedBackground)
        .background(
            LinearGradient(
                gradient: Gradient(colors: colorScheme == .dark ? [Color.black.opacity(0.5), Color.gray.opacity(0.3)] : [Color.gray.opacity(0.05), Color.gray.opacity(0.15)]),
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()
        )
    }
}
