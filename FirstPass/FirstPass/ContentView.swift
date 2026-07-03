//
//  ContentView.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 14/04/2026.
//

import SwiftUI
import AppKit

// MARK: - Color Constants

extension Color {
    /// Dynamic color that resolves against the effective appearance of the
    /// view hierarchy — so the viewer can stay dark (via a forced dark
    /// colorScheme) while the rest of the app follows the selected theme.
    init(light: NSColor, dark: NSColor) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
        })
    }

    // Main surfaces
    static let fpBackground = Color(
        light: NSColor(srgbRed: 0.92, green: 0.92, blue: 0.93, alpha: 1),
        dark: NSColor(srgbRed: 0.08, green: 0.08, blue: 0.09, alpha: 1) // #141417
    )
    static let fpContent = Color(
        light: NSColor(srgbRed: 0.97, green: 0.97, blue: 0.975, alpha: 1),
        dark: NSColor(srgbRed: 0.14, green: 0.14, blue: 0.15, alpha: 1) // #242426
    )
    // Accent is identical in both themes
    static let fpAccent = Color(red: 1.0, green: 0.624, blue: 0.039) // #ff9f0a

    // Text
    static let fpText = Color(
        light: NSColor(srgbRed: 0.13, green: 0.13, blue: 0.14, alpha: 1),
        dark: NSColor(srgbRed: 0.92, green: 0.92, blue: 0.92, alpha: 1)
    )
    static let fpTextSecondary = Color(
        light: NSColor(srgbRed: 0.44, green: 0.44, blue: 0.46, alpha: 1),
        dark: NSColor(srgbRed: 0.55, green: 0.55, blue: 0.55, alpha: 1)
    )

    // Decorations (hairlines, chips, insets, floating panels)
    static let fpBorder = Color(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.10),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.07)
    )
    static let fpChipBackground = Color(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.05),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.04)
    )
    static let fpControlActive = Color(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1),
        dark: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.12)
    )
    static let fpInset = Color(
        light: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.07),
        dark: NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 0.30)
    )
    static let fpPanel = Color(
        light: NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.92),
        dark: NSColor(srgbRed: 0.11, green: 0.11, blue: 0.118, alpha: 0.85)
    )
}

struct ContentView: View {
    @Environment(FolderTreeVM.self) private var folderTreeVM
    @Environment(PhotoGridVM.self) private var photoGridVM
    @State private var sidebarVisible = true
    
    var body: some View {
        HSplitView {
            if sidebarVisible {
                // Sidebar gauche
                LeftSideBar(viewModel: folderTreeVM)
                    .frame(minWidth: 200, maxWidth: 300)
            }
            
            // Contenu principal - Photo grid
            VStack(spacing: 0) {
                // Titlebar
                TitleBar(
                    folderPath: folderPath,
                    sidebarVisible: sidebarVisible,
                    onToggleSidebar: { sidebarVisible.toggle() }
                )
                
                // Photo grid
                PhotoGridView(viewModel: photoGridVM, folderTreeVM: folderTreeVM)
                    .frame(minWidth: 700)
            }
        }
        .background(Color.fpBackground)
        .onAppear {
            // Pass PhotoGridVM to FolderTreeVM for photo loading on folder selection
            folderTreeVM.photoGridVM = photoGridVM
        }
    }
    
    // MARK: - Computed Properties
    
    private var folderPath: [String] {
        guard let selectedFolder = folderTreeVM.selectedFolder else {
            return []
        }
        
        // Build path from root to selected folder
        var path: [String] = []
        var current: FolderItem? = selectedFolder
        
        // Simple path for now - just the folder name
        // TODO: Build full path from root to selected folder
        path.append(selectedFolder.name)
        
        return path
    }
}

#Preview {
    let folderVM = FolderTreeVM()
    let photoVM = PhotoGridVM()
    return ContentView()
        .environment(folderVM)
        .environment(photoVM)
}
