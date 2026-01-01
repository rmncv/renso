import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(NavigationRouter.self) private var router
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        @Bindable var router = router

        TabView(selection: $router.selectedTab) {
            DashboardTab()
                .tabItem {
                    Label(Tab.dashboard.title, systemImage: Tab.dashboard.icon)
                }
                .tag(Tab.dashboard)

            TransactionsTab()
                .tabItem {
                    Label(Tab.transactions.title, systemImage: Tab.transactions.icon)
                }
                .tag(Tab.transactions)

            AnalyticsTab()
                .tabItem {
                    Label(Tab.analytics.title, systemImage: Tab.analytics.icon)
                }
                .tag(Tab.analytics)

            SettingsTab()
                .tabItem {
                    Label(Tab.settings.title, systemImage: Tab.settings.icon)
                }
                .tag(Tab.settings)
        }
    }
}

// MARK: - Tab Views

struct DashboardTab: View {
    var body: some View {
        DashboardView()
    }
}

struct TransactionsTab: View {
    var body: some View {
        TransactionsListView()
    }
}

struct AnalyticsTab: View {
    var body: some View {
        AnalyticsView()
    }
}

struct SettingsTab: View {
    var body: some View {
        SettingsView()
    }
}

#Preview {
    ContentView()
        .environment(NavigationRouter())
        .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}
