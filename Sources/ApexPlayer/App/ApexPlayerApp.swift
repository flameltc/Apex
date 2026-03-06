import SwiftUI

@main
struct ApexPlayerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var container = AppContainer()

    var body: some Scene {
        WindowGroup {
            MainView(viewModel: MainViewModel(container: container))
                .frame(minWidth: 980, minHeight: 620)
        }
        .windowStyle(.automatic)
    }
}
