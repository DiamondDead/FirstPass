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
    let cmdLeftArrowAction: () -> Void
    let cmdRightArrowAction: () -> Void
    let cmdDownArrowAction: () -> Void
    let cmdUpArrowAction: () -> Void
    let flagPickAction: () -> Void
    let flagRejectAction: () -> Void
    let flagUnflaggedAction: () -> Void
    let setRatingAction: (Int) -> Void
    let setColorLabelAction: (ColorLabel) -> Void
    let clearColorLabelAction: () -> Void
    
    func makeNSView(context: Context) -> KeyHandlingView {
        let view = KeyHandlingView()
        view.leftArrowAction = leftArrowAction
        view.rightArrowAction = rightArrowAction
        view.escapeAction = escapeAction
        view.cmdLeftArrowAction = cmdLeftArrowAction
        view.cmdRightArrowAction = cmdRightArrowAction
        view.cmdDownArrowAction = cmdDownArrowAction
        view.cmdUpArrowAction = cmdUpArrowAction
        view.flagPickAction = flagPickAction
        view.flagRejectAction = flagRejectAction
        view.flagUnflaggedAction = flagUnflaggedAction
        view.setRatingAction = setRatingAction
        view.setColorLabelAction = setColorLabelAction
        view.clearColorLabelAction = clearColorLabelAction
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
        var cmdLeftArrowAction: (() -> Void)?
        var cmdRightArrowAction: (() -> Void)?
        var cmdDownArrowAction: (() -> Void)?
        var cmdUpArrowAction: (() -> Void)?
        var flagPickAction: (() -> Void)?
        var flagRejectAction: (() -> Void)?
        var flagUnflaggedAction: (() -> Void)?
        var setRatingAction: ((Int) -> Void)?
        var setColorLabelAction: ((ColorLabel) -> Void)?
        var clearColorLabelAction: (() -> Void)?
        
        override var acceptsFirstResponder: Bool {
            return true
        }
        
        override func keyDown(with event: NSEvent) {
            let isCmdPressed = event.modifierFlags.contains(.command)
            
            // Ratings (1-5), color labels (6-9) and clear (0) — matched on the
            // physical digit row so they work on AZERTY without Shift.
            if !isCmdPressed, let digit = KeyboardLayout.digit(from: event) {
                switch digit {
                case 1...5:
                    setRatingAction?(digit)
                    return
                case 6:
                    setColorLabelAction?(.red)
                    return
                case 7:
                    setColorLabelAction?(.yellow)
                    return
                case 8:
                    setColorLabelAction?(.green)
                    return
                case 9:
                    setColorLabelAction?(.blue)
                    return
                default: // 0
                    clearColorLabelAction?()
                    return
                }
            }

            // Flags (P, X, U) — matched on the typed character, layout-independent.
            // Cmd guard keeps system shortcuts like Cmd+P working.
            if !isCmdPressed, let char = KeyboardLayout.lowercasedChar(from: event) {
                switch char {
                case "p":
                    flagPickAction?()
                    return
                case "x":
                    flagRejectAction?()
                    return
                case "u":
                    flagUnflaggedAction?()
                    return
                default:
                    break
                }
            }
            
            switch event.keyCode {
            case 123: // Left arrow
                if isCmdPressed {
                    cmdLeftArrowAction?()
                } else {
                    leftArrowAction?()
                }
            case 124: // Right arrow
                if isCmdPressed {
                    cmdRightArrowAction?()
                } else {
                    rightArrowAction?()
                }
            case 125: // Down arrow
                if isCmdPressed {
                    cmdDownArrowAction?()
                } else {
                    super.keyDown(with: event)
                }
            case 126: // Up arrow
                if isCmdPressed {
                    cmdUpArrowAction?()
                } else {
                    super.keyDown(with: event)
                }
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
    
    // Color label hex values from web design
    private let colorLabelHex: [ColorLabel: Color] = [
        .red: Color(red: 1.0, green: 0.2, blue: 0.2),
        .yellow: Color(red: 1.0, green: 0.84, blue: 0.0),
        .green: Color(red: 0.2, green: 0.8, blue: 0.4),
        .blue: Color(red: 0.2, green: 0.6, blue: 1.0),
        .purple: Color(red: 0.6, green: 0.4, blue: 1.0)
    ]
    
    var body: some View {
        ZStack {
            // Dark background — opaque so the viewer stays dark even when the
            // app runs in light theme (intentional, to not bias color perception).
            // A tap in this dark area (outside the image/controls) closes the viewer,
            // mirroring the Escape shortcut. Image and buttons sit above and consume their own taps.
            Color(red: 0.05, green: 0.05, blue: 0.055)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture {
                    // Debug: log background tap that dismisses the viewer
                    debugPrint("[PhotoViewerView] Dark background tapped — returning to grid")
                    viewModel.deselectPhoto()
                }
            
            if let photo = viewModel.selectedPhoto {
                VStack(spacing: 0) {
                    // Main photo display area
                    GeometryReader { geometry in
                        ZStack {
                            // Display full image for non-RAW formats, thumbnail for RAW
                            if let fullImage = photo.fullImage {
                                Image(nsImage: fullImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                    .shadow(color: .black.opacity(0.7), radius: 60, x: 0, y: 12)
                            } else if let thumbnail = photo.thumbnail {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                                    .shadow(color: .black.opacity(0.7), radius: 60, x: 0, y: 12)
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
                            
                            // Flag badge overlay (large)
                            if photo.flag != .unflagged {
                                largeFlagBadge(for: photo.flag)
                                    .padding(.top, 14)
                                    .padding(.leading, 14)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                            
                            // Color label indicator
                            if photo.colorLabel != .none {
                                Circle()
                                    .fill(colorLabelHex[photo.colorLabel] ?? .gray)
                                    .frame(width: 12, height: 12)
                                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
                                    .padding(.top, 14)
                                    .padding(.trailing, 14)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            }
                            
                            // Navigation arrows
                            HStack {
                                Button(action: { viewModel.previousPhoto() }) {
                                    navArrow(direction: .left)
                                }
                                .disabled(!canGoPrevious())
                                .buttonStyle(.plain)
                                
                                Spacer()
                                
                                Button(action: { viewModel.nextPhoto() }) {
                                    navArrow(direction: .right)
                                }
                                .disabled(!canGoNext())
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            
                            // Counter chip
                            if let currentIndex = viewModel.photos.firstIndex(where: { $0.id == photo.id }) {
                                counterChip(current: currentIndex + 1, total: viewModel.photos.count)
                                    .padding(.top, 14)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                            }
                            
                            // Close button
                            Button(action: { viewModel.deselectPhoto() }) {
                                closeChip()
                            }
                            .padding(.top, 14)
                            .padding(.trailing, 14)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        }
                    }
                    
                    // EXIF strip (showing N/A for now)
                    ExifStrip(photo: photo)
                    
                    // Tagging bar
                    TaggingBar(photo: photo, viewModel: viewModel)
                    
                    // Filmstrip
                    filmstrip
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
                escapeAction: { viewModel.deselectPhoto() },
                cmdLeftArrowAction: {},
                cmdRightArrowAction: {},
                cmdDownArrowAction: {},
                cmdUpArrowAction: {},
                flagPickAction: { viewModel.setFlagPick() },
                flagRejectAction: { viewModel.setFlagReject() },
                flagUnflaggedAction: { viewModel.setFlagUnflagged() },
                setRatingAction: { viewModel.setRating($0) },
                setColorLabelAction: { viewModel.setColorLabel($0) },
                clearColorLabelAction: { viewModel.clearColorLabel() }
            )
        )
        // The viewer is always dark regardless of the app theme, so the
        // dynamic fp* colors used inside resolve to their dark variants.
        .environment(\.colorScheme, .dark)
    }
    
    // MARK: - Helper Methods
    
    private enum NavDirection { case left, right }
    
    @ViewBuilder
    private func largeFlagBadge(for flag: Flag) -> some View {
        let isPick = flag == .pick
        let badgeColor: Color = isPick ? Color(red: 0.18, green: 0.82, blue: 0.35) : Color(red: 1.0, green: 0.27, blue: 0.23)
        
        HStack(spacing: 5) {
            if isPick {
                Image(systemName: "flag.fill")
                    .font(.system(size: 12))
            } else {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
            }
            Text(isPick ? "PICK" : "REJECT")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.04)
        }
        .foregroundStyle(Color(red: 0.04, green: 0.04, blue: 0.045))
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(badgeColor.opacity(0.95))
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 2)
    }
    
    @ViewBuilder
    private func navArrow(direction: NavDirection) -> some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.06))
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                )
            
            Image(systemName: direction == .left ? "chevron.left" : "chevron.right")
                .font(.system(size: 14))
                .foregroundStyle(Color.fpText)
        }
        .frame(width: 36, height: 36)
    }
    
    @ViewBuilder
    private func counterChip(current: Int, total: Int) -> some View {
        Text("\(String(format: "%03d", current)) / \(String(format: "%03d", total))")
            .font(.system(size: 10.5, design: .monospaced))
            .foregroundStyle(Color.fpText.opacity(0.78))
            .tracking(0.04)
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(Color.black.opacity(0.5))
            .cornerRadius(999)
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
            )
    }
    
    @ViewBuilder
    private func closeChip() -> some View {
        HStack(spacing: 5) {
            Image(systemName: "square.grid.2x2")
                .font(.system(size: 11))
            Text("Grille")
                .font(.system(size: 10.5))
            Text("Esc")
                .font(.system(size: 9.5, design: .monospaced))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(Color.white.opacity(0.1))
                .cornerRadius(3)
        }
        .foregroundStyle(Color.fpText.opacity(0.78))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.black.opacity(0.5))
        .cornerRadius(999)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.5)
        )
    }
    
    @ViewBuilder
    private var filmstrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(viewModel.photos) { thumbPhoto in
                    Button(action: {
                        viewModel.selectPhoto(thumbPhoto)
                    }) {
                        if let thumb = thumbPhoto.thumbnail {
                            ZStack {
                                // Color label spine
                                if thumbPhoto.colorLabel != .none {
                                    VStack {
                                        colorLabelHex[thumbPhoto.colorLabel] ?? .gray
                                    }
                                    .frame(width: 2)
                                    .frame(maxHeight: .infinity)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Image(nsImage: thumb)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .opacity(thumbPhoto.flag == .rejected ? 0.6 : (viewModel.selectedPhoto?.id == thumbPhoto.id ? 1.0 : 0.82))
                                    .saturation(thumbPhoto.flag == .rejected ? 0.4 : 1.0)
                                
                                // Selection ring
                                let isSelected = viewModel.selectedPhoto?.id == thumbPhoto.id
                                let selectionColor: Color = isSelected ? Color.fpAccent : Color.clear
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(selectionColor, lineWidth: 2)
                                
                                // Flag indicator
                                if thumbPhoto.flag != .unflagged {
                                    let isPick = thumbPhoto.flag == .pick
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(isPick ? Color(red: 0.18, green: 0.82, blue: 0.35) : Color(red: 1.0, green: 0.27, blue: 0.23))
                                        .frame(width: 10, height: 10)
                                        .padding(3)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                                }
                                
                                // Star rating
                                if thumbPhoto.rating > 0 {
                                    Text("★\(thumbPhoto.rating)")
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundStyle(Color.fpAccent)
                                        .padding(4)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                                }
                            }
                            .frame(height: 70)
                            .aspectRatio(3/2, contentMode: .fit)
                            .background(Color(red: 0.04, green: 0.04, blue: 0.045))
                            .cornerRadius(3)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
                            )
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .frame(height: 92)
        .background(Color(red: 0.055, green: 0.055, blue: 0.063))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5),
            alignment: .top
        )
    }
    
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

