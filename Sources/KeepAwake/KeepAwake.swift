import AppKit
import ServiceManagement
import SwiftUI

struct CaffeinateFlags: Equatable, Sendable {
    var preventDisplaySleep = false
    var preventIdleSleep = false
    var preventDiskSleep = false
    var preventSystemSleep = false
    var declareUserActivity = false

    var arguments: [String] {
        var flags: [String] = []

        if preventDisplaySleep { flags.append("-d") }
        if preventIdleSleep { flags.append("-i") }
        if preventDiskSleep { flags.append("-m") }
        if preventSystemSleep { flags.append("-s") }
        if declareUserActivity { flags.append("-u") }

        return flags
    }

    var hasSelectedFlags: Bool {
        !arguments.isEmpty
    }

    var summary: String {
        let flags = arguments
        return flags.isEmpty ? "(none)" : flags.joined(separator: " ")
    }
}

@MainActor
final class CaffeinateController: ObservableObject {
    @Published var flags = CaffeinateFlags()
    @Published private(set) var isRunning = false
    @Published private(set) var activeArguments: [String] = []
    @Published private(set) var statusText = "Idle"

    private var process: Process?

    func toggle() {
        isRunning ? stop() : start()
    }

    func start() {
        guard process == nil else { return }
        guard flags.hasSelectedFlags else {
            statusText = "Select a flag"
            return
        }

        let newProcess = Process()
        newProcess.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        newProcess.arguments = flags.arguments
        newProcess.terminationHandler = { [weak self] process in
            Task { @MainActor in
                guard let self else { return }
                self.process = nil
                self.isRunning = false
                self.statusText = process.terminationReason == .exit ? "Stopped" : "Interrupted"
            }
        }

        do {
            try newProcess.run()
            process = newProcess
            activeArguments = flags.arguments
            isRunning = true
            statusText = "Running"
        } catch {
            process = nil
            isRunning = false
            statusText = "Failed: \(error.localizedDescription)"
        }
    }

    func stop() {
        guard let process else { return }

        if process.isRunning {
            process.terminate()
        }

        self.process = nil
        isRunning = false
        statusText = "Stopping..."
    }
}

@MainActor
final class LoginItemController: ObservableObject {
    @Published private(set) var isOpenAtLoginEnabled = false
    @Published private(set) var statusText = "Checking..."
    @Published private(set) var detailText: String?
    @Published private(set) var needsApproval = false

    private let service = SMAppService.mainApp

    init() {
        refresh()
    }

    func setOpenAtLogin(_ isEnabled: Bool) {
        do {
            let status = service.status

            if isEnabled {
                if status != .enabled && status != .requiresApproval {
                    try service.register()
                }
            } else if status == .enabled || status == .requiresApproval {
                try service.unregister()
            }

            refresh()
        } catch {
            refresh()
            detailText = error.localizedDescription
        }
    }

    func refresh() {
        switch service.status {
        case .enabled:
            isOpenAtLoginEnabled = true
            needsApproval = false
            statusText = "Enabled"
            detailText = nil
        case .requiresApproval:
            isOpenAtLoginEnabled = true
            needsApproval = true
            statusText = "Needs Approval"
            detailText = "Allow KeepAwake in Login Items."
        case .notRegistered:
            isOpenAtLoginEnabled = false
            needsApproval = false
            statusText = "Disabled"
            detailText = nil
        case .notFound:
            isOpenAtLoginEnabled = false
            needsApproval = false
            statusText = "Unavailable"
            detailText = "Run KeepAwake from its app bundle."
        @unknown default:
            isOpenAtLoginEnabled = false
            needsApproval = false
            statusText = "Unknown"
            detailText = nil
        }
    }

