//
//  XMPSidecar.swift
//  FirstPass
//
//  Reads and writes Adobe-standard XMP sidecar files for photos.
//  Only three fields are managed: star rating (xmp:Rating), color label
//  (xmp:Label) and the pick flag (lr:pick = 1 / -1 / 0). Any other metadata
//  already present in an external sidecar (e.g. Lightroom / Camera Raw) is
//  preserved when updating.
//

import Foundation

/// The three pieces of metadata we read from / write to an XMP sidecar.
struct XMPMetadata {
    var rating: Int?
    var label: String?
    var pick: Int?
}

/// Stateless helper for Adobe XMP sidecar read / write.
enum XMPSidecar {
    
    // MARK: - Namespaces
    
    private static let nsX = "adobe:ns:meta/"
    private static let nsRDF = "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
    private static let nsXMP = "http://ns.adobe.com/xap/1.0/"
    private static let nsLR = "http://ns.adobe.com/lightroom/1.0/"
    
    // MARK: - Sidecar URL
    
    /// Returns the sidecar URL for a photo (e.g. `IMG_0001.CR3` -> `IMG_0001.xmp`).
    nonisolated static func sidecarURL(for photoURL: URL) -> URL {
        photoURL.deletingPathExtension().appendingPathExtension("xmp")
    }
    
    // MARK: - Reading
    
