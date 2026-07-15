import AppKit
import CodexLimitCore
import SwiftUI

struct AppStatusPresentation {
    let snapshot: LimitSnapshot

    var symbolName: String {
        switch snapshot.statusLevel {
        case .unavailable:
            return "clock"
        case .error:
            return "exclamationmark.triangle"
        case .critical:
            return "exclamationmark.octagon"
        case .warning:
            return "exclamationmark.triangle"
        case .normal:
            return "gauge"
        }
    }

    var tint: Color {
        switch snapshot.statusLevel {
        case .unavailable:
            return .secondary
        case .error, .warning:
            return .orange
        case .critical:
            return .red
        case .normal:
            return .teal
        }
    }

    var title: String {
        switch snapshot.statusLevel {
        case .unavailable:
            return "Not checked yet"
        case .error:
            return "Update failed"
        case .critical:
            return "Critical: capacity is critically low"
        case .warning:
            return "Warning: capacity is low"
        case .normal:
            return snapshot.statusTitle
        }
    }

    var message: String {
        switch snapshot.statusLevel {
        case .unavailable:
            return "Press Refresh or wait for the first automatic check."
        case .error where snapshot.isStale:
            return "Last-known data remains visible. Try refreshing again."
        case .error:
            return "The latest update or check failed. Try Refresh to check again."
        case .critical:
            return "Critical: one or more usage windows have 15% or less remaining."
        case .warning:
            return "Warning: one or more usage windows have 30% or less remaining."
        case .normal where snapshot.availableResetCount > 0:
            return "The widget opens this reset watcher when clicked."
        case .normal where snapshot.creditBalance != nil:
            return "Flexible credits extend Codex usage after the included limits are exhausted."
        case .normal:
            return "Keep an eye on the usage windows."
        }
    }

    var menuBarAccessibilityValue: String {
        "\(message) \(snapshot.summaryLine)"
    }
}

struct AppHeaderView: View {
    let snapshot: LimitSnapshot

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            appLogo

            VStack(alignment: .leading, spacing: 3) {
                Text("Codex Limit Widget")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                Text("\(snapshot.planLabel) usage monitor")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let configuration = snapshot.configurationLine {
                    Text(configuration)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(snapshot.balanceValue)
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text(snapshot.balanceCaption)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(snapshot.balanceCaption)
            .accessibilityValue(snapshot.balanceValue)
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.separator.opacity(0.35))
        }
    }

    @ViewBuilder
    private var appLogo: some View {
        if let image = NSImage(named: "AppLogo") {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 54, height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.separator.opacity(0.35))
                }
                .accessibilityHidden(true)
        } else {
            Image(systemName: "gauge.with.dots.needle.67percent")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 54, height: 54)
                .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .accessibilityHidden(true)
        }
    }
}

struct AppStatusCard: View {
    let snapshot: LimitSnapshot

    private var presentation: AppStatusPresentation {
        AppStatusPresentation(snapshot: snapshot)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: presentation.symbolName)
                .font(.title2)
                .foregroundStyle(presentation.tint)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(presentation.title)
                    .font(.headline)
                Text(presentation.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(presentation.tint.opacity(0.35))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.title)
        .accessibilityValue(presentation.message)
    }
}

struct AppErrorBanner: View {
    let snapshot: LimitSnapshot

    var body: some View {
        if let message = snapshot.errorMessage {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    if snapshot.isStale {
                        Text("Update failed — showing data from \(snapshot.generatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.subheadline.weight(.semibold))
                    } else {
                        Text("Update failed")
                            .font(.subheadline.weight(.semibold))
                    }
                    Text("Details: \(message)")
                        .font(.subheadline)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Details: \(message)")
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(.orange.opacity(0.30))
            }
            .accessibilityElement(children: .combine)
        }
    }
}
