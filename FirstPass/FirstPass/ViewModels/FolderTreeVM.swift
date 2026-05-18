//
//  FolderTreeVM.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import Foundation
import AppKit

/// View model for managing the folder tree structure
@Observable
@MainActor
final class FolderTreeVM {
    
    // MARK: - State
    
    var rootFolder: FolderItem?
    var selectedFolder: FolderItem?
    var errorMessage: String?
    private var securityScopedBookmark: Data?
    private var currentFolderURL: URL?
    weak var photoGridVM: PhotoGridVM?
    
    // MARK: - UserDefaults Keys
    
    private let bookmarkKey = "lastFolderBookmark"
    
    // MARK: - Supported image extensions
    
    private let imageExtensions: Set<String> = [
        "cr3", "cr2", "arw", "nef", "raf", "rw2", "orf", "dng", "raw",
        "heic", "jpg", "jpeg", "tif", "tiff"
    ]
    
    // MARK: - Initialization
    
    init(photoGridVM: PhotoGridVM? = nil) {
        self.photoGridVM = photoGridVM
        debugPrint("[FolderTreeVM] Initialized")
        
        // Try to restore last opened folder
        restoreLastFolder()
    }
    
    // MARK: - Public Methods
    
    /// Opens a folder picker and loads the selected folder
    func openFolder() {
        debugPrint("[FolderTreeVM] Opening folder picker")
        
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        panel.begin { [weak self] response in
            guard let self = self else { return }
            
            if response == .OK, let url = panel.url {
                debugPrint("[FolderTreeVM] Folder selected: \(url.path)")
                self.loadFolder(at: url)
            } else {
                debugPrint("[FolderTreeVM] Folder selection cancelled")
            }
        }
    }
    
    /// Loads a folder and its subfolders
    func loadFolder(at url: URL) {
        debugPrint("[FolderTreeVM] Loading folder at: \(url.path)")
        
        // Clear any previous error
        errorMessage = nil
        
        // Stop accessing previous folder if any
        if let previousURL = currentFolderURL {
            debugPrint("[FolderTreeVM] Stopping access to previous folder: \(previousURL.path)")
            previousURL.stopAccessingSecurityScopedResource()
        }
        
        // Request security-scoped bookmark access and keep it alive
        let accessing = url.startAccessingSecurityScopedResource()
        if !accessing {
            debugPrint("[FolderTreeVM] Warning: Failed to start accessing security-scoped resource")
        }
        currentFolderURL = url
        
        // Create root folder item
        let rootName = url.lastPathComponent
        let rootFolder = FolderItem(url: url, name: rootName)
        
        // Scan folder structure
        scanFolder(url, into: rootFolder)
        
        // Calculate total photos including subfolders
        let totalPhotos = calculateTotalPhotos(in: rootFolder)
        
        // Validate that folder contains photos
        if totalPhotos == 0 {
            errorMessage = "Ce dossier ne contient aucune photo. Veuillez sélectionner un dossier avec des fichiers RAW, JPEG ou TIFF."
            debugPrint("[FolderTreeVM] Error: No photos found in folder")
            // Stop accessing since we're not keeping this folder
            url.stopAccessingSecurityScopedResource()
            currentFolderURL = nil
            return
        }
        
        self.rootFolder = rootFolder
        self.selectedFolder = rootFolder
        
        // Save the bookmark for persistence
        saveFolderBookmark(for: url)
        
        debugPrint("[FolderTreeVM] Folder loaded with \(rootFolder.subfolders.count) subfolders and \(totalPhotos) total photos")
    }
    
    /// Toggles the expanded state of a folder
    func toggleExpansion(_ folder: FolderItem) {
        folder.isExpanded.toggle()
        debugPrint("[FolderTreeVM] Toggled expansion for folder: \(folder.name)")
    }
    
    /// Selects a folder
    func selectFolder(_ folder: FolderItem) {
        selectedFolder = folder
        debugPrint("[FolderTreeVM] Selected folder: \(folder.name) with \(folder.photoCount) photos")
        
        // Load photos in the grid view
        photoGridVM?.loadPhotos(from: folder.url)
    }
    
    // MARK: - Private Methods
    
    /// Saves the security-scoped bookmark for the folder
    private func saveFolderBookmark(for url: URL) {
        debugPrint("[FolderTreeVM] Saving bookmark for folder: \(url.path)")
        
        do {
            let bookmark = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            securityScopedBookmark = bookmark
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
            debugPrint("[FolderTreeVM] Bookmark saved successfully")
        } catch {
            debugPrint("[FolderTreeVM] Error saving bookmark: \(error.localizedDescription)")
        }
    }
    
    /// Restores the last opened folder from the saved bookmark
    private func restoreLastFolder() {
        debugPrint("[FolderTreeVM] Attempting to restore last folder")
        
        guard let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) else {
            debugPrint("[FolderTreeVM] No saved bookmark found")
            return
        }
        
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            
            if isStale {
                debugPrint("[FolderTreeVM] Bookmark is stale, clearing it")
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
                return
            }
            
