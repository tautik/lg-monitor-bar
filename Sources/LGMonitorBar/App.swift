import AppKit
import DDC
import OSLog
import ServiceManagement
import SwiftUI

private let writer = DDCWriter()
private let log = Logger(subsystem: "lg-monitor-bar", category: "ddc")

private func send(_ vcp: VCP, _ value: Int) {
    writer.set(vcp, UInt16(value)) { ok in
        log.notice("set \(String(describing: vcp), privacy: .public)=\(value) ok=\(ok)")
    }
}

@main
struct LGMonitorBarApp: App {
    var body: some Scene {
        MenuBarExtra {
            ControlPanel()
        } label: {
            Image(systemName: "sun.max").accessibilityLabel("LG Monitor")
        }
        .menuBarExtraStyle(.window)
    }
}

struct ControlPanel: View {
    @AppStorage("colorPreset") private var preset = 5
    @State private var showColor = false
    @State private var openAtLogin = SMAppService.mainApp.status == .enabled
    @State private var keepAwake = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(externalDisplayName()).font(.headline)

            SettingSlider("Brightness", "sun.max", .brightness, default: 70)
            SettingSlider("Contrast", "circle.lefthalf.filled", .contrast, default: 70)
            SettingSlider("Sharpness", "camera.metering.spot", .sharpness, default: 50)
            SettingSlider("Volume", "speaker.wave.2", .volume, default: 30)

            Picker("Colour", selection: $preset) {
                Text("Warm 5000K").tag(4)
                Text("6500K").tag(5)
                Text("Cool 9300K").tag(8)
                Text("sRGB").tag(1)
                Text("Custom").tag(11)
            }
            .onChange(of: preset) { _, new in send(.colorPreset, new) }

            DisclosureGroup("Colour gain (Custom preset)", isExpanded: $showColor) {
                SettingSlider("Red", "circle.fill", .redGain, default: 50, tint: .red)
                SettingSlider("Green", "circle.fill", .greenGain, default: 50, tint: .green)
                SettingSlider("Blue", "circle.fill", .blueGain, default: 50, tint: .blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Input").font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    // LG input codes from m1ddc's input-alt table.
                    Button("USB-C") { send(.input, 210) }
                    Button("DisplayPort") { send(.input, 208) }
                    Button("HDMI 1") { send(.input, 144) }
                    Button("HDMI 2") { send(.input, 145) }
                }
                .controlSize(.small)
            }

            Divider()

            Toggle("Keep Mac awake with lid closed", isOn: $keepAwake)
                .toggleStyle(.checkbox)
                .controlSize(.small)
                .help("Stops the Mac sleeping when the monitor switches to another input. Asks for your password.")
                .onAppear { keepAwake = sleepDisabled() }
                .onChange(of: keepAwake) { _, on in
                    // Also fires when we sync the box to the real state; only act on a real change.
                    guard on != sleepDisabled() else { return }
                    Task.detached {
                        run("/usr/bin/osascript", ["-e", "do shell script \"/usr/bin/pmset -a disablesleep \(on ? 1 : 0)\" with administrator privileges"])
                        let now = sleepDisabled()
                        await MainActor.run { keepAwake = now }
                    }
                }

            HStack {
                Toggle("Open at login", isOn: $openAtLogin)
                    .toggleStyle(.checkbox)
                    .onChange(of: openAtLogin) { _, on in
                        do {
                            try on ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
                        } catch {
                            log.error("login item: \(error.localizedDescription, privacy: .public)")
                            openAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)

            Text("The monitor can't report its settings to this Mac, so these show what you last set here.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 320)
    }
}

struct SettingSlider: View {
    let title: String
    let icon: String
    let vcp: VCP
    let tint: Color
    @AppStorage private var value: Double

    init(_ title: String, _ icon: String, _ vcp: VCP, default initial: Double, tint: Color = .accentColor) {
        self.title = title
        self.icon = icon
        self.vcp = vcp
        self.tint = tint
        _value = AppStorage(wrappedValue: initial, "\(vcp)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Label(title, systemImage: icon)
                Spacer()
                Text("\(Int(value))").monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: $value, in: 0...100)
                .tint(tint)
                .accessibilityLabel(title)
                .onChange(of: Int(value)) { _, new in send(vcp, new) }
        }
    }
}

@discardableResult
private func run(_ path: String, _ args: [String]) -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: path)
    process.arguments = args
    process.standardOutput = pipe
    guard (try? process.run()) != nil else { return "" }
    let out = pipe.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()
    return String(decoding: out, as: UTF8.self)
}

/// True when `pmset disablesleep` is on, the only setting that keeps a closed-lid Mac awake with no display.
private func sleepDisabled() -> Bool {
    run("/usr/bin/pmset", ["-g"]).range(of: #"SleepDisabled\s+1"#, options: .regularExpression) != nil
}

private func externalDisplayName() -> String {
    let external = NSScreen.screens.first { screen in
        let id = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
        return id.map { CGDisplayIsBuiltin($0) == 0 } ?? false
    }
    return external?.localizedName ?? "No external display"
}
