//
//  FirstPassApp.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 14/04/2026.
//

import SwiftUI

@main
struct FirstPassApp: App {
    // Shared state for folder tree and photo grid management
    @State private var folderTreeVM = FolderTreeVM()
    @State private var photoGridVM = PhotoGridVM()
    // Theme preference: follow system by default, or forced light/dark
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRaw = AppearanceMode.system.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(folderTreeVM)
                .environment(photoGridVM)
                .frame(minWidth: 1280, minHeight: 720)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        .windowResizability(WindowResizability.automatic)
        .defaultSize(width: 1280, height: 720)

        Settings {
            SettingsView()
                .preferredColorScheme(appearanceMode.colorScheme)
        }
    }
}
