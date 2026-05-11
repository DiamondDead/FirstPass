//
//  ContentView.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 14/04/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(FolderTreeVM.self) private var folderTreeVM
    @Environment(PhotoGridVM.self) private var photoGridVM
    
    var body: some View {
        NavigationSplitView {
            // Sidebar gauche
            LeftSideBar(viewModel: folderTreeVM)
                .navigationSplitViewColumnWidth(
                            min: 200, ideal: 250, max: 300)
        } detail: {
            // Contenu principal - Photo grid
            PhotoGridView(viewModel: photoGridVM)
                .frame(minWidth: 700)
        }
        .onAppear {
            // Pass PhotoGridVM to FolderTreeVM for photo loading on folder selection
            folderTreeVM.photoGridVM = photoGridVM
        }
    }
}

#Preview {
    let folderVM = FolderTreeVM()
    let photoVM = PhotoGridVM()
    return ContentView()
        .environment(folderVM)
        .environment(photoVM)
}
