//
//  PhotoItem.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import Foundation
import AppKit
import ImageIO

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
    let url: URL
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
    
    /// Loads EXIF metadata from the image file
    func loadEXIFMetadata() {
        guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            debugPrint("[PhotoItem] Failed to load EXIF metadata for: \(fileName)")
            return
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
        
        self.exif = metadata
        debugPrint("[PhotoItem] Loaded EXIF metadata for: \(fileName)")
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
