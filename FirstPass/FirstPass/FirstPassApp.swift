//
//  FirstPassApp.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 14/04/2026.
//

import SwiftUI

@main
struct FirstPassApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1280, minHeight: 720)
        }
        .windowResizability(WindowResizability.automatic)
        .defaultSize(width: 1280, height: 720)
    }
}
