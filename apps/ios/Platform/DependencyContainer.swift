import Factory
import Foundation

extension Container {
    var photoLibraryScanner: Factory<PhotoLibraryScanner> {
        self { MainActor.assumeIsolated { PhotoLibraryScanner() } }
    }
    
    var photoLibraryScanIndexStore: Factory<PhotoLibraryScanIndexStore> {
        self { MainActor.assumeIsolated { PhotoLibraryScanIndexStore.shared } }
    }
    
    var bonjourBrowser: Factory<BonjourBrowser> {
        self { MainActor.assumeIsolated { BonjourBrowser() } }
    }
    
    var keychainStore: Factory<KeychainStore> {
        self { KeychainStore() }
    }
    
    var autoBackupStore: Factory<AutoBackupJobStore> {
        self { AutoBackupJobStore.shared }
    }
    
    var autoBackupScheduler: Factory<AutoBackupScheduler> {
        self { MainActor.assumeIsolated { AutoBackupScheduler.shared } }
    }
    
    var autoBackupEngine: Factory<AutoBackupEngine> {
        self { AutoBackupEngine.shared }
    }
    
    var autoBackupPolicyEvaluator: Factory<AutoBackupPolicyEvaluator> {
        self { AutoBackupPolicyEvaluator() }
    }
}
