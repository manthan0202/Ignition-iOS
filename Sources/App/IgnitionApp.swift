import SwiftUI
import UIKit

@main
struct IgnitionApp: App {
    @StateObject private var model = AppModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            MainTabs(model: model)
                .preferredColorScheme(.light)
                .task {
                    await model.refresh()
                    await model.consumePendingNotificationAction()
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await model.refresh()
                            await model.consumePendingNotificationAction()
                        }
                    }
                }
                .onOpenURL { url in
                    if url.scheme == "ignition" {
                        Task {
                            await model.refresh()
                            if model.session != nil { model.showFocus = true }
                        }
                    }
                }
        }
    }
}

/// A compact, consistent two-tab bar. Avoids iOS version-specific floating
/// tab chrome and the large empty area beneath the Now sheet.
struct MainTabs: View {
    @ObservedObject var model: AppModel
    @State private var selection = 0

    var body: some View {
        ZStack {
            if selection == 0 {
                NowView(model: model).transition(.opacity)
            } else {
                PlanView(model: model).transition(.opacity)
            }
        }
        .animation(IgnitionMotion.quick, value: selection)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            HStack(spacing: 0) {
                tabButton("Now", icon: "house.fill", value: 0)
                tabButton("Plan", icon: "calendar", value: 1)
            }
            .padding(.horizontal, 35)
            .frame(height: 58)
            .frame(maxWidth: .infinity)
            .background(IgnitionDesign.raised)
            .overlay(alignment: .top) { IgnitionDesign.outline.opacity(0.65).frame(height: 1) }
        }
        .fullScreenCover(isPresented: $model.showFocus,
                         onDismiss: { model.presentReviewAfterFocusDismissal() }) {
            FocusView(model: model)
        }
        .sheet(isPresented: $model.showClose) {
            CloseView(model: model).presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $model.showStartSmall) {
            StartSmallView(model: model).presentationDetents([.medium])
        }
        .sheet(isPresented: $model.settingsOpen) { SettingsView(model: model) }
        .alert("Calendar changed elsewhere", isPresented: Binding(
            get: { model.calendarConflict != nil },
            set: { if !$0 { model.calendarConflict = nil } })) {
            Button("Use Google version") { model.resolveCalendarConflict(useGoogle: true) }
            Button("Keep Ignition version") { model.resolveCalendarConflict(useGoogle: false) }
            Button("Decide later", role: .cancel) { model.calendarConflict = nil }
        } message: { Text(model.conflictDescription) }
        .alert("Ignition", isPresented: Binding(get: { model.errorMessage != nil },
                                                set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }

    private func tabButton(_ title: String, icon: String, value: Int) -> some View {
        Button {
            guard selection != value else { return }
            IgnitionFeedback.selection()
            selection = value
        } label: {
            VStack(spacing: 3) {
                Image(systemName: icon).font(.system(size: 19, weight: .semibold))
                Text(title).font(.system(size: 11, weight: selection == value ? .semibold : .medium))
            }
            .foregroundStyle(selection == value ? IgnitionStyle.blue : IgnitionDesign.muted)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == value ? .isSelected : [])
    }
}

enum IgnitionStyle {
    // Compatibility aliases. Legacy screens now read the SAME semantic palette.
    static let blue = IgnitionDesign.action
    static let navy = IgnitionDesign.ink
    static let pale = IgnitionDesign.canvas
}

struct IgnitionPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.045 : 0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct PrimaryPill: View {
    let text: String
    var busy: Bool = false
    let action: () -> Void
    var body: some View {
        Button {
            guard !busy else { return }
            IgnitionFeedback.action()
            action()
        } label: {
            HStack(spacing: 9) {
                if busy { ProgressView().tint(.white) }
                Text(busy ? "STARTING FOCUS…" : text)
            }
            .font(.system(size: 16, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 12)
            .background(IgnitionStyle.blue, in: Capsule())
        }
        .buttonStyle(IgnitionPressStyle())
        .disabled(busy)
        .accessibilityIdentifier("ignition.lockIn")
    }
}


// MARK: - Ignition design and interaction foundation
// A single language used by Now, Plan and Focus. Widget extensions keep an
// independent minimal palette because ActivityKit extensions are separate targets.
enum IgnitionDesign {
    static let ink = Color(red: 0.070, green: 0.145, blue: 0.295)
    static let action = Color(red: 0.216, green: 0.410, blue: 0.895)
    static let muted = Color(red: 0.42, green: 0.49, blue: 0.61)
    static let canvas = Color(red: 0.946, green: 0.956, blue: 0.973)
    static let raised = Color(red: 0.986, green: 0.991, blue: 1.000)
    static let outline = Color(red: 0.85, green: 0.89, blue: 0.94)
    static let teal = Color(red: 0.26, green: 0.77, blue: 0.76)
    static let focusTop = Color(red: 0.049, green: 0.085, blue: 0.188)
    static let focusBottom = Color(red: 0.110, green: 0.185, blue: 0.365)
    static let cardRadius: CGFloat = 18
    static let sheetRadius: CGFloat = 28
    static let fieldHeight: CGFloat = 46

    static func screenTitle() -> Font { .system(size: 27, weight: .bold, design: .rounded) }
    static func sectionTitle() -> Font { .system(size: 20, weight: .semibold) }
    static func taskTitle() -> Font { .system(size: 16, weight: .semibold) }
    static func bodyText() -> Font { .system(size: 14, weight: .regular) }
    static func metadata() -> Font { .system(size: 12, weight: .medium) }
    static func microLabel() -> Font { .system(size: 11, weight: .semibold) }
}

enum IgnitionMotion {
    static let press = Animation.easeOut(duration: 0.12)
    static let quick = Animation.easeOut(duration: 0.18)
    static let settle = Animation.spring(response: 0.34, dampingFraction: 0.86)
    static let sheet = Animation.interactiveSpring(response: 0.38, dampingFraction: 0.90)
}

enum IgnitionFeedback {
    private static var enabled: Bool {
        UserDefaults.standard.object(forKey: "ignition.haptics.enabled") as? Bool ?? true
    }
    static func selection() {
        guard enabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }
    static func lift() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.65)
    }
    static func action() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred(intensity: 0.85)
    }
    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

struct IgnitionSurface: ViewModifier {
    var corner: CGFloat = IgnitionDesign.cardRadius
    var elevated: Bool = false
    func body(content: Content) -> some View {
        content
            .background(IgnitionDesign.raised, in: RoundedRectangle(cornerRadius: corner, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(IgnitionDesign.outline.opacity(0.50), lineWidth: 0.8))
            .shadow(color: IgnitionDesign.ink.opacity(elevated ? 0.08 : 0.025),
                    radius: elevated ? 12 : 3, y: elevated ? 5 : 1)
    }
}

extension View {
    func ignitionSurface(corner: CGFloat = IgnitionDesign.cardRadius,
                         elevated: Bool = false) -> some View {
        modifier(IgnitionSurface(corner: corner, elevated: elevated))
    }
}