    /// Reads rating / label / pick from a photo's sidecar, if it exists.
    /// Handles both attribute style (`xmp:Rating="4"`) and element style
    /// (`<xmp:Rating>4</xmp:Rating>`) so external files are supported.
    nonisolated static func read(for photoURL: URL) -> XMPMetadata? {
        let xmpURL = sidecarURL(for: photoURL)
        guard let text = try? String(contentsOf: xmpURL, encoding: .utf8) else {
            return nil
        }
        
        var meta = XMPMetadata()
        if let r = value(in: text, property: "xmp:Rating") {
            meta.rating = Int(r.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let l = value(in: text, property: "xmp:Label") {
            meta.label = l.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let p = value(in: text, property: "lr:pick") {
            meta.pick = Int(p.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        debugPrint("[XMPSidecar] Read \(xmpURL.lastPathComponent): rating=\(meta.rating?.description ?? "nil"), label=\(meta.label ?? "nil"), pick=\(meta.pick?.description ?? "nil")")
        return meta
    }
    
    // MARK: - Writing
    
    /// Writes rating / label / pick to the photo's sidecar, preserving any
    /// other metadata already present. Creates the file from a minimal Adobe
    /// template when it doesn't exist yet.
    static func write(rating: Int, label: ColorLabel, flag: Flag, for photoURL: URL) {
        let xmpURL = sidecarURL(for: photoURL)
        let fileManager = FileManager.default
        let fileExists = fileManager.fileExists(atPath: xmpURL.path)
        
        // Don't create an empty sidecar when there is nothing meaningful to store
        if !fileExists && rating == 0 && label == .none && flag == .unflagged {
            debugPrint("[XMPSidecar] Nothing to persist for \(xmpURL.lastPathComponent), skipping")
            return
        }
        
        let document: XMLDocument
        let description: XMLElement
        if fileExists,
           let existing = try? XMLDocument(contentsOf: xmpURL, options: [.nodePreserveWhitespace]),
           let desc = findDescription(in: existing) {
            document = existing
            description = desc
            debugPrint("[XMPSidecar] Updating existing sidecar: \(xmpURL.lastPathComponent)")
        } else {
            (document, description) = makeNewDocument()
            debugPrint("[XMPSidecar] Creating new sidecar: \(xmpURL.lastPathComponent)")
        }
        
        // Rating + Label live in the xmp namespace
        ensureNamespace(on: description, prefix: "xmp", uri: nsXMP)
        setProperty(description, name: "xmp:Rating", value: rating > 0 ? String(rating) : nil)
        setProperty(description, name: "xmp:Label", value: label == .none ? nil : label.rawValue)
        
        // Pick flag in the lightroom namespace (1 = pick, -1 = reject, absent = unflagged)
        if flag == .unflagged {
            setProperty(description, name: "lr:pick", value: nil)
        } else {
            ensureNamespace(on: description, prefix: "lr", uri: nsLR)
            setProperty(description, name: "lr:pick", value: flag == .pick ? "1" : "-1")
        }
        
        do {
            let data = document.xmlData(options: [.nodePrettyPrint])
            try data.write(to: xmpURL)
            debugPrint("[XMPSidecar] Wrote \(xmpURL.lastPathComponent): rating=\(rating), label=\(label.rawValue), flag=\(flag.rawValue)")
        } catch {
            debugPrint("[XMPSidecar] Failed to write \(xmpURL.lastPathComponent): \(error.localizedDescription)")
        }
    }
    
    // MARK: - XML Helpers
    
    /// Finds the first `rdf:Description` element in the document.
    private static func findDescription(in document: XMLDocument) -> XMLElement? {
        guard let root = document.rootElement() else { return nil }
        for rdf in root.elements(forName: "rdf:RDF") {
            if let desc = rdf.elements(forName: "rdf:Description").first {
                return desc
            }
        }
        return nil
    }
    
    /// Builds a minimal Adobe XMP document and returns its `rdf:Description`.
    private static func makeNewDocument() -> (XMLDocument, XMLElement) {
        let description = XMLElement(name: "rdf:Description")
        if let about = XMLNode.attribute(withName: "rdf:about", stringValue: "") as? XMLNode {
            description.addAttribute(about)
        }
        ensureNamespace(on: description, prefix: "xmp", uri: nsXMP)
        
        let rdf = XMLElement(name: "rdf:RDF")
        ensureNamespace(on: rdf, prefix: "rdf", uri: nsRDF)
        rdf.addChild(description)
        
        let meta = XMLElement(name: "x:xmpmeta")
        ensureNamespace(on: meta, prefix: "x", uri: nsX)
        meta.addChild(rdf)
        
        let document = XMLDocument(rootElement: meta)
        document.version = "1.0"
        document.characterEncoding = "UTF-8"
        return (document, description)
    }
    
    /// Sets, updates or removes a property on the description element,
    /// matching whichever representation (attribute or child element) already
    /// exists so external files keep their original style.
    private static func setProperty(_ element: XMLElement, name: String, value: String?) {
        // 1) Existing attribute form
        if element.attribute(forName: name) != nil {
            if let value {
                element.attribute(forName: name)?.stringValue = value
            } else {
                element.removeAttribute(forName: name)
            }
            return
        }
        // 2) Existing child element form
        let existing = element.elements(forName: name)
        if let first = existing.first {
            if let value {
                first.stringValue = value
            } else {
                existing.forEach { $0.detach() }
            }
            return
        }
        // 3) Not present yet: add as a new child element if we have a value
        if let value {
            element.addChild(XMLElement(name: name, stringValue: value))
        }
    }
    
    /// Ensures the given namespace prefix is declared on the element (or an ancestor).
    private static func ensureNamespace(on element: XMLElement, prefix: String, uri: String) {
        var node: XMLElement? = element
        while let current = node {
            if let namespaces = current.namespaces, namespaces.contains(where: { $0.name == prefix }) {
                return
            }
            node = current.parent as? XMLElement
        }
        if let ns = XMLNode.namespace(withName: prefix, stringValue: uri) as? XMLNode {
            element.addNamespace(ns)
        }
    }
    
    // MARK: - Regex Helpers (reading)
    
    /// Extracts a property value from raw XMP text, trying attribute then element form.
    nonisolated private static func value(in text: String, property: String) -> String? {
        let escaped = NSRegularExpression.escapedPattern(for: property)
        // Attribute form: property="value"
        if let v = firstCapture(in: text, pattern: "\(escaped)\\s*=\\s*\"([^\"]*)\"") {
            return v
        }
        // Element form: <property ...>value</property>
        if let v = firstCapture(in: text, pattern: "<\(escaped)[^>]*>([^<]*)</\(escaped)>") {
            return v
        }
        return nil
    }
    
    /// Returns the first capture group of the first match for the pattern.
    nonisolated private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
