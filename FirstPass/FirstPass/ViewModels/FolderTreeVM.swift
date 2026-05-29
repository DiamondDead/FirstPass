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
    // Transient error shown when creating a new folder fails (presented as an alert, not the sidebar error state)
    var creationError: String?
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
        debugPrint("[FolderTreeVM] Creating folder: \(folderName), include photos: \(includeSelectedPhotos), selected: \(photoURLs.count)")
        creationError = nil
        
        // The new folder is created inside the currently selected folder (fallback: root)
        guard let parentFolder = selectedFolder ?? rootFolder else {
            debugPrint("[FolderTreeVM] No parent folder available, cannot create folder")
            creationError = "Aucun dossier ouvert. Ouvrez un dossier avant de créer un sous-dossier."
            return nil
        }
        
        // Validate the requested name
        let trimmedName = folderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            debugPrint("[FolderTreeVM] Empty folder name, aborting")
            creationError = "Le nom du dossier ne peut pas être vide."
            return nil
        }
        
        let parentURL = parentFolder.url
        let fileManager = FileManager.default
        let newFolderURL = parentURL.appendingPathComponent(trimmedName, isDirectory: true)
        debugPrint("[FolderTreeVM] Parent directory for new folder: \(parentURL.path)")
        
        // Check if folder already exists
        if fileManager.fileExists(atPath: newFolderURL.path) {
            debugPrint("[FolderTreeVM] Folder already exists at: \(newFolderURL.path)")
            creationError = "Un dossier nommé « \(trimmedName) » existe déjà."
            return nil
        }
        
        do {
            // Create the new folder on disk
            try fileManager.createDirectory(at: newFolderURL, withIntermediateDirectories: false, attributes: nil)
            debugPrint("[FolderTreeVM] Created folder at: \(newFolderURL.path)")
            
            // Move photos (and their XMP sidecars) if requested
            var movedCount = 0
            if includeSelectedPhotos {
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
            
            // Update the in-memory tree so the sidebar shows the new subfolder right away
            let newFolderItem = FolderItem(url: newFolderURL, name: trimmedName)
            scanFolder(newFolderURL, into: newFolderItem) // populates photoCount / subfolders
            parentFolder.subfolders.append(newFolderItem)
            parentFolder.subfolders.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            parentFolder.isExpanded = true // reveal the freshly created folder
            // The moved photos no longer live directly in the parent folder
            parentFolder.photoCount = max(0, parentFolder.photoCount - movedCount)
            debugPrint("[FolderTreeVM] Tree updated: added \(trimmedName) under \(parentFolder.name)")
            
            return newFolderURL
        } catch {
            debugPrint("[FolderTreeVM] Error creating folder: \(error.localizedDescription)")
            creationError = "Échec de la création du dossier : \(error.localizedDescription)"
            return nil
        }
    }
    
    // MARK: - Tree Refresh & Photo Move
    
    /// Re-scans the open folder tree from disk, preserving expansion and selection.
    /// Use after external changes or moving files to update photo counts and subfolders.
    func refreshTree() {
        guard let rootURL = rootFolder?.url ?? currentFolderURL else {
            debugPrint("[FolderTreeVM] refreshTree: no folder open, nothing to refresh")
            return
        }
        debugPrint("[FolderTreeVM] Refreshing tree from: \(rootURL.path)")
        
        // Capture current UI state so it survives the rebuild
        var expandedURLs = Set<URL>()
        if let root = rootFolder { collectExpandedURLs(root, into: &expandedURLs) }
        let selectedURL = selectedFolder?.url
        
        // Rebuild the tree from disk
        let newRoot = FolderItem(url: rootURL, name: rootURL.lastPathComponent)
        scanFolder(rootURL, into: newRoot)
        
        // Restore expansion state by URL, then publish the new tree
        restoreExpansion(newRoot, expandedURLs: expandedURLs)
        rootFolder = newRoot
        
        // Restore selection (fallback to root) and reload its photos in the grid
        let target = selectedURL.flatMap { findFolder(in: newRoot, matching: $0) } ?? newRoot
        selectedFolder = target
        photoGridVM?.loadPhotos(from: target.url)
        debugPrint("[FolderTreeVM] Tree refreshed, selected: \(target.name)")
    }
    
    /// Moves photos (and their XMP sidecars) into the destination folder, then refreshes the tree.
    /// - Parameters:
    ///   - photoURLs: Source photo file URLs to move
    ///   - destination: The folder the photos should be moved into
    func movePhotos(_ photoURLs: [URL], to destination: FolderItem) {
        guard !photoURLs.isEmpty else {
            debugPrint("[FolderTreeVM] movePhotos: no photos to move")
            return
        }
        debugPrint("[FolderTreeVM] Moving \(photoURLs.count) photo(s) to: \(destination.name)")
        creationError = nil
        
        let fileManager = FileManager.default
        let destURL = destination.url
        var movedCount = 0
        var skipped = 0
        
        for photoURL in photoURLs {
            // Skip photos already located in the destination folder
            if photoURL.deletingLastPathComponent().standardizedFileURL == destURL.standardizedFileURL {
                debugPrint("[FolderTreeVM] Skipping \(photoURL.lastPathComponent): already in destination")
                continue
            }
            
            let destinationURL = destURL.appendingPathComponent(photoURL.lastPathComponent)
            
            // Don't overwrite an existing file at the destination
            if fileManager.fileExists(atPath: destinationURL.path) {
                debugPrint("[FolderTreeVM] Skipping \(photoURL.lastPathComponent): already exists in destination")
                skipped += 1
                continue
            }
            
            do {
                try fileManager.moveItem(at: photoURL, to: destinationURL)
                debugPrint("[FolderTreeVM] Moved \(photoURL.lastPathComponent) to \(destination.name)")
                
                // Move the XMP sidecar too, if present
                let xmpSourceURL = photoURL.deletingPathExtension().appendingPathExtension("xmp")
                if fileManager.fileExists(atPath: xmpSourceURL.path) {
                    let xmpDestURL = destURL.appendingPathComponent(xmpSourceURL.lastPathComponent)
                    try? fileManager.moveItem(at: xmpSourceURL, to: xmpDestURL)
                    debugPrint("[FolderTreeVM] Moved XMP sidecar for \(photoURL.lastPathComponent)")
                }
                movedCount += 1
            } catch {
                debugPrint("[FolderTreeVM] Error moving \(photoURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        debugPrint("[FolderTreeVM] Move complete: \(movedCount) moved, \(skipped) skipped")
        
        if skipped > 0 {
            creationError = "\(skipped) photo(s) n'ont pas pu être déplacées (un fichier du même nom existe déjà)."
        }
        
        // Refresh counts and grid only if something actually changed
        if movedCount > 0 {
            refreshTree()
        }
    }
    
    // MARK: - Tree Helpers
    
    /// Collects the URLs of all expanded folders in the tree.
    private func collectExpandedURLs(_ folder: FolderItem, into set: inout Set<URL>) {
        if folder.isExpanded { set.insert(folder.url) }
        for sub in folder.subfolders { collectExpandedURLs(sub, into: &set) }
    }
    
    /// Restores the expanded state on a freshly scanned tree using captured URLs.
    private func restoreExpansion(_ folder: FolderItem, expandedURLs: Set<URL>) {
        folder.isExpanded = expandedURLs.contains(folder.url)
        for sub in folder.subfolders { restoreExpansion(sub, expandedURLs: expandedURLs) }
    }
    
    /// Finds a folder in the tree matching the given URL.
    private func findFolder(in folder: FolderItem, matching url: URL) -> FolderItem? {
        if folder.url.standardizedFileURL == url.standardizedFileURL { return folder }
        for sub in folder.subfolders {
            if let match = findFolder(in: sub, matching: url) { return match }
        }
        return nil
    }
}