    func openLoginItemsSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

struct MenuBarView: View {
    @ObservedObject var controller: CaffeinateController
    @ObservedObject var loginItemController: LoginItemController

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.03), Color.black.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            VStack(alignment: .leading, spacing: 16) {
                heroStateCard
                selectedFlagsSection
                actionButtons
                controlsSection
                loginItemSection
                quitButton
            }
            .padding(16)
        }
        .frame(width: 390)
        .onAppear {
            loginItemController.refresh()
        }
    }

    private var heroStateCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: controller.isRunning ? "bolt.fill" : "moon.zzz.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(statusTint)
                    .frame(width: 34, height: 34)
                    .background(statusTint.opacity(0.14), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(controller.isRunning ? "KeepAwake Active" : "KeepAwake Inactive")
                        .font(.headline.weight(.semibold))
                    Text(controller.isRunning ? "Sleep prevention is currently enabled." : "Mac sleep behavior is normal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(controller.statusText.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                    .foregroundStyle(statusTint)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(statusTint)
                    .frame(width: 8, height: 8)
                Text(controller.isRunning ? "ACTIVE" : "NOT ACTIVE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 2)

            VStack(alignment: .leading, spacing: 8) {
                Text("Current flags")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if displayedArguments.isEmpty {
                    Text(controller.isRunning ? "Running with default caffeinate behavior." : "No flags selected yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    flagChipWrap(arguments: displayedArguments)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private var selectedFlagsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Keep Mac awake with")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary.opacity(0.9))

            flagToggle(title: "Prevent display sleep", subtitle: "Keep the screen awake", flag: "-d", isOn: $controller.flags.preventDisplaySleep)
            flagToggle(title: "Prevent idle sleep", subtitle: "Stop idle sleep while active", flag: "-i", isOn: $controller.flags.preventIdleSleep)
            flagToggle(title: "Prevent disk sleep", subtitle: "Avoid disk sleep", flag: "-m", isOn: $controller.flags.preventDiskSleep)
            flagToggle(title: "Prevent system sleep", subtitle: "Keep the whole system awake", flag: "-s", isOn: $controller.flags.preventSystemSleep)
            flagToggle(title: "Declare user activity", subtitle: "Simulate recent activity", flag: "-u", isOn: $controller.flags.declareUserActivity)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
    }

    private var controlsSection: some View {
        HStack(spacing: 10) {
            Label(controlStatusText, systemImage: controller.isRunning ? "lock.fill" : "slider.horizontal.3")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(.horizontal, 2)
    }

    private var loginItemSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { loginItemController.isOpenAtLoginEnabled },
                set: { loginItemController.setOpenAtLogin($0) }
            )) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(loginItemController.isOpenAtLoginEnabled ? .green : .secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch at Login")
                            .font(.subheadline.weight(.medium))
                        Text(loginItemController.statusText)
                            .font(.caption)
                            .foregroundStyle(loginItemController.needsApproval ? .orange : .secondary)
                    }
                }
            }
            .toggleStyle(RightCheckToggleStyle(isLocked: false))

            if let detailText = loginItemController.detailText {
                Text(detailText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if loginItemController.needsApproval {
                Button {
                    loginItemController.openLoginItemsSettings()
                } label: {
                    Label("Open Login Items", systemImage: "gearshape.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.primary.opacity(0.055))
        )
    }

    private var actionButtons: some View {
        Button {
            guard canToggle else { return }
            controller.toggle()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: actionIconName)
                    .font(.title3.weight(.bold))
                VStack(alignment: .leading, spacing: 1) {
                    Text(actionTitle)
                        .font(.headline.weight(.semibold))
                    Text(actionSubtitle)
                        .font(.caption)
                        .opacity(0.92)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(actionTint)
            )
            .foregroundStyle(.white)
        }
        .keyboardShortcut(.defaultAction)
        .buttonStyle(.plain)
    }

    private var quitButton: some View {
        Button("Quit KeepAwake") {
            NSApplication.shared.terminate(nil)
        }
        .frame(maxWidth: .infinity)
        .controlSize(.regular)
        .buttonStyle(.borderedProminent)
        .tint(.gray.opacity(0.45))
    }

    private var statusTint: Color {
        controller.isRunning ? .green : .gray
    }

    private var displayedArguments: [String] {
        controller.isRunning ? controller.activeArguments : controller.flags.arguments
    }

    private var canToggle: Bool {
        controller.isRunning || controller.flags.hasSelectedFlags
    }

    private var actionTint: Color {
        if controller.isRunning { return .orange }
        return controller.flags.hasSelectedFlags ? .green : .gray
    }

    private var actionIconName: String {
        if controller.isRunning { return "stop.circle.fill" }
        return controller.flags.hasSelectedFlags ? "play.circle.fill" : "checklist"
    }

    private var actionTitle: String {
        if controller.isRunning { return "Turn KeepAwake Off" }
        return controller.flags.hasSelectedFlags ? "Turn KeepAwake On" : "Select a Flag"
    }

    private var actionSubtitle: String {
        if controller.isRunning { return "Allow your Mac to sleep again" }
        return controller.flags.hasSelectedFlags ? "Prevent your Mac from sleeping" : "Choose at least one option above"
    }

    private var controlStatusText: String {
        if controller.isRunning { return "Flags locked while running" }
        return controller.flags.hasSelectedFlags ? "Flags can be changed before starting" : "Select at least one flag to start"
    }

    @ViewBuilder
    private func flagToggle(title: String, subtitle: String, flag: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(flag)
                    .font(.caption.monospaced().weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.14), in: Capsule())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .toggleStyle(RightCheckToggleStyle(isLocked: controller.isRunning))
        .opacity(controller.isRunning ? 0.74 : 1)
    }

    private func flagChipWrap(arguments: [String]) -> some View {
        HStack(spacing: 8) {
            ForEach(arguments, id: \.self) { argument in
                Text(argument)
                    .font(.caption.monospaced().weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(Color.primary.opacity(0.08), in: Capsule())
                    .foregroundStyle(.primary)
            }
            Spacer(minLength: 0)
        }
    }
}

struct RightCheckToggleStyle: ToggleStyle {
    let isLocked: Bool

    func makeBody(configuration: Configuration) -> some View {
        Button {
            guard !isLocked else { return }
            configuration.isOn.toggle()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                configuration.label
                Spacer()
                Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(configuration.isOn ? .green : .secondary.opacity(0.7))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(configuration.isOn ? Color.green.opacity(0.14) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(configuration.isOn ? Color.green.opacity(0.35) : Color.primary.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

@main
struct KeepAwakeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = CaffeinateController()
    @StateObject private var loginItemController = LoginItemController()

    var body: some Scene {
        MenuBarExtra(controller.isRunning ? "KeepAwake ON" : "KeepAwake OFF", systemImage: controller.isRunning ? "bolt.fill" : "moon.zzz.fill") {
            MenuBarView(controller: controller, loginItemController: loginItemController)
        }
        .menuBarExtraStyle(.window)
    }
}
