//
//  FolderItem.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import Foundation

/// Represents a folder in the file system tree
@Observable
final class FolderItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let name: String
    var subfolders: [FolderItem] = []
    var photoCount: Int = 0
    var isExpanded: Bool = false
    
    init(url: URL, name: String) {
        self.url = url
        self.name = name
        debugPrint("[FolderItem] Created folder item: \(name) at \(url.path)")
    }
    
    // MARK: - Hashable
    
    static func == (lhs: FolderItem, rhs: FolderItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
