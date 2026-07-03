//
//  KeyboardHints.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 18/05/2026.
//

import SwiftUI

struct KeyboardHints: View {
    @State private var isOpen = false
    
    private let shortcuts: [(String, String)] = [
        ("P", "Pick"),
        ("X", "Reject"),
        ("U", "Unflag"),
        ("1–5", "Étoiles"),
        ("6–9", "Label couleur"),
        ("0", "Effacer label"),
        ("← →", "Naviguer"),
        ("↵", "Détail / Grille"),
        ("⌘ ↵", "Éditeur externe"),
        ("Esc", "Retour grille"),
    ]
    
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if isOpen {
                hintsPanel
            }
            
            toggleButton
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(18)
    }
    
    @ViewBuilder
    private var hintsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("RACCOURCIS")
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(Color.fpTextSecondary.opacity(0.45))
                .tracking(0.12)
                .padding(.bottom, 8)
            
            ForEach(shortcuts, id: \.0) { shortcut, description in
                HStack {
                    Text(description)
                        .font(.system(size: 11))
                        .foregroundStyle(Color.fpTextSecondary.opacity(0.7))
                    
                    Spacer()
                    
                    Text(shortcut)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.fpTextSecondary.opacity(0.85))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.fpChipBackground)
                        .cornerRadius(3)
                }
                .padding(.vertical, 3)
            }
        }
        .padding(12)
        .padding(.horizontal, 14)
        .background(Color.fpPanel)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.fpBorder, lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 4)
        .frame(minWidth: 220)
    }
    
    @ViewBuilder
    private var toggleButton: some View {
        Button(action: { isOpen.toggle() }) {
            HStack(spacing: 5) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                Text(isOpen ? "Fermer" : "Raccourcis")
                    .font(.system(size: 10.5, design: .monospaced))
                    .tracking(0.04)
            }
            .foregroundStyle(Color.fpTextSecondary.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.fpPanel)
            .cornerRadius(999)
            .overlay(
                RoundedRectangle(cornerRadius: 999)
                    .stroke(Color.fpBorder, lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    KeyboardHints()
        .frame(width: 400, height: 400)
        .background(Color.fpBackground)
}
