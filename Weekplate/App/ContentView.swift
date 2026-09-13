import SwiftUI

private enum AppTab: String, CaseIterable {
    case week = "Week", recipes = "Recipes", find = "Find", trends = "Trends", you = "You"
    var symbol: String {
        switch self {
        case .week: "square.grid.2x2.fill"
        case .recipes: "fork.knife"
        case .find: "barcode.viewfinder"
        case .trends: "chart.xyaxis.line"
        case .you: "person.crop.circle"
        }
    }
}

struct ContentView: View {
    @ObservedObject var store: AppStore
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var tab: AppTab = .week
    @State private var showSplash = true
    @AppStorage("weekplate.splashSeen") private var hasSeenSplash = false

    var body: some View {
        ZStack(alignment: .top) {
            VStack(spacing: 0) {
            Group {
                switch tab {
                case .week: WeekView(store: store)
                case .recipes: RecipesView(store: store)
                case .find: FindFoodView(store: store)
                case .trends: TrendsView(store: store)
                case .you: SettingsView(store: store)
                }
            }
            .id(tab)
            .transition(.opacity.combined(with: .move(edge: .trailing)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { item in
                    Button {
                        withAnimation(.spring(response: 0.38, dampingFraction: 0.85)) { tab = item }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: item.symbol).font(.system(size: 19, weight: .bold))
                            Text(item.rawValue).font(.system(size: 10, weight: .bold))
                        }
                        .foregroundStyle(tab == item ? Brand.coral : Brand.muted(scheme))
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(MotionButtonStyle())
                    .accessibilityLabel(item.rawValue)
                }
            }
            .padding(.top, 13).padding(.bottom, 6)
            .background(Brand.surface(scheme))
            }
            if let notice = store.toast, !showSplash {
                ActionToastView(notice: notice)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(2)
            }
            if showSplash {
                LaunchExperienceView()
                    .transition(.opacity.combined(with: .scale(scale: 1.06)))
                    .zIndex(3)
            }
        }
        .background(Brand.background(scheme).ignoresSafeArea())
        .foregroundStyle(Brand.ink(scheme))
        .animation(.spring(response: 0.45, dampingFraction: 0.78), value: store.toast?.id)
        .task {
            // Leave a short reading pause after the bars and wordmark settle.
            try? await Task.sleep(for: .seconds(reduceMotion ? 0.35 : (hasSeenSplash ? 1.65 : 2.6)))
            withAnimation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.88)) { showSplash = false }
            hasSeenSplash = true
        }
    }
}
