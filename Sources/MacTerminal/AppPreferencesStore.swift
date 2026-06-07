import Foundation
import MacTerminalCore

extension Notification.Name {
    static let macTerminalPreferencesDidChange = Notification.Name("MacTerminal.PreferencesDidChange")
}

final class AppPreferencesStore {
    static let shared = AppPreferencesStore()

    private let key = "MacTerminal.Preferences"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var preferences: AppPreferences {
        get {
            guard let data = defaults.data(forKey: key),
                  let decoded = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
                return AppPreferences.default()
            }
            return decoded.normalized()
        }
        set {
            let normalized = newValue.normalized()
            guard let data = try? JSONEncoder().encode(normalized) else {
                return
            }
            defaults.set(data, forKey: key)
            NotificationCenter.default.post(name: .macTerminalPreferencesDidChange, object: normalized)
        }
    }

    var activeProfile: TerminalProfile {
        preferences.activeProfile
    }

    func saveActiveProfile(_ profile: TerminalProfile) {
        var preferences = preferences
        let normalizedProfile = profile.normalized()
        if let index = preferences.profiles.firstIndex(where: { $0.id == profile.id }) {
            preferences.profiles[index] = normalizedProfile
        } else {
            preferences.profiles.append(normalizedProfile)
        }
        preferences.activeProfileID = normalizedProfile.id
        self.preferences = preferences
    }
}
