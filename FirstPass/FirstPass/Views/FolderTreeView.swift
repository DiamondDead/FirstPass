//
//  FolderTreeView.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import SwiftUI
import UniformTypeIdentifiers

/// Recursive view for displaying folder tree structure
struct FolderTreeView: View {
    let folder: FolderItem
    let viewModel: FolderTreeVM
    let depth: Int
    
    // True while photos are being dragged over this folder row (for highlight)
    @State private var isDropTargeted = false
    
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
                            .foregroundStyle(Color.fpTextSecondary)
                            .frame(width: 12)
                    } else {
                        // Spacer to maintain alignment
                        Spacer()
                            .frame(width: 12)
                    }
                    
                    // Folder icon
                    Image(systemName: "folder.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(viewModel.selectedFolder?.id == folder.id ? Color.fpAccent : Color.fpTextSecondary)
                    
                    // Folder name
                    Text(folder.name)
                        .font(.system(size: 13))
                        .lineLimit(1)
                        .foregroundStyle(viewModel.selectedFolder?.id == folder.id ? Color.fpText : Color.fpTextSecondary)
                    
                    Spacer()
                    
                    // Photo count
                    if folder.photoCount > 0 {
                        Text("\(folder.photoCount)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(Color.fpTextSecondary)
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(viewModel.selectedFolder?.id == folder.id ? Color.black.opacity(0.11) : Color.clear)
            .cornerRadius(4)
            // Highlight the row while photos are dragged over it
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isDropTargeted ? Color.fpAccent : Color.clear, lineWidth: 1.5)
            )
            .background(isDropTargeted ? Color.fpAccent.opacity(0.12) : Color.clear)
            // Accept dropped photos and move them into this folder
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { _ in
                let dragged = viewModel.photoGridVM?.draggingPhotoURLs ?? []
                guard !dragged.isEmpty else {
                    debugPrint("[FolderTreeView] Drop on \(folder.name) but no dragged photos")
                    return false
                }
                debugPrint("[FolderTreeView] Dropping \(dragged.count) photo(s) onto \(folder.name)")
                viewModel.movePhotos(dragged, to: folder)
                viewModel.photoGridVM?.draggingPhotoURLs = []
                return true
            }
            
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
