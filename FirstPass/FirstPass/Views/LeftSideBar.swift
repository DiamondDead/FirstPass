//
//  LeftSideBar.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import SwiftUI

struct LeftSideBar: View {
    let viewModel: FolderTreeVM
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with open button
            VStack(alignment: .leading, spacing: 8) {
                Button(action: {
                    viewModel.openFolder()
                }) {
                    HStack {
                        Image(systemName: "folder.badge.plus")
                        Text("Ouvrir un dossier")
                    }
                    .font(.system(size: 13))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            
            Divider()
            
            // Folder tree
            if let errorMessage = viewModel.errorMessage {
                // Error state
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.red)
                    Text("Erreur")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else if let rootFolder = viewModel.rootFolder {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        FolderTreeView(folder: rootFolder, viewModel: viewModel)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            } else {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Aucun dossier ouvert")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    Text("Cliquez sur \"Ouvrir un dossier\" pour commencer")
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            }
        }
    }
}

#Preview {
    let vm = FolderTreeVM()
    return LeftSideBar(viewModel: vm)
        .frame(width: 250)
}
