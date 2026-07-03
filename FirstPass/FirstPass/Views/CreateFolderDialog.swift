//
//  CreateFolderDialog.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 18/05/2026.
//

import SwiftUI
import AppKit

/// Dialog for creating a new folder with optional photo inclusion
struct CreateFolderDialog: View {
    @State private var folderName: String = ""
    @State private var includeSelectedPhotos: Bool = true
    let selectedPhotoCount: Int
    let onCreateFolder: (String, Bool) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Nouveau dossier")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.fpText)
            
            // Folder name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Nom du dossier")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.fpTextSecondary)
                
                ZStack(alignment: .leading) {
                    if folderName.isEmpty {
                        Text("Nom du dossier")
                            .foregroundStyle(Color.fpTextSecondary.opacity(0.5))
                            .padding(.horizontal, 12)
                    }
                    
                    TextField("", text: $folderName)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.fpInset)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.fpBorder, lineWidth: 0.5)
                        )
                        .foregroundStyle(Color.fpText)
                }
            }
            
            // Checkbox for including selected photos — only relevant when photos are selected
            if selectedPhotoCount > 0 {
                Toggle(isOn: $includeSelectedPhotos) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inclure les photos sélectionnées")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.fpText)
                        Text("\(selectedPhotoCount) photo\(selectedPhotoCount > 1 ? "s" : "")")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.fpTextSecondary)
                    }
                }
                .toggleStyle(.checkbox)
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Annuler") {
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.fpTextSecondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.fpChipBackground)
                .cornerRadius(6)
                
                Button("Créer") {
                    onCreateFolder(folderName, includeSelectedPhotos)
                    onDismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.fpText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.fpAccent)
                .cornerRadius(6)
                .disabled(folderName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(folderName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1.0)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color.fpContent)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.fpBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.4), radius: 20, x: 0, y: 8)
        .onAppear {
            debugPrint("[CreateFolderDialog] Appeared with \(selectedPhotoCount) selected photos")
        }
    }
}

#Preview {
    CreateFolderDialog(
        selectedPhotoCount: 5,
        onCreateFolder: { folderName, includePhotos in
            debugPrint("Create folder: \(folderName), include photos: \(includePhotos)")
        },
        onDismiss: {}
    )
    .background(Color.fpBackground)
}
