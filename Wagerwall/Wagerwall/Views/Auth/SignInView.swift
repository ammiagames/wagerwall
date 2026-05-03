import SwiftUI

struct SignInView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 72))
                    .foregroundStyle(.blue)

                Text("WagerWall")
                    .font(.largeTitle.bold())

                Text("Take control of your gambling habits")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            if let error = auth.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button {
                Task { await auth.signInWithGoogle() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                    Text("Sign in with Google")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)

            Spacer()
                .frame(height: 48)
        }
    }
}
