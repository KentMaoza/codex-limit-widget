import CodexLimitCore
import SwiftUI

struct LargeLimitWidgetView: View {
    let snapshot: LimitSnapshot

    private var visibleWindows: [LimitWindowSnapshot] {
        Array(snapshot.windows.prefix(4))
    }

    private var overflowCount: Int {
        max(0, snapshot.windows.count - visibleWindows.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            WidgetHeaderView(snapshot: snapshot, large: true)

            if snapshot.windows.isEmpty {
                WidgetStatusView(snapshot: snapshot, showsErrorDetail: true)
                Spacer(minLength: 0)
            } else {
                ForEach(visibleWindows) { window in
                    WidgetMeter(
                        title: window.title,
                        window: window,
                        showsUsage: true,
                        showsReset: true
                    )
                }

                if overflowCount > 0 {
                    Text("+\(overflowCount) more in app")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("\(overflowCount) more usage windows in app")
                }

                Spacer(minLength: 0)
                WidgetStatusView(snapshot: snapshot, showsErrorDetail: true)
            }
        }
        .padding()
    }
}
