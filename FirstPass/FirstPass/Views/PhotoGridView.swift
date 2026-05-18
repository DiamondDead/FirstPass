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
                            PhotoThumbnailView(
                                photo: photo,
                                onTap: {
                                    viewModel.selectPhoto(photo)
                                },
                                onCmdTap: {
                                    viewModel.toggleSelection(photo)
                                }
                            )
                        }
                    }
                    .padding()
                }
                .overlay {
                    // Photo viewer overlay
                    if viewModel.selectedPhoto != nil {
                        PhotoViewerView(viewModel: viewModel)
                            .transition(.opacity)
                            .zIndex(1)
                    }
                }
            }
        }
    }
}

/// View for a single photo thumbnail
struct PhotoThumbnailView: View {
    let photo: PhotoItem
    let onTap: () -> Void
    let onCmdTap: () -> Void
    
    // Fixed container size for thumbnails
    private let containerSize: CGFloat = 150
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            thumbnailContainer
            fileNameText
        }
    }
    
    // MARK: - View Components
    
    private var thumbnailContainer: some View {
        ZStack {
            thumbnailContent
        }
        .frame(width: containerSize, height: containerSize)
        .background(backgroundColor)
        .cornerRadius(6)
        .overlay(borderOverlay)
        .onHover { hovering in
            isHovering = hovering
        }
        .gesture(cmdTapGesture)
        .onTapGesture(perform: onTap)
    }
    
    @ViewBuilder
    private var thumbnailContent: some View {
        if let thumbnail = photo.thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: containerSize, height: containerSize)
        } else {
            loadingPlaceholder
        }
    }
    
    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: containerSize, height: containerSize)
            .overlay {
                if photo.isLoadingThumbnail {
                    ProgressView()
                        .controlSize(.small)
                }
            }
    }
    
    private var backgroundColor: Color {
        if photo.isSelected {
            return Color.blue.opacity(0.1)
        } else if isHovering {
            return Color.gray.opacity(0.15)
        } else {
            return Color.gray.opacity(0.1)
        }
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(borderColor, lineWidth: photo.isSelected ? 2 : 1)
    }
    
    private var borderColor: Color {
        photo.isSelected ? Color.blue : Color.gray.opacity(0.3)
    }
    
    private var cmdTapGesture: some Gesture {
        TapGesture()
            .modifiers(.command)
            .onEnded { _ in
                onCmdTap()
            }
    }
    
    private var fileNameText: some View {
        Text(photo.fileName)
            .font(.system(size: 11))
            .foregroundStyle(photo.isSelected ? .primary : .secondary)
            .lineLimit(1)
            .frame(width: containerSize)
    }
}

#Preview {
    let vm = PhotoGridVM()
    return PhotoGridView(viewModel: vm)
        .frame(width: 800, height: 600)
}
