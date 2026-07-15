import CodexLimitCore
import SwiftUI

struct MediumLimitWidgetView: View {
    let snapshot: LimitSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            WidgetHeaderView(snapshot: snapshot)

            HStack(spacing: 12) {
                WidgetMeter(title: "5h", window: snapshot.fiveHourWindow, showsReset: true)
                WidgetMeter(title: "Weekly", window: snapshot.weeklyWindow, showsReset: true)
            }

            WidgetStatusView(snapshot: snapshot)
        }
        .padding()
    }
}
