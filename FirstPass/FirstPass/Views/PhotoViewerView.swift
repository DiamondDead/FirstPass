//
//  PhotoViewerView.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import SwiftUI
import AppKit

// MARK: - Keyboard Shortcut Handler

struct KeyboardShortcutHandler: NSViewRepresentable {
    let leftArrowAction: () -> Void
    let rightArrowAction: () -> Void
    let escapeAction: () -> Void
    
    func makeNSView(context: Context) -> KeyHandlingView {
        let view = KeyHandlingView()
        view.leftArrowAction = leftArrowAction
        view.rightArrowAction = rightArrowAction
        view.escapeAction = escapeAction
        // Make the view first responder to receive key events
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }
    
    func updateNSView(_ nsView: KeyHandlingView, context: Context) {}
    
    class KeyHandlingView: NSView {
        var leftArrowAction: (() -> Void)?
        var rightArrowAction: (() -> Void)?
        var escapeAction: (() -> Void)?
        
        override var acceptsFirstResponder: Bool {
            return true
        }
        
        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 123: // Left arrow
                leftArrowAction?()
            case 124: // Right arrow
                rightArrowAction?()
            case 53: // Escape
                escapeAction?()
            default:
                super.keyDown(with: event)
            }
        }
    }
}

/// View for displaying a single photo in full size with navigation
struct PhotoViewerView: View {
    let viewModel: PhotoGridVM
    
    var body: some View {
        ZStack {
            // Semi-transparent dark background
            Color.black.opacity(0.7).ignoresSafeArea()
            
            if let photo = viewModel.selectedPhoto {
                VStack(spacing: 0) {
                    // Main photo display
                    GeometryReader { geometry in
                        ZStack {
                            // Display full image for non-RAW formats, thumbnail for RAW
                            if let fullImage = photo.fullImage {
                                Image(nsImage: fullImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                            } else if let thumbnail = photo.thumbnail {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                if photo.isLoadingFullImage {
                                    // Loading indicator for full image
                                    VStack {
                                        ProgressView()
                                            .controlSize(.large)
                                            .foregroundStyle(.white)
                                            .padding()
                                        Text("Chargement en haute qualité...")
                                            .foregroundStyle(.white)
                                            .font(.caption)
                                    }
                                }
                            } else {
                                ProgressView()
                                    .controlSize(.large)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                    
                    // Bottom navigation bar
                    VStack(spacing: 8) {
                        // Navigation buttons
                        HStack(spacing: 20) {
                            // Previous button
                            Button(action: {
                                viewModel.previousPhoto()
                            }) {
                                Image(systemName: "chevron.left.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }
                            .disabled(!canGoPrevious())
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            // Close button
                            Button(action: {
                                viewModel.deselectPhoto()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }
                            .buttonStyle(.plain)
                            
                            Spacer()
                            
                            // Next button
                            Button(action: {
                                viewModel.nextPhoto()
                            }) {
                                Image(systemName: "chevron.right.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }
                            .disabled(!canGoNext())
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 40)
                        
                        // Thumbnail strip
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(viewModel.photos) { thumbPhoto in
                                    Button(action: {
                                        viewModel.selectPhoto(thumbPhoto)
                                    }) {
                                        if let thumb = thumbPhoto.thumbnail {
                                            Image(nsImage: thumb)
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(height: 60)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .stroke(viewModel.selectedPhoto?.id == thumbPhoto.id ? Color.accentColor : Color.clear, lineWidth: 3)
                                                )
                                                .cornerRadius(4)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .frame(height: 80)
                    }
                    .padding(.vertical, 20)
                }
            } else {
                // No photo selected
                EmptyView()
            }
        }
        .onAppear {
            debugPrint("[PhotoViewerView] Appeared")
        }
        .onDisappear {
            debugPrint("[PhotoViewerView] Disappeared")
        }
        .background(
            KeyboardShortcutHandler(
                leftArrowAction: { viewModel.previousPhoto() },
                rightArrowAction: { viewModel.nextPhoto() },
                escapeAction: { viewModel.deselectPhoto() }
            )
        )
    }
    
    // MARK: - Helper Methods
    
    private func canGoPrevious() -> Bool {
        guard let current = viewModel.selectedPhoto,
              let currentIndex = viewModel.photos.firstIndex(where: { $0.id == current.id }) else {
            return false
        }
        return currentIndex > 0
    }
    
    private func canGoNext() -> Bool {
        guard let current = viewModel.selectedPhoto,
              let currentIndex = viewModel.photos.firstIndex(where: { $0.id == current.id }) else {
            return false
        }
        return currentIndex < viewModel.photos.count - 1
    }
}

#Preview {
    let vm = PhotoGridVM()
    return PhotoViewerView(viewModel: vm)
        .frame(width: 800, height: 600)
}
