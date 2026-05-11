//
//  PhotoGridVM.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import Foundation
import AppKit
import ImageIO

/// View model for managing photo grid display
@Observable
@MainActor
final class PhotoGridVM {
    
    // MARK: - State
    
    var photos: [PhotoItem] = []
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
    
    /// Loads thumbnails for photo items
    private func loadThumbnails(for photoItems: [PhotoItem]) {
        debugPrint("[PhotoGridVM] Loading thumbnails for \(photoItems.count) photos")
        
        Task {
            await withTaskGroup(of: (PhotoItem, NSImage?).self) { group in
                for photoItem in photoItems {
                    group.addTask {
                        let thumbnail = await self.extractThumbnail(from: photoItem.url)
                        return (photoItem, thumbnail)
                    }
                }
                
                for await (photoItem, thumbnail) in group {
                    photoItem.thumbnail = thumbnail
                    photoItem.isLoadingThumbnail = false
                }
            }
            
            isLoading = false
            debugPrint("[PhotoGridVM] Thumbnails loaded")
        }
    }
    
    /// Extracts JPEG preview thumbnail from a RAW file
    private func extractThumbnail(from url: URL) async -> NSImage? {
        debugPrint("[PhotoGridVM] Extracting thumbnail from: \(url.lastPathComponent)")
        
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            debugPrint("[PhotoGridVM] Failed to create image source for: \(url.lastPathComponent)")
            return nil
        }
        
        // Get the image at index 0 (first image in the file)
        guard let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            debugPrint("[PhotoGridVM] Failed to create CGImage for: \(url.lastPathComponent)")
            return nil
        }
        
        // Create NSImage from CGImage
        let nsImage = NSImage(cgImage: cgImage, size: .zero)
        debugPrint("[PhotoGridVM] Thumbnail extracted for: \(url.lastPathComponent)")
        return nsImage
    }
}
