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
    @State private var plateAppeared = false
    @State private var wordsAppeared = false
    @State private var dotsSpinning = false

    var body: some View {
        ZStack {
            Brand.lime.ignoresSafeArea()
            VStack(spacing: 25) {
                Spacer()
                ZStack {
                    Circle().fill(Brand.coral)
                        .frame(width: 248, height: 248)
                    Circle().fill(Color(red: 0.09, green: 0.12, blue: 0.17))
                        .frame(width: 204, height: 204)
                    Circle().fill(Brand.lime)
                        .frame(width: 160, height: 160)
                    ForEach(0..<7, id: \.self) { index in
                        Circle().fill(Color(red: 0.09, green: 0.12, blue: 0.17))
                            .frame(width: 14, height: 14)
                            .offset(y: -65)
                            .rotationEffect(.degrees(Double(index) * 360 / 7))
                    }
                    .rotationEffect(.degrees(dotsSpinning ? 360 : 0))
                    Image(systemName: "fork.knife")
                        .font(.system(size: 62, weight: .black))
                        .foregroundStyle(Color(red: 0.09, green: 0.12, blue: 0.17))
                        .symbolEffect(.bounce, value: plateAppeared)
                }
                .scaleEffect(plateAppeared ? 1 : 0.35)
                .rotationEffect(.degrees(plateAppeared ? 0 : -22))
                .opacity(plateAppeared ? 1 : 0)

                VStack(spacing: 10) {
                    Text("WEEKPLATE")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .tracking(-2)
                    Text("Small bites. Big weeks.")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                }
                .foregroundStyle(Color(red: 0.09, green: 0.12, blue: 0.17))
                .offset(y: wordsAppeared ? 0 : 25)
                .opacity(wordsAppeared ? 1 : 0)
                Spacer()
                Text("MAKE EVERY DAY COUNT")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .tracking(3)
                    .foregroundStyle(.black.opacity(0.55))
                    .padding(.bottom, 32)
            }
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .spring(response: 0.65, dampingFraction: 0.62)) { plateAppeared = true }
            withAnimation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) { wordsAppeared = true }
            if !reduceMotion {
                withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) { dotsSpinning = true }
            }
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
                    .font(.system(size: 16, weight: .black, design: .rounded))
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 19).padding(.vertical, 14)
            .background(Brand.lime, in: Capsule())
            .shadow(color: .black.opacity(0.17), radius: 18, y: 8)
        }
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.75)) { burst = true }
        }
        .accessibilityLabel(notice.title)
    }
}
