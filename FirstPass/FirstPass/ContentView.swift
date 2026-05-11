//
//  ContentView.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 14/04/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(FolderTreeVM.self) private var folderTreeVM
    
    var body: some View {
        NavigationSplitView {
            // Sidebar gauche
            LeftSideBar(viewModel: folderTreeVM)
                .navigationSplitViewColumnWidth(
                            min: 200, ideal: 250, max: 300)
        } detail: {
            // Contenu principal
            Text("Bonjour")
                .frame(minWidth: 700)
        }
    }
}

#Preview {
    let vm = FolderTreeVM()
    return ContentView()
        .environment(vm)
}
