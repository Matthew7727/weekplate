import SwiftUI

enum Brand {
    // A sharp, graphic palette. Colour is used as a signal, not decoration.
    static let coral = Color(red: 0.88, green: 0.08, blue: 0.25) // signal red
    static let lime = Color(red: 1.0, green: 0.82, blue: 0.20) // signal yellow
    static let blue = Color(red: 0.12, green: 0.22, blue: 0.82) // cobalt
    static let lilac = Color(red: 0.69, green: 0.55, blue: 0.94) // ultraviolet
    static func background(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.035, green: 0.045, blue: 0.075) : Color(red: 0.96, green: 0.955, blue: 0.92)
    }
    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(red: 0.075, green: 0.09, blue: 0.14) : .white
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
            .background(color ?? Brand.surface(scheme), in: Rectangle())
            .overlay(Rectangle().stroke(Brand.ink(scheme).opacity(0.14), lineWidth: 1))
    }
}

struct Eyebrow: View {
    let text: String
    var color: Color = Brand.coral
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 11, weight: .black))
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
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 18).padding(.vertical, 13)
                .background(color, in: Rectangle())
        }
        .buttonStyle(MotionButtonStyle())
    }
}

struct ScreenHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    var alignment: HorizontalAlignment = .leading
    var body: some View {
        VStack(alignment: alignment, spacing: 6) {
            Eyebrow(text: eyebrow)
            Text(title)
                .font(.system(size: 38, weight: .black))
                .tracking(-1.4)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(alignment == .center ? .center : .leading)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .center ? .center : .leading)
    }
}

extension Double {
    var kcalText: String { Int(self.rounded()).formatted() }
    var portionText: String { self.formatted(.number.precision(.fractionLength(0...1))) }
}
