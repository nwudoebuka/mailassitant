import SwiftUI
import GoogleSignIn

@main
struct MailAssistantApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}

struct RootView: View {
    @StateObject private var auth = GoogleAuthManager.shared

    var body: some View {
        if auth.isSignedIn {
            ChatView()
        } else {
            SignInView()
        }
    }
}
