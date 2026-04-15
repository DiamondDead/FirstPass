//
//  LeftSideBarVM.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import Foundation
import Combine
import AppKit

@MainActor
final class LeftSideBarVM: NSObject, ObservableObject {
    
    override init() {
        super.init()
        
    }
    
    func open() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK {
                print(panel.url ?? "pas d'URL")
            }
        }
    }}
