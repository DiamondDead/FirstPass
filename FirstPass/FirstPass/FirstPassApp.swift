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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(folderTreeVM)
                .environment(photoGridVM)
                .frame(minWidth: 1280, minHeight: 720)
        }
        .windowResizability(WindowResizability.automatic)
        .defaultSize(width: 1280, height: 720)
    }
}
