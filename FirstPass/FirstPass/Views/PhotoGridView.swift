//
//  PhotoGridView.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import SwiftUI

/// View for displaying photos in a grid layout
struct PhotoGridView: View {
    let viewModel: PhotoGridVM
    
    // Grid configuration
    private let gridItem = GridItem(.adaptive(minimum: 150), spacing: 8)
    
    var body: some View {
        Group {
            if viewModel.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Chargement des photos...")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let errorMessage = viewModel.errorMessage {
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
            } else if viewModel.photos.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Aucune photo")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                    Text("Sélectionnez un dossier contenant des photos")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Photo grid
                ScrollView {
                    LazyVGrid(columns: [gridItem], spacing: 12) {
                        ForEach(viewModel.photos) { photo in
                            PhotoThumbnailView(photo: photo)
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

/// View for a single photo thumbnail
struct PhotoThumbnailView: View {
    let photo: PhotoItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Thumbnail image
            ZStack {
                if let thumbnail = photo.thumbnail {
                    Image(nsImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: photo.orientation == .portrait ? 150 : 120)
                } else {
                    // Loading placeholder
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: photo.orientation == .portrait ? 150 : 120)
                        .overlay {
                            if photo.isLoadingThumbnail {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                }
            }
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
            
            // File name
            Text(photo.fileName)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

#Preview {
    let vm = PhotoGridVM()
    return PhotoGridView(viewModel: vm)
        .frame(width: 800, height: 600)
}
