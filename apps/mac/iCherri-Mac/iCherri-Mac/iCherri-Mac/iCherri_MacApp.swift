//
//  iCherri_MacApp.swift
//  iCherri-Mac
//
//  Created by 정양욱 on 5/26/26.
//

import SwiftUI
import iCherri_Mac

@main
struct iCherri_MacApp: App {
    init() {
        Task {
            await AppCoordinator.shared.start()
        }
    }

    var body: some Scene {
        MenuBarExtraItem()
    }
}
