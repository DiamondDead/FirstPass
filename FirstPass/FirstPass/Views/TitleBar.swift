//
//  TitleBar.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 18/05/2026.
//

import SwiftUI

struct TitleBar: View {
    let folderPath: [String]
    let sidebarVisible: Bool
    let onToggleSidebar: () -> Void
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRaw = AppearanceMode.system.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .system
    }

    private var appearanceIcon: String {
        switch appearanceMode {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .dark: return "moon"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Sidebar toggle button
            Button(action: onToggleSidebar) {
                Image(systemName: sidebarVisible ? "sidebar.left" : "sidebar.left")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.fpTextSecondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            
            // Folder path breadcrumb
            HStack(spacing: 4) {
                ForEach(Array(folderPath.enumerated()), id: \.offset) { index, component in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.fpTextSecondary.opacity(0.5))
                    }
                    Text(component)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(index == folderPath.count - 1 ? Color.fpText : Color.fpTextSecondary)
                }
            }
            
            Spacer()

            // Theme switcher — cycles through the same modes as Preferences (Cmd+,)
            Menu {
                ForEach(AppearanceMode.allCases) { mode in
                    Button(action: { appearanceModeRaw = mode.rawValue }) {
                        HStack {
                            Text(mode.label)
                            if mode == appearanceMode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: appearanceIcon)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.fpTextSecondary)
                    .frame(width: 28, height: 28)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Thème : \(appearanceMode.label)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.fpContent)
        .overlay(
            Rectangle()
                .fill(Color.fpBorder)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

#Preview {
    TitleBar(
        folderPath: ["2026", "Shoots", "02_Février", "Mariage_Camille_Antoine"],
        sidebarVisible: true,
        onToggleSidebar: {}
    )
    .frame(width: 800, height: 50)
    .background(Color.fpBackground)
}
