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
    let folderTreeVM: FolderTreeVM
    @State private var showCreateFolderDialog = false
    
    // Grid configuration
    private let gridItem = GridItem(.adaptive(minimum: 230), spacing: 16)
    private let itemSpacing: CGFloat = 16
    private let padding: CGFloat = 18 * 2 // horizontal padding on both sides
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter bar
            if !viewModel.photos.isEmpty {
                FilterBar(
                    filterFlag: Binding(
                        get: { viewModel.filterFlag },
                        set: { viewModel.filterFlag = $0 }
                    ),
                    minStars: Binding(
                        get: { viewModel.minStars },
                        set: { viewModel.minStars = $0 }
                    ),
                    selectedColorLabels: Binding(
                        get: { viewModel.selectedColorLabels },
                        set: { viewModel.selectedColorLabels = $0 }
                    ),
                    totalCount: viewModel.totalCount,
                    pickCount: viewModel.pickCount,
                    rejectCount: viewModel.rejectCount,
                    unflaggedCount: viewModel.unflaggedCount,
                    filteredCount: viewModel.filteredCount,
                    selectedPhotoCount: selectedPhotoCount,
                    onCreateFolder: { showCreateFolderDialog = true }
                )
            }
            
            // Content area
            Group {
                if viewModel.isLoading {
                    // Loading state
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .foregroundStyle(.white)
                        Text("Chargement des photos...")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.fpTextSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.fpBackground)
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
                            .foregroundStyle(Color.fpTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.fpBackground)
                } else if viewModel.photos.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.fpTextSecondary)
                        Text("Aucune photo")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.fpTextSecondary)
                        Text("Sélectionnez un dossier contenant des photos")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.fpTextSecondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.fpBackground)
                } else if viewModel.filteredPhotos.isEmpty {
                    // Empty filters state
                    VStack(spacing: 12) {
                        Text("Aucune photo")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.fpTextSecondary)
                        Text("Les filtres actifs n'ont retourné aucun résultat.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.fpTextSecondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.fpBackground)
                } else {
                    // Photo grid
                    GeometryReader { geometry in
                        ScrollView {
                            LazyVGrid(columns: [gridItem], spacing: 16) {
                                ForEach(viewModel.filteredPhotos) { photo in
                                    PhotoThumbnailView(
                                        photo: photo,
                                        isSelected: photo.isSelected,
                                        onTap: {
                                            viewModel.selectPhoto(photo)
                                        },
                                        onCmdTap: {
                                            viewModel.toggleSelection(photo)
                                        }
                                    )
                                }
                            }
                            .padding(18)
                            .padding(.bottom, 80) // Space for keyboard hints
                        }
                        .background(Color.fpContent)
                        .overlay {
                            // Photo viewer overlay
                            if viewModel.selectedPhoto != nil {
                                PhotoViewerView(viewModel: viewModel)
                                    .transition(.opacity)
                                    .zIndex(1)
                            }
                            
                            // Keyboard hints
                            KeyboardHints()
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
        }
        .background(
            KeyboardMonitor(
                cmdLeftArrowAction: { viewModel.selectPhotoToLeft() },
                cmdRightArrowAction: { viewModel.selectPhotoToRight() },
                cmdDownArrowAction: { viewModel.selectRowBelow() },
                cmdUpArrowAction: { viewModel.selectRowAbove() },
                escapeAction: { viewModel.deselectAll() },
                cmdAAction: { viewModel.selectAll() },
                isViewingPhoto: viewModel.selectedPhoto != nil,
                setRatingAction: { viewModel.setRating($0) },
                setColorLabelAction: { viewModel.setColorLabel($0) },
                clearColorLabelAction: { viewModel.clearColorLabel() }
            )
        )
        .overlay {
            // Create folder dialog — full-screen dim blocks click-through
            if showCreateFolderDialog {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture { showCreateFolderDialog = false }
                
                CreateFolderDialog(
                    selectedPhotoCount: selectedPhotoCount,
                    onCreateFolder: { folderName, includePhotos in
                        debugPrint("[PhotoGridView] Creating folder: \(folderName), include photos: \(includePhotos)")
                        let selectedPhotoURLs = viewModel.photos.filter { $0.isSelected }.map { $0.url }
                        _ = folderTreeVM.createFolderAndMovePhotos(
                            folderName: folderName,
                            photoURLs: selectedPhotoURLs,
                            includeSelectedPhotos: includePhotos
                        )
                        if includePhotos {
                            viewModel.deselectAll()
                            // Reload photos from the current folder to reflect moved files
                            if let currentFolder = folderTreeVM.selectedFolder {
                                viewModel.loadPhotos(from: currentFolder.url)
                            }
                        }
                        showCreateFolderDialog = false
                    },
                    onDismiss: { showCreateFolderDialog = false }
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    /// Count of selected photos
    private var selectedPhotoCount: Int {
        viewModel.photos.filter { $0.isSelected }.count
    }
    
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
    let isSelected: Bool
    let onTap: () -> Void
    let onCmdTap: () -> Void
    
    // Color label hex values from web design
    private let colorLabelHex: [ColorLabel: Color] = [
        .red: Color(red: 1.0, green: 0.2, blue: 0.2),
        .yellow: Color(red: 1.0, green: 0.84, blue: 0.0),
        .green: Color(red: 0.2, green: 0.8, blue: 0.4),
        .blue: Color(red: 0.2, green: 0.6, blue: 1.0),
        .purple: Color(red: 0.6, green: 0.4, blue: 1.0)
    ]
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            thumbnailContainer
            fileNameText
        }
    }
    
    // MARK: - View Components
    
    private var thumbnailContainer: some View {
        ZStack {
            // Color label spine (left edge)
            if photo.colorLabel != .none {
                VStack {
                    colorLabelHex[photo.colorLabel] ?? .gray
                }
                .frame(width: 3)
                .frame(maxHeight: .infinity)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            thumbnailContent
            
            // Flag badge
            if photo.flag != .unflagged {
                flagBadge
                    .padding(.top, 6)
                    .padding(.leading, photo.colorLabel != .none ? 9 : 6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            
            // Star overlay
            if photo.rating > 0 {
                starOverlay
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
        }
        .aspectRatio(3/2, contentMode: .fit)
        .background(Color(red: 0.04, green: 0.04, blue: 0.045)) // #0a0a0b
        .cornerRadius(4)
        .overlay(selectionRing)
        .shadow(color: .black.opacity(isSelected ? 0.4 : 0.15), radius: isSelected ? 8 : 2, x: 0, y: isSelected ? 8 : 1)
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
                .opacity(photo.flag == .rejected ? 0.65 : 1.0)
                .saturation(photo.flag == .rejected ? 0.4 : 1.0)
        } else {
            loadingPlaceholder
        }
    }
    
    private var loadingPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                if photo.isLoadingThumbnail {
                    ProgressView()
                        .controlSize(.small)
                        .foregroundStyle(.white)
                }
            }
    }
    
    private var flagBadge: some View {
        let isPick = photo.flag == .pick
        let badgeColor: Color = isPick ? Color(red: 0.18, green: 0.82, blue: 0.35) : Color(red: 1.0, green: 0.27, blue: 0.23)
        
        return ZStack {
            RoundedRectangle(cornerRadius: 4)
                .fill(badgeColor.opacity(0.95))
            
            if isPick {
                Image(systemName: "flag.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(Color(red: 0.04, green: 0.04, blue: 0.045))
            } else {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color(red: 0.04, green: 0.04, blue: 0.045))
            }
        }
        .frame(width: 18, height: 18)
    }
    
    private var starOverlay: some View {
        HStack(spacing: 1.5) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= photo.rating ? "star.fill" : "star")
                    .font(.system(size: 10))
                    .foregroundStyle(star <= photo.rating ? Color.fpAccent : Color.white.opacity(0.3))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .bottom,
                endPoint: .top
            )
        )
    }
    
    private var selectionRing: some View {
        RoundedRectangle(cornerRadius: 4)
            .stroke(isSelected ? Color.fpAccent : Color.clear, lineWidth: 2)
    }
    
    private var fileNameText: some View {
        Text(photo.fileName)
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundStyle(isSelected ? Color.fpAccent : Color.fpTextSecondary)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}

#Preview {
    let vm = PhotoGridVM()
    let folderVM = FolderTreeVM()
    return PhotoGridView(viewModel: vm, folderTreeVM: folderVM)
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
    let setRatingAction: ((Int) -> Void)?
    let setColorLabelAction: ((ColorLabel) -> Void)?
    let clearColorLabelAction: (() -> Void)?
    
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
        context.coordinator.setRatingAction = setRatingAction
        context.coordinator.setColorLabelAction = setColorLabelAction
        context.coordinator.clearColorLabelAction = clearColorLabelAction
        
        // Register monitor only once
        guard context.coordinator.monitor == nil else { return }
        debugPrint("[KeyboardMonitor] Registering local event monitor")
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator = context.coordinator] event in
            guard let coordinator else { return event }
            let isCmdPressed = event.modifierFlags.contains(.command)
            
            // Handle character keys for ratings (1-5) and color labels (6-9)
            if let characters = event.charactersIgnoringModifiers, characters.count == 1, !isCmdPressed {
                let char = characters.lowercased()
                switch char {
                case "1", "2", "3", "4", "5":
                    let rating = Int(char) ?? 1
                    coordinator.setRatingAction?(rating)
                    return nil
                case "6":
                    coordinator.setColorLabelAction?(.red)
                    return nil
                case "7":
                    coordinator.setColorLabelAction?(.yellow)
                    return nil
                case "8":
                    coordinator.setColorLabelAction?(.green)
                    return nil
                case "9":
                    coordinator.setColorLabelAction?(.blue)
                    return nil
                case "0":
                    coordinator.clearColorLabelAction?()
                    return nil
                default:
                    break
                }
            }
            
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
        var setRatingAction: ((Int) -> Void)?
        var setColorLabelAction: ((ColorLabel) -> Void)?
        var clearColorLabelAction: (() -> Void)?
        
        deinit {
            if let monitor = monitor {
                debugPrint("[KeyboardMonitor] Removing local event monitor")
                NSEvent.removeMonitor(monitor)
            }
        }
    }
}