// MARK: - EXIF Strip

struct ExifStrip: View {
    let photo: PhotoItem
    
    var body: some View {
        HStack(spacing: 18) {
            Text(photo.fileName)
                .font(.system(size: 10.5, design: .monospaced))
                .foregroundStyle(Color.fpText)
                .fontWeight(.semibold)
            
            exifSeparator()
            exifField(photo.exif.camera)
            exifSeparator()
            exifField(photo.exif.lens)
            exifSeparator()
            exifField(photo.exif.focalLength, isMono: true)
            exifSeparator()
            exifField(photo.exif.aperture, isMono: true)
            exifSeparator()
            exifField(photo.exif.shutterSpeed, isMono: true)
            exifSeparator()
            exifField(photo.exif.iso, isMono: true)
            exifSeparator()
            exifField(photo.exif.date, isMono: true)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 10)
        .background(Color(red: 0.08, green: 0.08, blue: 0.086).opacity(0.6))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5),
            alignment: .top
        )
    }
    
    @ViewBuilder
    private func exifField(_ text: String, isMono: Bool = false) -> some View {
        Text(text)
            .font(.system(size: 10.5, design: isMono ? .monospaced : .default))
            .foregroundStyle(Color.fpTextSecondary)
            .tracking(isMono ? 0.02 : 0)
    }
    
    @ViewBuilder
    private func exifSeparator() -> some View {
        Text("·")
            .foregroundStyle(Color.white.opacity(0.18))
    }
}

