import SiteThreadCore
import SwiftUI

/// Fixed status colours, deliberately independent of the system accent so an
/// unreachable site always reads as red.
enum Palette {
    static let urgent = Color(red: 1.0, green: 0.30, blue: 0.35)
    static let healthy = Color(red: 0.26, green: 0.84, blue: 0.42)
    static let backup = Color(red: 0.95, green: 0.81, blue: 0.30)
    static let dim = Color.secondary

    static func color(for status: SiteStatus) -> Color {
        switch status {
        case .down: return urgent
        case .backup: return backup
        case .up: return healthy
        }
    }

    static func symbol(for severity: Severity) -> String {
        switch severity {
        case .critical: return "exclamationmark.triangle.fill"
        case .warning: return "exclamationmark.triangle"
        case .healthy: return "network"
        case .disconnected: return "network.slash"
        }
    }

    static func color(for severity: Severity) -> Color {
        switch severity {
        case .critical: return urgent
        case .warning: return backup
        case .healthy: return healthy
        case .disconnected: return dim
        }
    }
}

struct SectionHeader: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundColor(Palette.dim)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The bordered surface used for every card and row in the panel.
struct Card<Content: View>: View {
    var borderColor: Color = Color.primary.opacity(0.10)
    var fill: Color = Color.primary.opacity(0.04)
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(borderColor, lineWidth: 1))
    }
}

struct StatusDot: View {
    let color: Color
    var size: CGFloat = 9

    var body: some View {
        Circle().fill(color).frame(width: size, height: size)
    }
}

struct StatTile: View {
    let symbol: String
    let value: Int
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: symbol).font(.system(size: 13))
                Text("\(value)").font(.title3.bold())
                Text(label).font(.caption2).foregroundColor(Palette.dim)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        selected ? Color.accentColor : Color.primary.opacity(0.10),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

struct TabBar: View {
    let labels: [String]
    @Binding var selection: Int
    var onChange: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(labels.enumerated()), id: \.offset) { entry in
                Button {
                    selection = entry.offset
                    onChange()
                } label: {
                    Text(entry.element)
                        .font(.system(size: 12, weight: selection == entry.offset ? .semibold : .regular))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    selection == entry.offset
                                        ? Color.accentColor.opacity(0.22)
                                        : Color.primary.opacity(0.05)
                                )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(
                                    selection == entry.offset ? Color.accentColor : Color.clear,
                                    lineWidth: 1
                                )
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// One device row, shared by the fleet list and the per-site list.
struct DeviceRow: View {
    let device: Device
    var fallbackName: String = "UniFi device"

    private var stateLabel: String {
        if !device.online { return "OFFLINE" }
        return device.update ? "UPDATE" : "ONLINE"
    }

    var body: some View {
        Card {
            HStack(spacing: 10) {
                StatusDot(color: device.online ? Palette.healthy : Palette.urgent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(device.name.isEmpty ? fallbackName : device.name)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(Palette.dim)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text(stateLabel)
                    .font(.caption2)
                    .foregroundColor(device.online ? Palette.dim : Palette.urgent)
            }
        }
    }

    private var subtitle: String {
        if !device.site.isEmpty { return device.site }
        if device.ip.isEmpty { return device.model }
        return device.model.isEmpty ? device.ip : "\(device.model)  ·  \(device.ip)"
    }
}

struct SiteRow: View {
    let site: Site
    let trailing: String
    let trailingColor: Color
    let dotColor: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Card {
                HStack(spacing: 9) {
                    StatusDot(color: dotColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(site.name.isEmpty ? "UniFi site" : site.name)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundColor(Palette.dim)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 6)
                    Text(trailing).font(.caption2).foregroundColor(trailingColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var subtitle: String {
        let status = site.statusText.isEmpty ? "Online" : site.statusText
        return site.isp.isEmpty ? status : "\(site.isp)  ·  \(status)"
    }
}

struct CameraTile: View {
    let camera: Camera
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(camera.name.isEmpty ? "Camera" : camera.name)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)
                Text(camera.online ? "ONLINE" : "OFFLINE")
                    .font(.caption2)
                    .foregroundColor(camera.online ? Palette.healthy : Palette.urgent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.05))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(selected ? Color.accentColor : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Snapshot viewer with the live camera name overlaid.
struct CameraStage: View {
    let image: NSImage?
    let name: String
    let placeholder: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.45))
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text(placeholder)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Text(name.isEmpty ? "" : "LIVE · \(name)")
                .font(.caption2)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color.black.opacity(0.65)))
                .padding(8)
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct EmptyNote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundColor(Palette.dim)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 6)
    }
}
