import SwiftUI

@main
struct ApexPlayerApp: App {
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: MainViewModel(container: container))
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.automatic)
    }
}
