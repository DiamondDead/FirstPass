//
//  PhotoGridView.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import SwiftUI
import AppKit

/// View for displaying photos in a grid layout
struct PhotoGridView: View {
    let viewModel: PhotoGridVM
    
    // Grid configuration
    private let gridItem = GridItem(.adaptive(minimum: 150), spacing: 8)
    private let itemSpacing: CGFloat = 8
    private let padding: CGFloat = 12 * 2 // horizontal padding on both sides
    
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
                GeometryReader { geometry in
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
                    .onAppear {
                        updateGridColumns(width: geometry.size.width)
                    }
                    .onChange(of: geometry.size.width) { _, newWidth in
                        updateGridColumns(width: newWidth)
                    }
                }
            }
        }
        .background(
            KeyboardMonitor(
                cmdLeftArrowAction: { viewModel.selectPhotoToLeft() },
                cmdRightArrowAction: { viewModel.selectPhotoToRight() },
                cmdDownArrowAction: { viewModel.selectRowBelow() },
                cmdUpArrowAction: { viewModel.selectRowAbove() },
                escapeAction: { viewModel.deselectAll() },
                cmdAAction: { viewModel.selectAll() },
                isViewingPhoto: viewModel.selectedPhoto != nil
            )
        )
    }
    
    // MARK: - Helper Methods
    
    /// Updates the grid columns count based on available width
    private func updateGridColumns(width: CGFloat) {
        let availableWidth = width - padding
        let itemMinWidth: CGFloat = 150
        let calculatedColumns = max(1, Int(availableWidth / (itemMinWidth + itemSpacing)))
        viewModel.gridColumns = calculatedColumns
        debugPrint("[PhotoGridView] Updated grid columns to: \(calculatedColumns) for width: \(width)")
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
        .onTapGesture {
            // Use currentEvent modifiers for accurate Cmd detection at click time
            if NSApp.currentEvent?.modifierFlags.contains(.command) == true {
                onCmdTap()
            } else {
                onTap()
            }
        }
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

// MARK: - Keyboard Monitor

/// Global keyboard event monitor for Cmd+arrow shortcuts
/// Uses coordinator to always call the latest closures and avoids duplicate monitors
struct KeyboardMonitor: NSViewRepresentable {
    let cmdLeftArrowAction: () -> Void
    let cmdRightArrowAction: () -> Void
    let cmdDownArrowAction: () -> Void
    let cmdUpArrowAction: () -> Void
    let escapeAction: () -> Void
    let cmdAAction: () -> Void
    let isViewingPhoto: Bool
    
    func makeNSView(context: Context) -> NSView {
        NSView()
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Always update coordinator with the latest closures and state
        context.coordinator.cmdLeftArrowAction = cmdLeftArrowAction
        context.coordinator.cmdRightArrowAction = cmdRightArrowAction
        context.coordinator.cmdDownArrowAction = cmdDownArrowAction
        context.coordinator.cmdUpArrowAction = cmdUpArrowAction
        context.coordinator.escapeAction = escapeAction
        context.coordinator.cmdAAction = cmdAAction
        context.coordinator.isViewingPhoto = isViewingPhoto
        
        // Register monitor only once
        guard context.coordinator.monitor == nil else { return }
        debugPrint("[KeyboardMonitor] Registering local event monitor")
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator = context.coordinator] event in
            guard let coordinator else { return event }
            let isCmdPressed = event.modifierFlags.contains(.command)
            
            switch event.keyCode {
            case 123 where isCmdPressed: // Cmd + Left arrow
                coordinator.cmdLeftArrowAction()
                return nil
            case 124 where isCmdPressed: // Cmd + Right arrow
                coordinator.cmdRightArrowAction()
                return nil
            case 125 where isCmdPressed: // Cmd + Down arrow
                coordinator.cmdDownArrowAction()
                return nil
            case 126 where isCmdPressed: // Cmd + Up arrow
                coordinator.cmdUpArrowAction()
                return nil
            case 0 where isCmdPressed: // Cmd + A (keyCode 0 is 'a')
                // Don't intercept Cmd+A when viewer is open (might want it for image actions later)
                guard !coordinator.isViewingPhoto else { return event }
                coordinator.cmdAAction()
                return nil
            case 53: // Escape (no Cmd)
                // When viewer is open, let the viewer's own escape handler close it
                guard !coordinator.isViewingPhoto else { return event }
                coordinator.escapeAction()
                return nil
            default:
                return event
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        var monitor: Any?
        var cmdLeftArrowAction: () -> Void = {}
        var cmdRightArrowAction: () -> Void = {}
        var cmdDownArrowAction: () -> Void = {}
        var cmdUpArrowAction: () -> Void = {}
        var escapeAction: () -> Void = {}
        var cmdAAction: () -> Void = {}
        var isViewingPhoto: Bool = false
        
        deinit {
            if let monitor = monitor {
                debugPrint("[KeyboardMonitor] Removing local event monitor")
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
