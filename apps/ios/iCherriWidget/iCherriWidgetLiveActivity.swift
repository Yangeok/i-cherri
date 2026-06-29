import SwiftUI
import WidgetKit
import ActivityKit

// MARK: - Shared Attributes Model (Must match host app exactly)
public struct BackupActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var completedCount: Int
        public var totalCount: Int
        public var formattedSpeed: String
        public var currentFilename: String?

        public init(
            progress: Double,
            completedCount: Int,
            totalCount: Int,
            formattedSpeed: String,
            currentFilename: String? = nil
        ) {
            self.progress = progress
            self.completedCount = completedCount
            self.totalCount = totalCount
            self.formattedSpeed = formattedSpeed
            self.currentFilename = currentFilename
        }
    }

    public let deviceName: String
    
    public init(deviceName: String) {
        self.deviceName = deviceName
    }
}

// MARK: - Widget Configuration
struct BackupLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BackupActivityAttributes.self) { context in
            // UI for Lock Screen and Banner (iOS 16.1+)
            BackupLiveActivityView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI when user long-presses the Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise.icloud.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("i-Cherri 백업")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(context.attributes.deviceName)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.formattedSpeed)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                        
                        Text("\(context.state.completedCount) / \(context.state.totalCount) 개")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let filename = context.state.currentFilename {
                            Text(filename)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        ProgressView(value: context.state.progress, total: 1.0)
                            .progressViewStyle(.linear)
                            .tint(.blue)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.clockwise.icloud.fill")
                        .foregroundColor(.blue)
                    Text("\(Int(context.state.progress * 100))%")
                        .font(.caption2)
                        .fontWeight(.semibold)
                }
            } compactTrailing: {
                Text(context.state.formattedSpeed)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            } minimal: {
                Image(systemName: "arrow.clockwise.icloud.fill")
                    .foregroundColor(.blue)
            }
        }
    }
}

// Lock Screen / Notification Banner UI
struct BackupLiveActivityView: View {
    let context: ActivityViewContext<BackupActivityAttributes>
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.clockwise.icloud.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    Text("i-Cherri 백업 중")
                        .font(.headline)
                }
                
                Spacer()
                
                Text(context.state.formattedSpeed)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            if let filename = context.state.currentFilename {
                Text(filename)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            HStack(spacing: 12) {
                ProgressView(value: context.state.progress, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                
                Text("\(Int(context.state.progress * 100))%")
                    .font(.caption)
                    .fontWeight(.bold)
                    .frame(width: 36, alignment: .trailing)
            }
            
            HStack {
                Text("보낼 대상: \(context.attributes.deviceName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(context.state.completedCount) / \(context.state.totalCount) 완료")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
