import SwiftUI

struct MotivationalCardView: View {
    let onComplete: () -> Void

    @State private var currentIndex: Int = 0
    @State private var offset: CGFloat = 0

    private let quotes = Array(PanicButtonViewModel.motivationalQuotes.shuffled().prefix(5))

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("You've Got This")
                .font(.title2.bold())

            Text("Swipe through these reminders")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Quote card
            if currentIndex < quotes.count {
                let quote = quotes[currentIndex]

                VStack(spacing: 16) {
                    Image(systemName: "quote.opening")
                        .font(.title)
                        .foregroundStyle(.blue.opacity(0.5))

                    Text(quote.text)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("— \(quote.author)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 24)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 50
                            if value.translation.width < -threshold && currentIndex < quotes.count - 1 {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    offset = -400
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    currentIndex += 1
                                    offset = 400
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        offset = 0
                                    }
                                }
                            } else if value.translation.width > threshold && currentIndex > 0 {
                                withAnimation(.easeOut(duration: 0.25)) {
                                    offset = 400
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                                    currentIndex -= 1
                                    offset = -400
                                    withAnimation(.easeOut(duration: 0.25)) {
                                        offset = 0
                                    }
                                }
                            } else {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    offset = 0
                                }
                            }
                        }
                )
            }

            // Page indicator
            HStack(spacing: 6) {
                ForEach(0..<quotes.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentIndex ? Color.blue : Color.secondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            WagerWallButton(title: "I Feel Better") {
                onComplete()
            }
            .padding(.bottom, 16)
        }
        .navigationTitle("Stay Strong")
        .navigationBarTitleDisplayMode(.inline)
    }
}
