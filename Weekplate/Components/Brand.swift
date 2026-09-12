import SwiftUI

enum Brand {
    static let coral = Color(red: 1.0, green: 0.39, blue: 0.29)
    static let lime = Color(red: 0.78, green: 0.94, blue: 0.36)
    static let blue = Color(red: 0.30, green: 0.42, blue: 0.96)
    static let lilac = Color(red: 0.78, green: 0.69, blue: 0.97)
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.055, green: 0.065, blue: 0.085) : Color(red: 0.965, green: 0.96, blue: 0.94)
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.12, green: 0.13, blue: 0.16) : .white
    }
    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? .white : Color(red: 0.10, green: 0.12, blue: 0.15)
    }
    static func muted(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.white.opacity(0.57) : Color.black.opacity(0.48)
    }
}

struct WCard<Content: View>: View {
    @Environment(\.colorScheme) private var scheme
    var color: Color? = nil
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color ?? Brand.surface(scheme), in: RoundedRectangle(cornerRadius: 24))
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Brand.coral
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .black, design: .rounded))
            .tracking(2.2)
            .foregroundStyle(color)
    }
}

struct PillButton: View {
    let title: String
    let symbol: String
    var color: Color = Brand.coral
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 13)
                .background(color, in: Capsule())
        }
        .buttonStyle(MotionButtonStyle())
    }
}

struct ScreenHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Eyebrow(text: eyebrow)
            Text(title)
                .font(.system(size: 38, weight: .black, design: .rounded))
                .tracking(-1.8)
            Text(subtitle).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension Double {
    var kcalText: String { Int(self.rounded()).formatted() }
    var portionText: String { self.formatted(.number.precision(.fractionLength(0...1))) }
}
