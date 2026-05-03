import Foundation
import GoogleSignIn
import Supabase

@Observable
final class AuthService {
    var session: Session?
    var isLoading = true
    var errorMessage: String?

    var isAuthenticated: Bool {
        session != nil
    }

    var userEmail: String? {
        session?.user.email
    }

    // Returns the signed-in user's id, or `Config.devUserId` when auth is bypassed.
    // Lets views proceed past their `guard let userId = ...` checks while sign-in is disabled.
    var currentUserId: UUID? {
        session?.user.id ?? Config.devUserId
    }

    func startAuthListener() {
        Task {
            for await (_, session) in supabase.auth.authStateChanges {
                self.session = session
                self.isLoading = false
            }
        }
    }

    func signInWithGoogle() async {
        errorMessage = nil
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootViewController = windowScene.windows.first?.rootViewController else {
                errorMessage = "Unable to find root view controller"
                return
            }

            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)

            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get ID token from Google"
                return
            }

            try await supabase.auth.signInWithIdToken(credentials: .init(
                provider: .google,
                idToken: idToken,
                accessToken: result.user.accessToken.tokenString
            ))
        } catch {
            // GIDSignIn error code -5 is user cancellation
            if (error as NSError).code != -5 {
                errorMessage = error.localizedDescription
            }
        }
    }

    func signOut() async {
        do {
            GIDSignIn.sharedInstance.signOut()
            try await supabase.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
