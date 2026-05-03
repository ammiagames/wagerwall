import SwiftUI

struct ProgressTabView: View {
    var body: some View {
        ScrollView {
            Text("Coming Soon")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.top, 100)
        }
        .navigationTitle("Progress")
    }
}
