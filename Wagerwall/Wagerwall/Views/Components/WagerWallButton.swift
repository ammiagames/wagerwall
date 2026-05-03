import SwiftUI

struct WagerWallButton: View {
    let title: String
    var style: ButtonStyle = .primary
    var isLoading: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    enum ButtonStyle {
        case primary
        case secondary
        case outline
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(style == .outline ? .blue : .white)
                } else {
                    Text(title)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(backgroundColor)
            .foregroundStyle(foregroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                if style == .outline {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(.blue, lineWidth: 2)
                }
            }
        }
        .disabled(isDisabled || isLoading)
        .opacity(isDisabled ? 0.5 : 1.0)
        .padding(.horizontal, 24)
    }

    private var backgroundColor: Color {
        switch style {
        case .primary: .blue
        case .secondary: .secondary.opacity(0.2)
        case .outline: .clear
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .primary: .white
        case .secondary: .primary
        case .outline: .blue
        }
    }
}
