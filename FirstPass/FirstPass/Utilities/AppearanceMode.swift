//
//  AppearanceMode.swift
//  FirstPass
//
//  User-selectable appearance: follow the system (default) or force
//  light / dark. Persisted in UserDefaults via @AppStorage.
//

import SwiftUI

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearanceMode"

    var id: String { rawValue }

    /// nil lets the window follow the system appearance
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    var label: String {
        switch self {
        case .system: return "Auto (système)"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }
}
