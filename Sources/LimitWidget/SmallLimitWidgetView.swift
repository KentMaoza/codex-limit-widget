import CodexLimitCore
import SwiftUI

struct SmallLimitWidgetView: View {
    let snapshot: LimitSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("Codex")
                    .font(.headline)
                Spacer()
                Text(snapshot.compactBalance)
                    .font(.headline)
                    .monospacedDigit()
                    .accessibilityLabel("Balance")
                    .accessibilityValue(snapshot.compactBalance == "—" ? "Unavailable" : snapshot.compactBalance)
            }

            WidgetStatusView(snapshot: snapshot)

            Spacer(minLength: 0)

            WidgetMeter(title: "5h", window: snapshot.fiveHourWindow)
            WidgetMeter(title: "Weekly", window: snapshot.weeklyWindow)
        }
        .padding()
    }
}
