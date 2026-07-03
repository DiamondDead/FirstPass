//
//  PhotoItem.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import Foundation
import AppKit
import ImageIO
import SwiftUI

// MARK: - Image Orientation Enum

enum ImageOrientation {
    case portrait
    case landscape
}

// MARK: - EXIF Metadata

struct EXIFMetadata {
    var camera: String = ""
    var lens: String = ""
    var focalLength: String = ""
    var aperture: String = ""
    var shutterSpeed: String = ""
    var iso: String = ""
    var date: String = ""
}

/// Represents a photo file with its preview thumbnail
@Observable
final class PhotoItem: Identifiable, Hashable {
    let id = UUID()
    var url: URL
    let fileName: String
    var thumbnail: NSImage?
    var fullImage: NSImage?
    var isLoadingThumbnail: Bool = false
    var isLoadingFullImage: Bool = false
    var orientation: ImageOrientation = .landscape
    
    // Selection state for multi-select
    var isSelected: Bool = false
    
    // Metadata
    var flag: Flag = .unflagged
    var rating: Int = 0
    var colorLabel: ColorLabel = .none
    var exif: EXIFMetadata = EXIFMetadata()
    
    init(url: URL, fileName: String) {
        self.url = url
        self.fileName = fileName
        debugPrint("[PhotoItem] Created photo item: \(fileName) at \(url.path)")
    }
    
    // MARK: - XMP Metadata Persistence
    
    /// Applies rating / color label / flag read from an XMP sidecar.
    /// The read itself (`XMPSidecar.read`) is pure and can run off the main
    /// thread; this application must happen where the UI observes the item.
    func apply(xmp meta: XMPMetadata) {
        if let r = meta.rating, (0...5).contains(r) {
            rating = r
        }
        if let label = meta.label, let mapped = ColorLabel(xmpLabel: label) {
            colorLabel = mapped
        }
        if let pick = meta.pick {
            switch pick {
            case 1: flag = .pick
            case -1: flag = .rejected
            default: flag = .unflagged
            }
        }
        debugPrint("[PhotoItem] Loaded XMP for \(fileName): rating=\(rating), label=\(colorLabel.rawValue), flag=\(flag.rawValue)")
    }
    
    /// Writes the current rating / color label / flag to the XMP sidecar,
    /// preserving any other metadata already present in the file.
    func persistMetadata() {
        XMPSidecar.write(rating: rating, label: colorLabel, flag: flag, for: url)
    }
    
    // MARK: - Mutations (mutate + persist)
    
    /// Updates the star rating and persists it to the XMP sidecar.
    func updateRating(_ newRating: Int) {
        rating = newRating
        persistMetadata()
    }
    
    /// Updates the pick/reject flag and persists it to the XMP sidecar.
    func updateFlag(_ newFlag: Flag) {
        flag = newFlag
        persistMetadata()
    }
    
    /// Updates the color label and persists it to the XMP sidecar.
    func updateColorLabel(_ newLabel: ColorLabel) {
        colorLabel = newLabel
        persistMetadata()
    }
    
    /// Reads EXIF metadata from an image file. Pure function, safe to call
    /// from a background task — assign the result to `exif` on the main actor.
    nonisolated static func extractEXIFMetadata(from url: URL) -> EXIFMetadata? {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            debugPrint("[PhotoItem] Failed to load EXIF metadata for: \(url.lastPathComponent)")
            return nil
        }
        
        var metadata = EXIFMetadata()
        
        // Extract EXIF data
        if let exifDict = properties["{Exif}"] as? [String: Any] {
            // Camera make and model
            let make = exifDict["Make"] as? String ?? ""
            let model = exifDict["Model"] as? String ?? ""
            metadata.camera = make.isEmpty ? model : "\(make) \(model)"
            
            // Lens model
            if let lensModel = exifDict["LensModel"] as? String {
                metadata.lens = lensModel
            }
            
            // Focal length
            if let focalLength = exifDict["FocalLength"] as? Double {
                metadata.focalLength = String(format: "%.0fmm", focalLength)
            }
            
            // F-number (aperture)
            if let fNumber = exifDict["FNumber"] as? Double {
                metadata.aperture = String(format: "f/%.1f", fNumber)
            }
            
            // Exposure time (shutter speed)
            if let exposureTime = exifDict["ExposureTime"] as? Double {
                if exposureTime >= 1 {
                    metadata.shutterSpeed = String(format: "%.1fs", exposureTime)
                } else {
                    metadata.shutterSpeed = String(format: "1/%.0fs", 1.0 / exposureTime)
                }
            }
            
            // ISO
            if let iso = exifDict["ISOSpeedRatings"] as? [Int], let isoValue = iso.first {
                metadata.iso = String(isoValue)
            }
        }
        
        // Extract TIFF data for date
        if let tiffDict = properties["{TIFF}"] as? [String: Any],
           let dateTime = tiffDict["DateTime"] as? String {
            // Format date from "2024:02:15 14:30:45" to "15/02/2024"
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            if let date = dateFormatter.date(from: dateTime) {
                dateFormatter.dateFormat = "dd/MM/yyyy"
                metadata.date = dateFormatter.string(from: date)
            }
        }
        
        debugPrint("[PhotoItem] Loaded EXIF metadata for: \(url.lastPathComponent)")
        return metadata
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
    
    /// Display color for the label (single source of truth for all views).
    var color: Color {
        switch self {
        case .none: return .gray
        case .red: return Color(red: 1.0, green: 0.2, blue: 0.2)
        case .yellow: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case .green: return Color(red: 0.2, green: 0.8, blue: 0.4)
        case .blue: return Color(red: 0.2, green: 0.6, blue: 1.0)
        case .purple: return Color(red: 0.6, green: 0.4, blue: 1.0)
        }
    }

    /// Maps an Adobe `xmp:Label` string to a color label (case-insensitive).
    /// Returns nil for unknown / custom labels so they don't override state.
    init?(xmpLabel: String) {
        switch xmpLabel.lowercased() {
        case "red": self = .red
        case "yellow": self = .yellow
        case "green": self = .green
        case "blue": self = .blue
        case "purple": self = .purple
        default: return nil
        }
    }
}
