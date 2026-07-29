//
//  iCherriWidgetBundle.swift
//  iCherriWidget
//
//  Created by 정양욱 on 6/29/26.
//

import WidgetKit
import SwiftUI

@main
struct iCherriWidgetBundle: WidgetBundle {
    var body: some Widget {
        iCherriWidget()
        iCherriWidgetControl()
        BackupLiveActivityWidget()
    }
}
