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
    
    // MARK: - Supported image extensions
    
    private let imageExtensions: Set<String> = [
        "cr3", "cr2", "arw", "nef", "raf", "rw2", "orf", "dng", "raw",
        "heic", "jpg", "jpeg", "tif", "tiff"
    ]
    
    // MARK: - Initialization
    
    init() {
        debugPrint("[FolderTreeVM] Initialized")
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
        
        // Request security-scoped bookmark access
        let accessing = url.startAccessingSecurityScopedResource()
        defer {
            if accessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
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
            return
        }
        
        self.rootFolder = rootFolder
        self.selectedFolder = rootFolder
        
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
    }
    
    // MARK: - Private Methods
    
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
}
