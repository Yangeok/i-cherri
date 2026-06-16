//
//  iCherri_iosApp.swift
//  iCherri-ios
//
//  Created by 정양욱 on 5/26/26.
//

import BackgroundTasks
import SwiftUI

@main
struct iCherri_iosApp: App {
    init() {
        AutoBackupScheduler.shared.registerBackgroundTasks()
        AutoBackupScheduler.shared.scheduleNextEvaluation()
    }

    var body: some Scene {
        WindowGroup {
            BackupDashboardView()
        }
    }
}
