import AuthenticationServices
import CryptoKit
import Foundation
import Security
import UIKit

/// Optional DIRECT Google Calendar connection. The user must create an iOS
/// OAuth client in Google Cloud and configure its client ID/reversed callback
/// scheme in the app Info.plist. No client secret is embedded in the app.
/// Google calendars already enabled in iOS Calendar should normally be used
/// through EventKit instead; don't connect the same calendar twice.
@MainActor
final class GoogleCalendarService: NSObject, ObservableObject, ASWebAuthenticationPresentationContextProviding {
    struct Credential: Codable {
        var accessToken: String
        var refreshToken: String
        var expiresAt: Date
    }
    struct CalendarInfo: Decodable, Identifiable {
        let id: String
        let summary: String?
        let accessRole: String?
    }
    struct CalendarList: Decodable { let items: [CalendarInfo]?; let nextPageToken: String? }
    struct GoogleMoment: Codable { let dateTime: String?; let date: String? }
    struct GoogleEvent: Codable {
        let id: String
        let summary: String?
        let description: String?
        let status: String?
        let etag: String?
        let iCalUID: String?
        let start: GoogleMoment?
        let end: GoogleMoment?
    }
    struct EventsPage: Codable {
        let items: [GoogleEvent]?
        let nextPageToken: String?
        let nextSyncToken: String?
    }
    struct CalendarDelta {
        var calendarID: String
        var upserts: [WorkItem]
        var removedIDs: [String]
        var tokenExpired: Bool
        var nextSyncToken: String? = nil
    }
    struct TokenResponse: Decodable {
        let access_token: String
        let refresh_token: String?
        let expires_in: Int
    }
    enum GoogleError: LocalizedError {
        case notConfigured, notConnected, invalidResponse, server(Int), conflict, oauth(String)
        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Google OAuth is not configured. Add an iOS OAuth client ID and its reversed URL scheme in the project's Info.plist."
            case .notConnected: return "Connect Google Calendar before synchronizing."
            case .invalidResponse: return "Google returned an unexpected response."
            case .server(let status): return "Google Calendar returned HTTP \(status). Your local data is retained."
            case .conflict: return "This event changed in Google Calendar. Review both versions before overwriting."
            case .oauth(let reason): return "Google sign-in failed: \(reason)"
            }
        }
    }
    @Published private(set) var connected = false
    @Published private(set) var statusText = "Not connected"
    @Published private(set) var lastSync: Date?
    @Published private(set) var calendars: [CalendarInfo] = []
    private var webAuthentication: ASWebAuthenticationSession?
    private var token: Credential?
    private var syncTokens: [String: String] = [:]
    private let credentialService = "Ignition.GoogleCalendar.OAuth"
    private let tokenDefaultsKey = "IgnitionGoogleSyncTokensV1"

    override init() {
        super.init()
        token = readCredential()
        connected = token != nil
        statusText = connected ? "Connected (direct Google API)" : "Not connected"
        syncTokens = UserDefaults.standard.dictionary(forKey: tokenDefaultsKey) as? [String: String] ?? [:]
    }
    private var clientID: String {
        Bundle.main.object(forInfoDictionaryKey: "IgnitionGoogleOAuthClientID") as? String ?? ""
    }
    private var callbackScheme: String {
        let prefix = clientID.replacingOccurrences(of: ".apps.googleusercontent.com", with: "")
        return "com.googleusercontent.apps.\(prefix)"
    }
    var configured: Bool {
        guard clientID.hasSuffix(".apps.googleusercontent.com"), clientID.count > 35 else { return false }
        let types = Bundle.main.object(forInfoDictionaryKey: "CFBundleURLTypes") as? [[String: Any]] ?? []
        return types.contains { ($0["CFBundleURLSchemes"] as? [String] ?? []).contains(callbackScheme) }
    }
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows).first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
    private func secureVerifier() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "") + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }
    func connect() async throws {
        guard configured else { throw GoogleError.notConfigured }
        let verifier = secureVerifier()
        let digest = SHA256.hash(data: Data(verifier.utf8))
        let challenge = Data(digest).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
        let state = UUID().uuidString
        let redirect = "\(callbackScheme):/oauth2redirect"
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirect),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: "https://www.googleapis.com/auth/calendar"),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state)
        ]
        let callbackURL = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<URL, Error>) in
            let session = ASWebAuthenticationSession(url: components.url!, callbackURLScheme: callbackScheme) { url, error in
                if let url { continuation.resume(returning: url) }
                else { continuation.resume(throwing: error ?? GoogleError.oauth("No callback")) }
            }
            session.presentationContextProvider = self
            webAuthentication = session
            if !session.start() { continuation.resume(throwing: GoogleError.oauth("Could not open secure login")) }
        }
        webAuthentication = nil
        let values = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard values.first(where: { $0.name == "state" })?.value == state,
              let code = values.first(where: { $0.name == "code" })?.value else {
            throw GoogleError.oauth("Callback state mismatch or missing authorization code")
        }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "code", value: code),
            URLQueryItem(name: "code_verifier", value: verifier),
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "redirect_uri", value: redirect)
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleError.invalidResponse }
        guard http.statusCode == 200 else { throw GoogleError.server(http.statusCode) }
        let grant = try JSONDecoder().decode(TokenResponse.self, from: data)
        let credential = Credential(accessToken: grant.access_token, refreshToken: grant.refresh_token ?? "",
                                    expiresAt: Date().addingTimeInterval(TimeInterval(grant.expires_in)))
        saveCredential(credential)
        connected = true
        statusText = "Connected (direct Google API)"
    }
    func disconnect() {
        token = nil
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: credentialService]
        SecItemDelete(query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: tokenDefaultsKey)
        syncTokens = [:]
        calendars = []
        connected = false
        statusText = "Disconnected"
    }
    private func readCredential() -> Credential? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: credentialService,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(Credential.self, from: data)
    }
    private func saveCredential(_ value: Credential) {
        token = value
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: credentialService]
        SecItemDelete(query as CFDictionary)
        guard let data = try? JSONEncoder().encode(value) else { return }
        var payload = query
        payload[kSecValueData as String] = data
        payload[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(payload as CFDictionary, nil)
    }
    private func authorizedToken() async throws -> String {
        guard var current = token else { throw GoogleError.notConnected }
        if current.expiresAt > Date().addingTimeInterval(120) { return current.accessToken }
        guard !current.refreshToken.isEmpty else { throw GoogleError.notConnected }
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [URLQueryItem(name: "client_id", value: clientID),
                           URLQueryItem(name: "refresh_token", value: current.refreshToken),
                           URLQueryItem(name: "grant_type", value: "refresh_token")]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleError.invalidResponse }
        guard http.statusCode == 200 else { throw GoogleError.server(http.statusCode) }
        let refreshed = try JSONDecoder().decode(TokenResponse.self, from: data)
        current.accessToken = refreshed.access_token
        current.expiresAt = Date().addingTimeInterval(TimeInterval(refreshed.expires_in))
        if let replacement = refreshed.refresh_token { current.refreshToken = replacement }
        saveCredential(current)
        return current.accessToken
    }
    private func escaped(_ id: String) -> String {
        id.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?"))) ?? id
    }
    private func execute(_ endpoint: String, method: String = "GET", body: Data? = nil,
                         etag: String? = nil, allowGone: Bool = false) async throws -> (Data, Int) {
        let accessToken = try await authorizedToken()
        var request = URLRequest(url: URL(string: "https://www.googleapis.com/calendar/v3/" + endpoint)!)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        if let body { request.httpBody = body; request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let etag { request.setValue(etag, forHTTPHeaderField: "If-Match") }
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw GoogleError.invalidResponse }
        if http.statusCode == 412 { throw GoogleError.conflict }
        if allowGone && http.statusCode == 410 { return (data, 410) }
        guard (200..<300).contains(http.statusCode) else { throw GoogleError.server(http.statusCode) }
        return (data, http.statusCode)
    }
    func listCalendars() async throws -> [CalendarInfo] {
        var all: [CalendarInfo] = []
        var nextPage: String?
        repeat {
            var query = URLComponents()
            var parameters = [URLQueryItem(name: "maxResults", value: "250")]
            if let nextPage { parameters.append(URLQueryItem(name: "pageToken", value: nextPage)) }
            query.queryItems = parameters
            let (data, _) = try await execute("users/me/calendarList?" + (query.percentEncodedQuery ?? ""))
            let response = try JSONDecoder().decode(CalendarList.self, from: data)
            all.append(contentsOf: response.items ?? [])
            nextPage = response.nextPageToken
        } while nextPage != nil
        calendars = all
        return calendars
    }
    private func googleDate(_ moment: GoogleMoment?) -> Date? {
        // All-day events contain a YYYY-MM-DD *calendar day*, not midnight
        // UTC. Convert using the device calendar so they do not appear on
        // the previous afternoon in western time zones.
        if let localDay = moment?.date {
            return CalendarSyncRules.allDayDate(localDay)
        }
        guard let value = moment?.dateTime else { return nil }
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = f.date(from: value) { return date }
        f.formatOptions = [.withInternetDateTime]
        if let date = f.date(from: value) { return date }
        f.formatOptions = [.withFullDate]
        return f.date(from: value)
    }
    private func makeWorkItem(_ event: GoogleEvent, calendarID: String, canEdit: Bool) -> WorkItem? {
        guard let start = googleDate(event.start), let end = googleDate(event.end),
              event.status != "cancelled" else { return nil }
        var item = WorkItem(title: event.summary ?? "Untitled event", notes: event.description ?? "",
                            scheduledStart: start,
                            durationMinutes: max(5, Int(end.timeIntervalSince(start) / 60)),
                            tint: .purple, isFixed: !canEdit)
        item.externalProvider = "google"
        item.externalCalendarID = calendarID
        item.externalEventID = event.id
        item.externalETag = event.etag
        item.externalUniversalID = event.iCalUID
        item.isAllDay = event.start?.date != nil
        item.syncState = "synced"
        return item
    }
    /// Incremental per-calendar pagination. An invalid token triggers a full
    /// refresh of that calendar only; local tasks and session history survive.
    func fetchChanges(calendar: CalendarInfo) async throws -> CalendarDelta {
        var previous = syncTokens[calendar.id]
        var expired = false
        for attempt in 0..<2 {
            var output: [WorkItem] = []
            var deleted: [String] = []
            var page: String?
            var finalToken: String?
            var shouldRetry = false
            repeat {
                var params = URLComponents()
                var queries = [URLQueryItem(name: "maxResults", value: "1000"),
                               URLQueryItem(name: "showDeleted", value: "true"),
                               URLQueryItem(name: "singleEvents", value: "false")]
                if let previous { queries.append(URLQueryItem(name: "syncToken", value: previous)) }
                if let page { queries.append(URLQueryItem(name: "pageToken", value: page)) }
                params.queryItems = queries
                let path = "calendars/\(escaped(calendar.id))/events?" + (params.percentEncodedQuery ?? "")
                let (data, status) = try await execute(path, allowGone: true)
                if status == 410 {
                    syncTokens.removeValue(forKey: calendar.id)
                    UserDefaults.standard.set(syncTokens, forKey: tokenDefaultsKey)
                    previous = nil
                    expired = true
                    shouldRetry = true
                    break
                }
                let result = try JSONDecoder().decode(EventsPage.self, from: data)
                for event in result.items ?? [] {
                    if event.status == "cancelled" { deleted.append(event.id) }
                    else if let item = makeWorkItem(event, calendarID: calendar.id,
                                                   canEdit: calendar.accessRole == "owner" || calendar.accessRole == "writer") {
                        output.append(item)
                    }
                }
                page = result.nextPageToken
                finalToken = result.nextSyncToken ?? finalToken
            } while page != nil
            if shouldRetry && attempt == 0 { continue }
            // Do not advance syncToken before the repository durably persists
            // the upserts and deletions. A crash in between would lose events.
            return CalendarDelta(calendarID: calendar.id, upserts: output,
                                 removedIDs: deleted, tokenExpired: expired,
                                 nextSyncToken: finalToken)
        }
        throw GoogleError.invalidResponse
    }
    /// Call ONLY after WorkRepository.applyGoogle(delta) has returned; that
    /// method writes the updated data snapshot atomically to disk.
    func commit(_ delta: CalendarDelta) {
        if let token = delta.nextSyncToken { syncTokens[delta.calendarID] = token }
        UserDefaults.standard.set(syncTokens, forKey: tokenDefaultsKey)
        lastSync = Date()
        statusText = "Synced \(lastSync!.formatted(date: .omitted, time: .shortened))"
    }

    func fetchCurrent(calendarID: String, eventID: String) async throws -> WorkItem {
        let (data, _) = try await execute("calendars/\(escaped(calendarID))/events/\(escaped(eventID))")
        let event = try JSONDecoder().decode(GoogleEvent.self, from: data)
        guard let item = makeWorkItem(event, calendarID: calendarID, canEdit: true) else {
            throw GoogleError.invalidResponse
        }
        return item
    }

    private func eventBody(for task: WorkItem) throws -> Data {
        guard let start = task.scheduledStart else { throw GoogleError.invalidResponse }
        let end = start.addingTimeInterval(TimeInterval(max(5, task.durationMinutes) * 60))
        var payload: [String: Any] = ["summary": task.title, "description": task.notes]
        if task.isAllDay == true {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"
            payload["start"] = ["date": formatter.string(from: start)]
            payload["end"] = ["date": formatter.string(from: Calendar.current.date(byAdding: .day, value: 1, to: start) ?? end)]
        } else {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime]
            payload["start"] = ["dateTime": formatter.string(from: start)]
            payload["end"] = ["dateTime": formatter.string(from: end)]
        }
        return try JSONSerialization.data(withJSONObject: payload)
    }

    /// The deterministic Google ID makes insert retries idempotent: if an
    /// earlier network response was lost, a 409 points to the SAME event,
    /// never another copy. Google accepts lower-case base32hex IDs.
    static func stableEventID(for taskID: UUID) -> String {
        CalendarSyncRules.stableGoogleEventID(taskID)
    }

    func save(task: WorkItem) async throws -> GoogleEvent {
        guard task.externalProvider == "google", let calendarID = task.externalCalendarID,
              task.scheduledStart != nil else { throw GoogleError.invalidResponse }
        let body = try eventBody(for: task)
        if let existingID = task.externalEventID {
            guard let etag = task.externalETag else { throw GoogleError.conflict }
            let (data, _) = try await execute("calendars/\(escaped(calendarID))/events/\(escaped(existingID))",
                                               method: "PATCH", body: body, etag: etag)
            return try JSONDecoder().decode(GoogleEvent.self, from: data)
        }
        var object = try JSONSerialization.jsonObject(with: body) as? [String: Any] ?? [:]
        let chosenID = Self.stableEventID(for: task.id)
        object["id"] = chosenID
        let postBody = try JSONSerialization.data(withJSONObject: object)
        do {
            let (data, _) = try await execute("calendars/\(escaped(calendarID))/events",
                                               method: "POST", body: postBody)
            return try JSONDecoder().decode(GoogleEvent.self, from: data)
        } catch GoogleError.server(409) {
            // A previous insert may have succeeded despite a dropped response.
            // Fetch it instead of making a second calendar event.
            let (data, _) = try await execute("calendars/\(escaped(calendarID))/events/\(escaped(chosenID))")
            return try JSONDecoder().decode(GoogleEvent.self, from: data)
        }
    }

    func delete(task: WorkItem) async throws {
        guard task.externalProvider == "google", let calendarID = task.externalCalendarID,
              let eventID = task.externalEventID, let etag = task.externalETag else {
            throw GoogleError.invalidResponse
        }
        do {
            _ = try await execute("calendars/\(escaped(calendarID))/events/\(escaped(eventID))",
                                  method: "DELETE", etag: etag)
        } catch GoogleError.server(404) {
            // Delete is idempotent: the event no longer exists remotely.
            return
        }
    }
}
