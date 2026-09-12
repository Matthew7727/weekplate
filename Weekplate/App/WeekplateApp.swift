import SwiftUI

@main @MainActor struct WeekplateApp: App {
    @StateObject private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .preferredColorScheme(store.data.theme == .system ? nil :
                    (store.data.theme == .dark ? .dark : .light))
        }
    }
}
