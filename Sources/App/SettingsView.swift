import SwiftUI
import FamilyControls
import ActivityKit

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var protection: ProtectionService
    @ObservedObject private var audio: FocusAudioPlayer
    @ObservedObject private var google: GoogleCalendarService
    init(model: AppModel) {
        self.model = model
        _protection = ObservedObject(wrappedValue: model.protection)
        _audio = ObservedObject(wrappedValue: model.audio)
        _google = ObservedObject(wrappedValue: model.google)
    }
    @Environment(\.dismiss) private var dismiss
    @State private var showPicker = false
    @State private var showGoogleDisconnectOptions = false
    @State private var enabledNotifications = false
    @AppStorage("rescueEnabled") private var rescueEnabled = false
    @AppStorage("ignition.haptics.enabled") private var hapticsEnabled = true
    var body: some View {
        NavigationStack {
            Form {
                Section("Protection") {
                    Text(protection.status.title).foregroundStyle(.secondary)
                    #if IGNITION_PREVIEW
                    Text("Preview: Screen Time shielding is deliberately disabled. The Lock Screen and Dynamic Island Live Activity can still be tested on an iPhone.")
                        .font(.footnote).foregroundStyle(.secondary)
                    #else
                    Button("Authorize Screen Time") { Task { _ = await model.protection.authorize() } }
                    Button("Choose distracting apps and websites") { showPicker = true }
                    Button("Release Ignition shields now", role: .destructive) { model.protection.deactivate() }
                    #endif
                    Text("App shielding is opt-in. iOS notification alerts are separate from Screen Time restrictions; Ignition does not promise to mute all system notifications. Without permission or a selection, Ignition runs as a timer only. Sessions under 16 minutes are timer-only because safe automatic unblocking cannot be guaranteed with Apple's 15-minute monitoring minimum. Ignition shields selected apps; it cannot force-quit them.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Live Activity · Lock Screen and Dynamic Island") {
                    HStack {
                        Text("System permission")
                        Spacer()
                        Text(ActivityAuthorizationInfo().areActivitiesEnabled ? "Enabled" : "Disabled")
                            .foregroundStyle(ActivityAuthorizationInfo().areActivitiesEnabled ? .green : .orange)
                    }
                    Text(model.liveActivityStatus)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text("A running session should appear on the Lock Screen and, on supported iPhones, Dynamic Island. Enable Live Activities in iPhone Settings for this app if needed. Preview includes a separate Live Activity extension; Screen Time blocking is not included.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section("Calendar connections") {
                    Button("Connect or refresh Apple Calendar") {
                        Task { await model.importCalendar(for: model.selectedDate) }
                    }
                    Text("Apple Calendar can also sync a Google account already enabled in iPhone Settings → Calendar. This is the recommended setup and prevents duplicate imports.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(model.calendarSyncStatus).font(.footnote).foregroundStyle(.secondary)
                    if google.configured {
                        if google.connected {
                            Text(google.statusText).font(.footnote).foregroundStyle(.secondary)
                            Button("Refresh Google Calendar") { Task { await model.refreshCalendars() } }
                            Button("Disconnect direct Google API", role: .destructive) {
                                showGoogleDisconnectOptions = true
                            }
                        } else {
                            Button("Connect Google Calendar directly (advanced)") {
                                Task {
                                    do { try await google.connect(); await model.refreshCalendars() }
                                    catch { model.errorMessage = error.localizedDescription }
                                }
                            }
                        }
                    } else {
                        Text("Direct Google API requires an OAuth client ID and URL callback scheme in Xcode. Without those credentials, Google calendars can still connect through iPhone Calendar.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("Experience") {
                    Toggle("Touch feedback", isOn: $hapticsEnabled)
                    Text("Subtle feedback for task pickup, scheduling, and entering focus. Respects your preference throughout the app.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("Timer") {
                    Picker("Default duration",selection:$model.defaultMinutes) {
                        ForEach([2,10,15,25,45,60],id:\.self) { m in Text("\(m) min").tag(m) }
                    }
                }
                Section("Alerts") {
                    Button("Enable focus notifications") {
                        Task { enabledNotifications = await model.notices.authorize() }
                    }
                    if enabledNotifications { Label("Authorized",systemImage:"checkmark.circle.fill") }
                    Toggle("Gentle missed-start Rescue",isOn:$rescueEnabled)
                    Text("Only for explicitly scheduled tasks, once per planned start. Requires notification permission.").font(.footnote).foregroundStyle(.secondary)
                }
                Section("Focus audio") {
                    Toggle("Play my chosen sound when focus starts", isOn: $audio.autoPlay)
                    Text("Your choice and volume are remembered. Sound pauses with focus and during breaks, then resumes with focus. Silence is always available.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Picker("Default focus sound",selection:Binding(get:{audio.selection},set:{model.audio.choosePreferredTrack($0, sessionActive: model.session?.phase == .active)})) {
                        ForEach(model.audio.tracks,id:\.self) { Text($0).tag($0) }
                    }
                    HStack { Text("Volume");Slider(value:Binding(get:{Double(audio.volume)},set:{model.audio.updateVolume(Float($0))}),in:0...1) }
                    Button("Stop playback") { model.audio.stop() }
                    if let error = audio.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.orange)
                    }
                }
                Section("Privacy") {
                    Text("Tasks and session history are stored on device. Voice transcripts are editable and are never automatically saved as calendar events.")
                        .font(.footnote)
                }
            }
            .scrollContentBackground(.hidden)
            .background(IgnitionDesign.canvas)
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") {dismiss()} } }
        }
        .confirmationDialog("Disconnect Google Calendar", isPresented: $showGoogleDisconnectOptions) {
            Button("Disconnect, keep cached events") { google.disconnect() }
            Button("Disconnect, remove Google event cache", role: .destructive) {
                model.work.clearGoogleImportedCache()
                google.disconnect()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Local Ignition tasks, focus blocks and session history are never deleted.")
        }
        .familyActivityPicker(isPresented: $showPicker, selection: $protection.selection)
        .onChange(of: rescueEnabled) { _, _ in
            // Disable must cancel reminders already queued for existing tasks.
            for task in model.work.items { model.notices.scheduleReminder(for: task) }
        }
    }
}
