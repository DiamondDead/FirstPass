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
    var isLoading: Bool = false
    var errorMessage: String?
    
    // MARK: - Supported image extensions
    
    private let imageExtensions: Set<String> = [
        "cr3", "cr2", "arw", "nef", "raf", "rw2", "orf", "dng", "raw",
        "heic", "jpg", "jpeg", "tif", "tiff"
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
        
        // Request security-scoped bookmark access
        let accessing = folderURL.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                folderURL.stopAccessingSecurityScopedResource()
            }
        }
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
            
            // Filter for image files only
            let imageFiles = contents.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return imageExtensions.contains(fileExtension)
            }
            
            debugPrint("[PhotoGridVM] Found \(imageFiles.count) image files")
            
            // Create photo items
            var photoItems: [PhotoItem] = []
            for fileURL in imageFiles {
                let photoItem = PhotoItem(url: fileURL, fileName: fileURL.lastPathComponent)
                photoItems.append(photoItem)
            }
            
            // Sort alphabetically
            photoItems.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
            
            self.photos = photoItems
            
            // Load thumbnails asynchronously
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
    }
    
    /// Deselects the current photo
    func deselectPhoto() {
        selectedPhoto = nil
        debugPrint("[PhotoGridVM] Deselected photo")
    }
    
    /// Navigates to the previous photo
    func previousPhoto() {
        guard let current = selectedPhoto,
              let currentIndex = photos.firstIndex(where: { $0.id == current.id }),
              currentIndex > 0 else {
            return
        }
        selectedPhoto = photos[currentIndex - 1]
        debugPrint("[PhotoGridVM] Previous photo: \(selectedPhoto?.fileName ?? "none")")
    }
    
    /// Navigates to the next photo
    func nextPhoto() {
        guard let current = selectedPhoto,
              let currentIndex = photos.firstIndex(where: { $0.id == current.id }),
              currentIndex < photos.count - 1 else {
            return
        }
        selectedPhoto = photos[currentIndex + 1]
        debugPrint("[PhotoGridVM] Next photo: \(selectedPhoto?.fileName ?? "none")")
    }
    
    /// Loads thumbnails for photo items
    private func loadThumbnails(for photoItems: [PhotoItem]) {
        debugPrint("[PhotoGridVM] Loading thumbnails for \(photoItems.count) photos")
        
        Task {
            let maxConcurrent = 4
            let chunks = photoItems.chunked(into: maxConcurrent)
            
            for chunk in chunks {
                await withTaskGroup(of: (PhotoItem, NSImage?, ImageOrientation).self) { group in
                    for photoItem in chunk {
                        group.addTask {
                            let (thumbnail, orientation) = await self.extractThumbnail(from: photoItem.url)
                            return (photoItem, thumbnail, orientation)
                        }
                    }
                    
                    for await (photoItem, thumbnail, orientation) in group {
                        photoItem.thumbnail = thumbnail
                        photoItem.orientation = orientation
                        photoItem.isLoadingThumbnail = false
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
