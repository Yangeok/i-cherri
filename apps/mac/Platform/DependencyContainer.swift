import Factory
import Foundation

extension Container {
    var databaseManager: Factory<DatabaseManager> {
        self { DatabaseManager.shared }
    }
    
    var appCoordinator: Factory<AppCoordinator> {
        self { MainActor.assumeIsolated { AppCoordinator.shared } }
    }
}
