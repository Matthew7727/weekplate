import SwiftUI

struct MotionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(reduceMotion ? nil : .spring(response: 0.26, dampingFraction: 0.62), value: configuration.isPressed)
    }
}

struct LaunchExperienceView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var scheme
    @State private var barsAppeared = false
    @State private var wordsAppeared = false

    private var barBase: Color {
        scheme == .dark ? Color(red: 0.93, green: 0.94, blue: 0.96) : Brand.ink(.light)
    }
    private var barColours: [Color] {
        [barBase, Brand.blue, barBase, Brand.coral, barBase, barBase, barBase]
    }

    var body: some View {
        ZStack {
            Brand.background(scheme).ignoresSafeArea()
            VStack(spacing: 30) {
                Spacer()
                ZStack {
                    ForEach(0..<7, id: \.self) { index in
                        Rectangle().fill(barColours[index])
                            .frame(width: 250, height: 28)
                            .offset(y: barsAppeared ? CGFloat(index - 3) * 40 : CGFloat(-250 + index * 12))
                            .opacity(barsAppeared || reduceMotion ? 1 : 0)
                            .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.72)
                                .delay(Double(index) * 0.1), value: barsAppeared)
                    }
                }
                .frame(height: 280)

                VStack(spacing: 10) {
                    Text("WEEKPLATE")
                        .font(.system(size: 40, weight: .black))
                        .tracking(-2)
                    Text("Small bites. Big weeks.")
                        .font(.system(size: 18, weight: .bold))
                }
                .foregroundStyle(Brand.ink(scheme))
                .offset(y: wordsAppeared ? 0 : 25)
                .opacity(wordsAppeared ? 1 : 0)
                Spacer()
                Text("MAKE EVERY DAY COUNT")
                    .font(.system(size: 11, weight: .black))
                    .tracking(3)
                    .foregroundStyle(Brand.muted(scheme))
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.72)) { barsAppeared = true }
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(0.85)) { wordsAppeared = true }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Weekplate. Small bites. Big weeks.")
    }
}

struct ActionToastView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let notice: ActionToast
    @State private var burst = false

    var body: some View {
        ZStack {
            ForEach(0..<7, id: \.self) { index in
                Circle()
                    .fill(index.isMultiple(of: 2) ? Brand.coral : Brand.blue)
                    .frame(width: 8, height: 8)
                    .offset(x: burst ? CGFloat(cos(Double(index) * .pi / 3.5) * 125) : 0,
                            y: burst ? CGFloat(sin(Double(index) * .pi / 3.5) * 55) : 0)
                    .opacity(burst ? 0 : 1)
            }
            HStack(spacing: 10) {
                Image(systemName: notice.symbol)
                    .font(.system(size: 19, weight: .black))
                    .symbolEffect(.bounce, value: burst)
                Text(notice.title)
                    .font(.system(size: 16, weight: .black))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 19).padding(.vertical, 14)
            .background(Brand.lime, in: Rectangle())
            .shadow(color: .black.opacity(0.17), radius: 18, y: 8)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.75)) { burst = true }
        }
        .accessibilityLabel(notice.title)
    }
}
