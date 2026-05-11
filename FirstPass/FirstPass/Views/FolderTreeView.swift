//
//  FolderTreeView.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import SwiftUI

/// Recursive view for displaying folder tree structure
struct FolderTreeView: View {
    let folder: FolderItem
    let viewModel: FolderTreeVM
    let depth: Int
    
    init(folder: FolderItem, viewModel: FolderTreeVM, depth: Int = 0) {
        self.folder = folder
        self.viewModel = viewModel
        self.depth = depth
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Folder row
            Button(action: {
                if !folder.subfolders.isEmpty {
                    viewModel.toggleExpansion(folder)
                }
                viewModel.selectFolder(folder)
            }) {
                HStack(spacing: 6) {
                    // Chevron (only show if there are subfolders)
                    if !folder.subfolders.isEmpty {
                        Image(systemName: folder.isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .frame(width: 12)
                    } else {
                        // Spacer to maintain alignment
                        Spacer()
                            .frame(width: 12)
                    }
                    
                    // Folder icon
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.blue)
                    
                    // Folder name
                    Text(folder.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundStyle(viewModel.selectedFolder?.id == folder.id ? .white : .primary)
                    
                    Spacer()
                    
                    // Photo count
                    if folder.photoCount > 0 {
                        Text("\(folder.photoCount)")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(viewModel.selectedFolder?.id == folder.id ? Color.accentColor : Color.clear)
            .cornerRadius(4)
            
            // Subfolders (if expanded)
            if folder.isExpanded && !folder.subfolders.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(folder.subfolders) { subfolder in
                        FolderTreeView(folder: subfolder, viewModel: viewModel, depth: depth + 1)
                            .padding(.leading, 16)
                    }
                }
            }
        }
    }
}

#Preview {
    let vm = FolderTreeVM()
    let rootFolder = FolderItem(url: URL(fileURLWithPath: "/test"), name: "Root")
    let subfolder1 = FolderItem(url: URL(fileURLWithPath: "/test/sub1"), name: "Subfolder 1")
    subfolder1.photoCount = 15
    let subfolder2 = FolderItem(url: URL(fileURLWithPath: "/test/sub2"), name: "Subfolder 2")
    subfolder2.photoCount = 8
    rootFolder.subfolders = [subfolder1, subfolder2]
    rootFolder.photoCount = 23
    
    return FolderTreeView(folder: rootFolder, viewModel: vm)
        .frame(width: 250)
}