// MARK: - Tagging Bar

struct TaggingBar: View {
    let photo: PhotoItem
    let viewModel: PhotoGridVM
    
    // Color label hex values
    private let colorLabelHex: [ColorLabel: Color] = [
        .red: Color(red: 1.0, green: 0.2, blue: 0.2),
        .yellow: Color(red: 1.0, green: 0.84, blue: 0.0),
        .green: Color(red: 0.2, green: 0.8, blue: 0.4),
        .blue: Color(red: 0.2, green: 0.6, blue: 1.0),
        .purple: Color(red: 0.6, green: 0.4, blue: 1.0)
    ]
    
    var body: some View {
        HStack(spacing: 22) {
            // Flag buttons
            HStack(spacing: 6) {
                flagButton(label: "Pick", key: "P", isActive: photo.flag == .pick, color: Color(red: 0.18, green: 0.82, blue: 0.35)) {
                    photo.updateFlag(photo.flag == .pick ? .unflagged : .pick)
                }
                
                flagButton(label: "Unflag", key: "U", isActive: photo.flag == .unflagged, isMuted: true) {
                    photo.updateFlag(.unflagged)
                }
                
                flagButton(label: "Reject", key: "X", isActive: photo.flag == .rejected, color: Color(red: 1.0, green: 0.27, blue: 0.23)) {
                    photo.updateFlag(photo.flag == .rejected ? .unflagged : .rejected)
                }
            }
            
            divider()
            
            // Star buttons
            HStack(spacing: 6) {
                ForEach(1...5, id: \.self) { star in
                    starButton(star: star)
                }
            }
            
            divider()
            
            // Color label buttons
            HStack(spacing: 6) {
                ForEach([ColorLabel.red, .yellow, .green, .blue, .purple], id: \.self) { label in
                    colorLabelButton(label: label, index: colorLabelIndex(for: label))
                }
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 12)
        .background(Color(red: 0.11, green: 0.11, blue: 0.118).opacity(0.78))
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 0.5),
            alignment: .top
        )
    }
    
    @ViewBuilder
    private func flagButton(label: String, key: String, isActive: Bool, color: Color? = nil, isMuted: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                HStack(spacing: 5) {
                    if label == "Pick" {
                        Image(systemName: "flag.fill")
                            .font(.system(size: 13))
                    } else if label == "Reject" {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                    } else {
                        Circle()
                            .stroke(Color.fpTextSecondary, lineWidth: 1.5)
                            .frame(width: 13, height: 13)
                    }
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(isActive && color != nil ? Color(red: 0.04, green: 0.04, blue: 0.045) : (isMuted ? Color.fpTextSecondary : Color.fpText))
                
                Text(key)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(isActive && color != nil ? Color(red: 0, green: 0, blue: 0).opacity(0.7) : Color.fpTextSecondary.opacity(0.7))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isActive ? Color.black.opacity(0.2) : Color.white.opacity(0.06))
                    .cornerRadius(3)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isActive ? (color ?? Color.white.opacity(0.16)) : Color.white.opacity(0.04))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 52)
    }
    
    @ViewBuilder
    private func starButton(star: Int) -> some View {
        Button(action: {
            photo.updateRating(photo.rating == star ? 0 : star)
        }) {
            VStack(spacing: 2) {
                Image(systemName: star <= photo.rating ? "star.fill" : "star")
                    .font(.system(size: 15))
                    .foregroundStyle(star <= photo.rating ? Color.fpAccent : Color.white.opacity(0.28))
                
                Text("\(star)")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(star <= photo.rating ? Color.fpAccent : Color.fpTextSecondary.opacity(0.7))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(star <= photo.rating ? Color.fpAccent.opacity(0.18) : Color.white.opacity(0.06))
                    .cornerRadius(3)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func colorLabelButton(label: ColorLabel, index: Int) -> some View {
        Button(action: {
            photo.updateColorLabel(photo.colorLabel == label ? .none : label)
        }) {
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(colorLabelHex[label] ?? .gray)
                    .frame(width: 16, height: 16)
                    .opacity(photo.colorLabel == label ? 1.0 : (photo.colorLabel == .none ? 0.85 : 0.35))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(photo.colorLabel == label ? Color.white.opacity(0.95) : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.4), radius: photo.colorLabel == label ? 2 : 1, x: 0, y: photo.colorLabel == label ? 2 : 1)
                
                // Purple has no keyboard shortcut (6-9 map to red-blue, 0 clears)
                Text(index < 4 ? "\(6 + index)" : " ")
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(Color.fpTextSecondary.opacity(0.7))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(index < 4 ? Color.white.opacity(0.06) : Color.clear)
                    .cornerRadius(3)
            }
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    @ViewBuilder
    private func divider() -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 30)
    }
    
    private func colorLabelIndex(for label: ColorLabel) -> Int {
        switch label {
        case .red: return 0
        case .yellow: return 1
        case .green: return 2
        case .blue: return 3
        case .purple: return 4
        case .none: return 0
        }
    }
}

#Preview {
    let vm = PhotoGridVM()
    return PhotoViewerView(viewModel: vm)
        .frame(width: 800, height: 600)
}