            debugPrint("[FolderTreeVM] Restoring folder from bookmark: \(url.path)")
            loadFolder(at: url)
            
        } catch {
            debugPrint("[FolderTreeVM] Error restoring bookmark: \(error.localizedDescription)")
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
        }
    }
    
    /// Calculates total photos in a folder and all its subfolders
    private func calculateTotalPhotos(in folder: FolderItem) -> Int {
        var total = folder.photoCount
        for subfolder in folder.subfolders {
            total += calculateTotalPhotos(in: subfolder)
        }
        return total
    }
    
    /// Recursively scans a folder to find subfolders and count photos
    private func scanFolder(_ url: URL, into folderItem: FolderItem) {
        debugPrint("[FolderTreeVM] Scanning folder: \(url.path)")
        
        do {
            let fileManager = FileManager.default
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .nameKey], options: [.skipsHiddenFiles])
            
            for fileURL in contents {
                // Check if it's a directory
                let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                
                if let isDirectory = resourceValues.isDirectory, isDirectory {
                    // It's a subfolder - add to tree and recurse
                    let subfolderName = fileURL.lastPathComponent
                    let subfolder = FolderItem(url: fileURL, name: subfolderName)
                    scanFolder(fileURL, into: subfolder)
                    folderItem.subfolders.append(subfolder)
                    debugPrint("[FolderTreeVM] Added subfolder: \(subfolderName)")
                } else {
                    // It's a file - check if it's an image
                    let fileExtension = fileURL.pathExtension.lowercased()
                    if imageExtensions.contains(fileExtension) {
                        folderItem.photoCount += 1
                    }
                }
            }
            
            // Sort subfolders alphabetically
            folderItem.subfolders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            
            debugPrint("[FolderTreeVM] Folder scan complete: \(folderItem.name) - \(folderItem.subfolders.count) subfolders, \(folderItem.photoCount) photos")
            
        } catch {
            debugPrint("[FolderTreeVM] Error scanning folder \(url.path): \(error.localizedDescription)")
        }
    }
    
    /// Creates a new folder in the current directory and optionally moves selected photos into it
    /// - Parameters:
    ///   - folderName: The name of the new folder to create
    ///   - photoURLs: URLs of the photos to move (if includeSelectedPhotos is true)
    ///   - includeSelectedPhotos: If true, moves all photos to the new folder
    /// - Returns: URL of the created folder, or nil if failed
    @discardableResult
    func createFolderAndMovePhotos(folderName: String, photoURLs: [URL], includeSelectedPhotos: Bool) -> URL? {
        debugPrint("[FolderTreeVM] Creating folder: \(folderName), include photos: \(includeSelectedPhotos)")
        
        guard !photoURLs.isEmpty else {
            debugPrint("[FolderTreeVM] No photos provided, cannot create folder")
            return nil
        }
        
        // Derive the parent directory directly from the first photo's URL
        // This is always reliable regardless of selectedFolder state
        let parentURL = photoURLs[0].deletingLastPathComponent()
        debugPrint("[FolderTreeVM] Parent directory for new folder: \(parentURL.path)")
        
        let fileManager = FileManager.default
        let newFolderURL = parentURL.appendingPathComponent(folderName)
        
        // Check if folder already exists
        if fileManager.fileExists(atPath: newFolderURL.path) {
            debugPrint("[FolderTreeVM] Folder already exists at: \(newFolderURL.path)")
            return nil
        }
        
        do {
            // Create the new folder
            try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: false, attributes: nil)
            debugPrint("[FolderTreeVM] Created folder at: \(newFolderURL.path)")
            
            // Move photos if requested
            if includeSelectedPhotos {
                var movedCount = 0
                for photoURL in photoURLs {
                    let fileName = photoURL.lastPathComponent
                    let destinationURL = newFolderURL.appendingPathComponent(fileName)
                    
                    // Also move XMP sidecar if it exists
                    let xmpSourceURL = photoURL.deletingPathExtension().appendingPathExtension("xmp")
                    let xmpDestinationURL = newFolderURL.appendingPathComponent(xmpSourceURL.lastPathComponent)
                    
                    do {
                        // Move the photo file
                        try fileManager.moveItem(at: photoURL, to: destinationURL)
                        debugPrint("[FolderTreeVM] Moved photo: \(fileName) to new folder")
                        
                        // Move XMP sidecar if it exists
                        if fileManager.fileExists(atPath: xmpSourceURL.path) {
                            try fileManager.moveItem(at: xmpSourceURL, to: xmpDestinationURL)
                            debugPrint("[FolderTreeVM] Moved XMP sidecar for: \(fileName)")
                        }
                        
                        movedCount += 1
                    } catch {
                        debugPrint("[FolderTreeVM] Error moving photo \(fileName): \(error.localizedDescription)")
                    }
                }
                debugPrint("[FolderTreeVM] Moved \(movedCount)/\(photoURLs.count) photos to new folder")
            }
            
            return newFolderURL
        } catch {
            debugPrint("[FolderTreeVM] Error creating folder: \(error.localizedDescription)")
            return nil
        }
    }
}
