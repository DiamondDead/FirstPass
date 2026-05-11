//
//  PhotoItem.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import Foundation
import AppKit

/// Represents a photo file with its preview thumbnail
@Observable
final class PhotoItem: Identifiable, Hashable {
    let id = UUID()
    let url: URL
    let fileName: String
    var thumbnail: NSImage?
    var isLoadingThumbnail: Bool = false
    
    // Metadata
    var flag: Flag = .unflagged
    var rating: Int = 0
    var colorLabel: ColorLabel = .none
    
    init(url: URL, fileName: String) {
        self.url = url
        self.fileName = fileName
        debugPrint("[PhotoItem] Created photo item: \(fileName) at \(url.path)")
    }
    
    // MARK: - Hashable
    
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - Flag Enum

enum Flag: String, CaseIterable {
    case unflagged = "U"
    case pick = "P"
    case rejected = "X"
}

// MARK: - Color Label Enum

enum ColorLabel: String, CaseIterable {
    case none = "None"
    case red = "Red"
    case yellow = "Yellow"
    case green = "Green"
    case blue = "Blue"
    case purple = "Purple"
}
