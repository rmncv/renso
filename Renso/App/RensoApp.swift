import SwiftUI
import SwiftData
import PostHog

@main
struct RensoApp: App {
    @State private var router = NavigationRouter()

    var sharedModelContainer: ModelContainer = {
        do {
            return try ModelContainerSetup.createContainer()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    init() {
        setupPostHog()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(router)
                .onAppear {
                    seedDefaultData()
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func setupPostHog() {
        // Configure PostHog - API key should be stored securely
        // For now, this is a placeholder. Replace with your actual PostHog API key
        let config = PostHogConfig(apiKey: "phc_placeholder_key_replace_with_actual")
        config.captureApplicationLifecycleEvents = true
        config.captureScreenViews = true
        PostHogSDK.shared.setup(config)
    }

    private func seedDefaultData() {
        let context = sharedModelContainer.mainContext
        let seeder = DataSeeder(modelContext: context)

        Task {
            do {
                try await seeder.seedDefaultDataIfNeeded()
            } catch {
                print("Failed to seed default data: \(error)")
            }
        }
    }
}
