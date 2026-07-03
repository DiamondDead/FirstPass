//
//  PhotoGridVM.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import Foundation
import AppKit
import ImageIO

// MARK: - Array Extension for Chunking

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

/// View model for managing photo grid display
@Observable
@MainActor
final class PhotoGridVM {
    
    // MARK: - State
    
    var photos: [PhotoItem] = []
    var selectedPhoto: PhotoItem?
    var activePhotoForNavigation: PhotoItem? // Photo used as reference for keyboard selection
    var draggingPhotoURLs: [URL] = [] // URLs of photos currently dragged to a sidebar folder
    var isLoading: Bool = false
    var errorMessage: String?
    var gridColumns: Int = 4 // Default, will be updated by view
    
    // Filter state
    var filterFlag: FilterFlag = .all
    var minStars: Int = 0
    var selectedColorLabels: Set<ColorLabel> = []

    // Sort state
    var sortKey: SortKey = .name
    var sortAscending: Bool = true
    
    // MARK: - Computed Properties
    
    /// Photos filtered by current filter settings, in the selected sort order
    var filteredPhotos: [PhotoItem] {
        let hasColorLabels = !selectedColorLabels.isEmpty
        
        let result = photos.filter { photo in
            // Filter by flag
            switch filterFlag {
            case .all:
                break
            case .pick:
                if photo.flag != .pick { return false }
            case .reject:
                if photo.flag != .rejected { return false }
            case .unflagged:
                if photo.flag != .unflagged { return false }
            }
            
            // Filter by minimum stars
            if photo.rating < minStars { return false }
            
            // Filter by color labels
            if hasColorLabels && !selectedColorLabels.contains(photo.colorLabel) { return false }
            
            return true
        }

        return result.sorted { a, b in
            let ordered: Bool
            switch sortKey {
            case .name:
                ordered = a.fileName.localizedCaseInsensitiveCompare(b.fileName) == .orderedAscending
            case .date:
                if a.sortDate != b.sortDate {
                    ordered = a.sortDate < b.sortDate
                } else {
                    ordered = a.fileName.localizedCaseInsensitiveCompare(b.fileName) == .orderedAscending
                }
            case .rating:
                if a.rating != b.rating {
                    ordered = a.rating < b.rating
                } else {
                    ordered = a.fileName.localizedCaseInsensitiveCompare(b.fileName) == .orderedAscending
                }
            }
            return sortAscending ? ordered : !ordered
        }
    }
    
    /// Count of photos for each filter category
    var totalCount: Int { photos.count }
    var pickCount: Int { photos.filter { $0.flag == .pick }.count }
    var rejectCount: Int { photos.filter { $0.flag == .rejected }.count }
    var unflaggedCount: Int { photos.filter { $0.flag == .unflagged }.count }
    var filteredCount: Int { filteredPhotos.count }
    
    // MARK: - Supported image extensions
    
    private let imageExtensions: Set<String> = [
        "cr3", "cr2", "arw", "nef", "raf", "rw2", "orf", "dng", "raw",
        "heic", "jpg", "jpeg", "tif", "tiff"
    ]
    
    // MARK: - RAW format extensions
    
    private let rawExtensions: Set<String> = [
        "cr3", "cr2", "arw", "nef", "raf", "rw2", "orf", "dng", "raw"
    ]
    
    // MARK: - Initialization
    
    init() {
        debugPrint("[PhotoGridVM] Initialized")
    }
    
    // MARK: - Public Methods
    
    /// Loads photos from a folder URL
    func loadPhotos(from folderURL: URL) {
        debugPrint("[PhotoGridVM] Loading photos from: \(folderURL.path)")
        
        isLoading = true
        errorMessage = nil
        photos = []
        selectedPhoto = nil
        
        // Note: Security-scoped resource access is managed by FolderTreeVM
        // We don't need to start/stop it here since the parent folder maintains the access
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            // Filter for image files only
            let imageFiles = contents.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return imageExtensions.contains(fileExtension)
            }
            
            debugPrint("[PhotoGridVM] Found \(imageFiles.count) image files")
            
