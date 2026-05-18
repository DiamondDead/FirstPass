//
//  ContentView.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 14/04/2026.
//

import SwiftUI

// MARK: - Color Constants

extension Color {
    static let fpBackground = Color(red: 0.08, green: 0.08, blue: 0.09) // #141417 (slightly lighter)
    static let fpContent = Color(red: 0.14, green: 0.14, blue: 0.15) // #242426 (slightly lighter)
    static let fpAccent = Color(red: 1.0, green: 0.624, blue: 0.039) // #ff9f0a
    static let fpText = Color(red: 0.92, green: 0.92, blue: 0.92) // rgba(255,255,255,0.92)
    static let fpTextSecondary = Color(red: 0.55, green: 0.55, blue: 0.55) // rgba(255,255,255,0.55)
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
                PhotoGridView(viewModel: photoGridVM)
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