            // Create photo items — EXIF and XMP metadata are read in the
            // background alongside the thumbnails to keep the UI responsive.
            var photoItems: [PhotoItem] = []
            for fileURL in imageFiles {
                photoItems.append(PhotoItem(url: fileURL, fileName: fileURL.lastPathComponent))
            }

            // Sort alphabetically
            photoItems.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }

            self.photos = photoItems

            // Load thumbnails + metadata asynchronously
            loadThumbnails(for: photoItems)
            
        } catch {
            debugPrint("[PhotoGridVM] Error loading photos: \(error.localizedDescription)")
            errorMessage = "Erreur lors du chargement des photos: \(error.localizedDescription)"
            isLoading = false
        }
    }
    
    /// Selects a photo for viewing
    func selectPhoto(_ photo: PhotoItem) {
        selectedPhoto = photo
        debugPrint("[PhotoGridVM] Selected photo: \(photo.fileName)")
        
        // Load full-quality image for non-RAW formats
        loadFullImage(for: photo)
    }
    
    /// Deselects the current photo
    func deselectPhoto() {
        selectedPhoto = nil
        debugPrint("[PhotoGridVM] Deselected photo")
    }
    
    /// Deselects all photos and clears the active navigation point
    func deselectAll() {
        for photo in photos {
            photo.isSelected = false
        }
        activePhotoForNavigation = nil
        debugPrint("[PhotoGridVM] Deselected all photos")
    }
    
    /// Selects all photos currently visible in the grid (respects active
    /// filters — photos hidden by a filter must never enter the selection,
    /// otherwise bulk actions like "move to folder" would affect them).
    func selectAll() {
        let visible = filteredPhotos
        for photo in visible {
            photo.isSelected = true
        }
        // Set anchor to the last photo so arrow navigation continues from there
        activePhotoForNavigation = visible.last
        debugPrint("[PhotoGridVM] Selected all \(visible.count) visible photos")
    }
    
    /// Selects the range between the navigation anchor and the given photo
    /// (Shift+click), in the visible (filtered + sorted) order. Without an
    /// anchor, behaves like a simple additive selection.
    func selectRange(to photo: PhotoItem) {
        let visible = filteredPhotos
        guard let anchor = activePhotoForNavigation,
              let anchorIndex = visible.firstIndex(where: { $0.id == anchor.id }),
              let targetIndex = visible.firstIndex(where: { $0.id == photo.id }) else {
            photo.isSelected = true
            activePhotoForNavigation = photo
            debugPrint("[PhotoGridVM] Range select without anchor: selected \(photo.fileName)")
            return
        }

        let range = min(anchorIndex, targetIndex)...max(anchorIndex, targetIndex)
        for index in range {
            visible[index].isSelected = true
        }
        debugPrint("[PhotoGridVM] Selected range of \(range.count) photos (anchor: \(anchor.fileName))")
    }

    /// Toggles selection state of a photo for multi-select (Cmd+click)
    func toggleSelection(_ photo: PhotoItem) {
        photo.isSelected.toggle()
        if photo.isSelected {
            // Always update anchor to the last photo selected — this is the reference for arrow navigation
            activePhotoForNavigation = photo
        } else if activePhotoForNavigation?.id == photo.id {
            // If we deselected the current anchor, clear it
            activePhotoForNavigation = nil
        }
        debugPrint("[PhotoGridVM] Toggled selection for photo: \(photo.fileName) - selected: \(photo.isSelected), anchor: \(activePhotoForNavigation?.fileName ?? "none")")
    }
    
    /// Selects photo to the left with Cmd+left arrow (in filtered order)
    func selectPhotoToLeft() {
        let visible = filteredPhotos
        guard let activePhoto = activePhotoForNavigation,
              let currentIndex = visible.firstIndex(where: { $0.id == activePhoto.id }),
              currentIndex > 0 else {
            debugPrint("[PhotoGridVM] Cannot select photo to left: no active photo or at start")
            return
        }

        let leftPhoto = visible[currentIndex - 1]
        leftPhoto.isSelected = true
        activePhotoForNavigation = leftPhoto
        debugPrint("[PhotoGridVM] Selected photo to left: \(leftPhoto.fileName)")
    }

    /// Selects photo to the right with Cmd+right arrow (in filtered order)
    func selectPhotoToRight() {
        let visible = filteredPhotos
        guard let activePhoto = activePhotoForNavigation,
              let currentIndex = visible.firstIndex(where: { $0.id == activePhoto.id }),
              currentIndex < visible.count - 1 else {
            debugPrint("[PhotoGridVM] Cannot select photo to right: no active photo or at end")
            return
        }

        let rightPhoto = visible[currentIndex + 1]
        rightPhoto.isSelected = true
        activePhotoForNavigation = rightPhoto
        debugPrint("[PhotoGridVM] Selected photo to right: \(rightPhoto.fileName)")
    }

    /// Selects entire row below with Cmd+down arrow (rows of the filtered grid)
    func selectRowBelow() {
        let visible = filteredPhotos
        guard let activePhoto = activePhotoForNavigation,
              let currentIndex = visible.firstIndex(where: { $0.id == activePhoto.id }) else {
            debugPrint("[PhotoGridVM] Cannot select row below: no active photo")
            return
        }

        let currentRow = currentIndex / gridColumns
        let targetRow = currentRow + 1
        let startIndex = targetRow * gridColumns
        let endIndex = min(startIndex + gridColumns, visible.count)

        guard startIndex < visible.count else {
            debugPrint("[PhotoGridVM] Cannot select row below: already at last row")
            return
        }

        for i in startIndex..<endIndex {
            visible[i].isSelected = true
        }

        // Set active navigation point to the first photo in the new row
        activePhotoForNavigation = visible[startIndex]
        debugPrint("[PhotoGridVM] Selected row \(targetRow) with \(endIndex - startIndex) photos")
    }

    /// Selects entire row above with Cmd+up arrow (rows of the filtered grid)
    func selectRowAbove() {
        let visible = filteredPhotos
        guard let activePhoto = activePhotoForNavigation,
              let currentIndex = visible.firstIndex(where: { $0.id == activePhoto.id }) else {
            debugPrint("[PhotoGridVM] Cannot select row above: no active photo")
            return
        }

        let currentRow = currentIndex / gridColumns
        let targetRow = currentRow - 1

        guard targetRow >= 0 else {
            debugPrint("[PhotoGridVM] Cannot select row above: already at first row")
            return
        }

        let startIndex = targetRow * gridColumns
        let endIndex = min(startIndex + gridColumns, visible.count)

        for i in startIndex..<endIndex {
            visible[i].isSelected = true
        }

        // Set active navigation point to the first photo in the new row
        activePhotoForNavigation = visible[startIndex]
        debugPrint("[PhotoGridVM] Selected row \(targetRow) with \(endIndex - startIndex) photos")
    }

    /// Navigates to the previous photo (in filtered order)
    func previousPhoto() {
        guard let current = selectedPhoto,
              let target = neighborPhoto(of: current, forward: false) else {
            return
        }
        selectedPhoto = target
        debugPrint("[PhotoGridVM] Previous photo: \(target.fileName)")
        loadFullImage(for: target)
    }

    /// Navigates to the next photo (in filtered order)
    func nextPhoto() {
        guard let current = selectedPhoto,
              let target = neighborPhoto(of: current, forward: true) else {
            return
        }
        selectedPhoto = target
        debugPrint("[PhotoGridVM] Next photo: \(target.fileName)")
        loadFullImage(for: target)
    }

    /// Returns the neighbor of a photo in the filtered list. When the current
    /// photo just dropped out of the filter (e.g. flagged Reject while the
    /// Pick filter is active), falls back to the nearest photo still visible.
    func neighborPhoto(of photo: PhotoItem, forward: Bool) -> PhotoItem? {
        let visible = filteredPhotos
        if let index = visible.firstIndex(where: { $0.id == photo.id }) {
            let target = forward ? index + 1 : index - 1
            guard visible.indices.contains(target) else { return nil }
            return visible[target]
        }
        // Current photo is no longer visible: walk the unfiltered order to
        // find the closest photo that is still in the filtered set.
        guard let position = photos.firstIndex(where: { $0.id == photo.id }) else { return nil }
        let visibleIDs = Set(visible.map { $0.id })
        let searchRange = forward
            ? Array(photos[(position + 1)...])
            : photos[..<position].reversed().map { $0 }
        return searchRange.first(where: { visibleIDs.contains($0.id) })
    }
    
    /// Sets the flag of the currently selected photo to Pick
    func setFlagPick() {
        guard let photo = selectedPhoto else {
            debugPrint("[PhotoGridVM] Cannot set flag: no photo selected")
            return
        }
        photo.updateFlag(.pick)
        debugPrint("[PhotoGridVM] Set flag to Pick for: \(photo.fileName)")
    }
    
    /// Sets the flag of the currently selected photo to Reject
    func setFlagReject() {
        guard let photo = selectedPhoto else {
            debugPrint("[PhotoGridVM] Cannot set flag: no photo selected")
            return
        }
        photo.updateFlag(.rejected)
        debugPrint("[PhotoGridVM] Set flag to Reject for: \(photo.fileName)")
    }
    
    /// Sets the flag of the currently selected photo to Unflagged
    func setFlagUnflagged() {
        guard let photo = selectedPhoto else {
            debugPrint("[PhotoGridVM] Cannot set flag: no photo selected")
            return
        }
        photo.updateFlag(.unflagged)
        debugPrint("[PhotoGridVM] Set flag to Unflagged for: \(photo.fileName)")
    }
    
    /// Sets the star rating of the currently selected photo
    func setRating(_ rating: Int) {
        guard let photo = selectedPhoto else {
            debugPrint("[PhotoGridVM] Cannot set rating: no photo selected")
            return
        }
        // Toggle off if same rating, otherwise set new rating
        photo.updateRating(photo.rating == rating ? 0 : rating)
        debugPrint("[PhotoGridVM] Set rating to \(photo.rating) for: \(photo.fileName)")
    }
    
    /// Sets the color label of the currently selected photo
    func setColorLabel(_ label: ColorLabel) {
        guard let photo = selectedPhoto else {
            debugPrint("[PhotoGridVM] Cannot set color label: no photo selected")
            return
        }
        // Toggle off if same label, otherwise set new label
        photo.updateColorLabel(photo.colorLabel == label ? .none : label)
        debugPrint("[PhotoGridVM] Set color label to \(photo.colorLabel) for: \(photo.fileName)")
    }
    
    /// Clears the color label of the currently selected photo
    func clearColorLabel() {
        guard let photo = selectedPhoto else {
            debugPrint("[PhotoGridVM] Cannot clear color label: no photo selected")
            return
        }
        photo.updateColorLabel(.none)
        debugPrint("[PhotoGridVM] Cleared color label for: \(photo.fileName)")
    }
    
    /// Opens the current photo (viewer) or the selected photos (grid) in the
    /// default external editor associated with the file type.
    func openInExternalEditor() {
        let targets: [URL]
        if let selected = selectedPhoto {
            targets = [selected.url]
        } else {
            targets = photos.filter { $0.isSelected }.map { $0.url }
        }
        guard !targets.isEmpty else {
            debugPrint("[PhotoGridVM] Open in external editor: nothing selected")
            return
        }
        debugPrint("[PhotoGridVM] Opening \(targets.count) photo(s) in external editor")
        for url in targets {
            NSWorkspace.shared.open(url)
        }
    }

    /// Releases decoded full-quality images except for the current photo and
    /// its immediate neighbors, so long culling sessions don't accumulate
    /// hundreds of full-size decoded images in memory.
    private func purgeFullImages(keeping current: PhotoItem) {
        var keep: Set<UUID> = [current.id]
        if let prev = neighborPhoto(of: current, forward: false) { keep.insert(prev.id) }
        if let next = neighborPhoto(of: current, forward: true) { keep.insert(next.id) }

        for photo in photos where photo.fullImage != nil && !keep.contains(photo.id) {
            photo.fullImage = nil
        }
    }

    /// Loads full-quality image for non-RAW formats
    private func loadFullImage(for photo: PhotoItem) {
        purgeFullImages(keeping: photo)

        let fileExtension = photo.url.pathExtension.lowercased()
        
        // Skip loading full image for RAW formats (they're heavy to decode)
        guard !rawExtensions.contains(fileExtension) else {
            debugPrint("[PhotoGridVM] Skipping full image load for RAW format: \(photo.fileName)")
            return
        }
        
        // Skip if already loaded or loading
        guard photo.fullImage == nil && !photo.isLoadingFullImage else {
            debugPrint("[PhotoGridVM] Full image already loaded or loading for: \(photo.fileName)")
            return
        }
        
        photo.isLoadingFullImage = true
        debugPrint("[PhotoGridVM] Loading full image for non-RAW format: \(photo.fileName)")
        
        Task {
            let fullImage = await loadFullQualityImage(from: photo.url)
            await MainActor.run {
                photo.fullImage = fullImage
                photo.isLoadingFullImage = false
                debugPrint("[PhotoGridVM] Full image loaded for: \(photo.fileName)")
            }
        }
    }
    
    /// Loads full-quality image from a non-RAW file
    private func loadFullQualityImage(from url: URL) async -> NSImage? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            debugPrint("[PhotoGridVM] Failed to create image source for: \(url.lastPathComponent)")
            return nil
        }
        
        // Load full image without size limit
        let options: [CFString: Any] = [
            kCGImageSourceShouldCacheImmediately: true
        ]
        
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, options as CFDictionary) else {
            debugPrint("[PhotoGridVM] Failed to create full image for: \(url.lastPathComponent)")
            return nil
        }
        
        let nsImage = NSImage(cgImage: cgImage, size: .zero)
        debugPrint("[PhotoGridVM] Full image loaded for: \(url.lastPathComponent)")
        return nsImage
    }
    
    /// Result of the background per-photo loading work
    private struct PhotoLoadResult {
        let photoItem: PhotoItem
        let thumbnail: NSImage?
        let orientation: ImageOrientation
        let exif: EXIFMetadata?
        let xmp: XMPMetadata?
        let fileDate: Date?
    }

    /// Loads thumbnails and metadata (EXIF + XMP sidecar) for photo items.
    /// All file reads happen off the main thread; observable state is only
    /// mutated back on the main actor.
    private func loadThumbnails(for photoItems: [PhotoItem]) {
        debugPrint("[PhotoGridVM] Loading thumbnails for \(photoItems.count) photos")

        Task {
            let maxConcurrent = 4
            let chunks = photoItems.chunked(into: maxConcurrent)

            for chunk in chunks {
                await withTaskGroup(of: PhotoLoadResult.self) { group in
                    for photoItem in chunk {
                        let url = photoItem.url
                        group.addTask {
                            let (thumbnail, orientation) = await self.extractThumbnail(from: url)
                            let exif = PhotoItem.extractEXIFMetadata(from: url)
                            let xmp = XMPSidecar.read(for: url)
                            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
                            let fileDate = values?.creationDate ?? values?.contentModificationDate
                            return PhotoLoadResult(photoItem: photoItem, thumbnail: thumbnail, orientation: orientation, exif: exif, xmp: xmp, fileDate: fileDate)
                        }
                    }

                    for await result in group {
                        result.photoItem.thumbnail = result.thumbnail
                        result.photoItem.orientation = result.orientation
                        result.photoItem.isLoadingThumbnail = false
                        if let exif = result.exif {
                            result.photoItem.exif = exif
                        }
                        if let fileDate = result.fileDate {
                            result.photoItem.fileDate = fileDate
                        }
                        if let xmp = result.xmp {
                            result.photoItem.apply(xmp: xmp)
                        }
                    }
                }
            }

            isLoading = false
            debugPrint("[PhotoGridVM] Thumbnails loaded")
        }
    }
    
    /// Extracts JPEG preview thumbnail from a RAW file
    private func extractThumbnail(from url: URL) async -> (NSImage?, ImageOrientation) {
        debugPrint("[PhotoGridVM] Extracting thumbnail from: \(url.lastPathComponent)")
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            debugPrint("[PhotoGridVM] Failed to create image source for: \(url.lastPathComponent)")
            return (nil, .landscape)
        }
        
        // Extract orientation from EXIF metadata
        let orientation = extractOrientation(from: imageSource)
        
        // Create thumbnail with reduced size for faster loading (max 800px on longest side)
        let thumbnailSize: CGFloat = 800
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: false,
            kCGImageSourceThumbnailMaxPixelSize: thumbnailSize
        ]
        
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            debugPrint("[PhotoGridVM] Failed to create thumbnail for: \(url.lastPathComponent)")
            return (nil, orientation)
        }
        
        // Note: kCGImageSourceCreateThumbnailWithTransform applies EXIF rotation automatically
        // No need for manual rotation
        
        // Create NSImage from CGImage
        let nsImage = NSImage(cgImage: cgImage, size: .zero)
        debugPrint("[PhotoGridVM] Thumbnail extracted for: \(url.lastPathComponent) with orientation: \(orientation)")
        return (nsImage, orientation)
    }
    
    /// Applies EXIF orientation rotation to the image
    private func applyOrientation(to cgImage: CGImage, from imageSource: CGImageSource) -> CGImage {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any],
              let orientationValue = properties[kCGImagePropertyOrientation] as? Int else {
            return cgImage
        }
        
        // EXIF orientation values:
        // 1: Normal (0°)
        // 6: Rotate 90° CW
        // 8: Rotate 90° CCW
        switch orientationValue {
        case 6:
            // Rotate 90° counter-clockwise instead of clockwise
            return rotateImage(cgImage, degrees: -90)
        case 8:
            // Rotate 90° clockwise instead of counter-clockwise
            return rotateImage(cgImage, degrees: 90)
        case 3:
            // Rotate 180°
            return rotateImage(cgImage, degrees: 180)
        default:
            return cgImage
        }
    }
    
    /// Rotates a CGImage by specified degrees
    private func rotateImage(_ image: CGImage, degrees: Int) -> CGImage {
        let radians = CGFloat(degrees) * .pi / 180
        let destWidth = image.height
        let destHeight = image.width
        
        let context = CGContext(data: nil,
                                width: destWidth,
                                height: destHeight,
                                bitsPerComponent: image.bitsPerComponent,
                                bytesPerRow: 0,
                                space: image.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                bitmapInfo: image.bitmapInfo.rawValue)
        
        context?.translateBy(x: CGFloat(destWidth) / 2, y: CGFloat(destHeight) / 2)
        context?.rotate(by: radians)
        context?.translateBy(x: -CGFloat(image.width) / 2, y: -CGFloat(image.height) / 2)
        context?.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        
        return context?.makeImage() ?? image
    }
    
    /// Extracts image orientation from EXIF metadata
    private func extractOrientation(from imageSource: CGImageSource) -> ImageOrientation {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] else {
            return .landscape
        }
        
        // Get orientation from EXIF (standard value 1-8)
        if let orientationValue = properties[kCGImagePropertyOrientation] as? Int {
            // EXIF orientation values:
            // 1: Normal (landscape)
            // 6: Rotate 90° CW (portrait)
            // 8: Rotate 90° CCW (portrait)
            switch orientationValue {
            case 6, 8:
                return .portrait
            default:
                return .landscape
            }
        }
        
        // Fallback to image dimensions
        if let width = properties[kCGImagePropertyPixelWidth] as? Int,
           let height = properties[kCGImagePropertyPixelHeight] as? Int {
            if height > width {
                return .portrait
            }
        }
        
        return .landscape
    }
}

// MARK: - Sort Key

enum SortKey: String, CaseIterable, Identifiable {
    case name
    case date
    case rating

    var id: String { rawValue }

    var label: String {
        switch self {
        case .name: return "Nom"
        case .date: return "Date"
        case .rating: return "Note"
        }
    }
}
