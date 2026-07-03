//
//  FilterBar.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 18/05/2026.
//

import SwiftUI

enum FilterFlag: String, CaseIterable {
    case all = "Tous"
    case pick = "Pick"
    case reject = "Reject"
    case unflagged = "Non triés"
}

struct FilterBar: View {
    @Binding var filterFlag: FilterFlag
    @Binding var minStars: Int
    @Binding var selectedColorLabels: Set<ColorLabel>
    let totalCount: Int
    let pickCount: Int
    let rejectCount: Int
    let unflaggedCount: Int
    let filteredCount: Int
    let selectedPhotoCount: Int
    let onCreateFolder: () -> Void
    
    // Color label hex values from web design
    private let colorLabelHex: [ColorLabel: Color] = [
        .red: Color(red: 1.0, green: 0.2, blue: 0.2),
        .yellow: Color(red: 1.0, green: 0.84, blue: 0.0),
        .green: Color(red: 0.2, green: 0.8, blue: 0.4),
        .blue: Color(red: 0.2, green: 0.6, blue: 1.0),
        .purple: Color(red: 0.6, green: 0.4, blue: 1.0)
    ]
    
    var body: some View {
        HStack(spacing: 16) {
            // Segmented control for flags
            HStack(spacing: 2) {
                ForEach(FilterFlag.allCases, id: \.self) { flag in
                    FlagFilterButton(
                        title: flagTitle(for: flag),
                        count: count(for: flag),
                        isActive: filterFlag == flag,
                        color: flagColor(for: flag),
                        action: { filterFlag = flag }
                    )
                }
            }
            .padding(2)
            .background(Color.fpInset)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.fpBorder, lineWidth: 0.5)
            )
            
            Divider()
                .frame(height: 16)
            
            // Star filter
            StarFilterChip(minStars: $minStars)
            
            Divider()
                .frame(height: 16)
            
            // Color label filters
            ColorLabelChips(
                selectedLabels: $selectedColorLabels,
                colorHex: colorLabelHex
            )
            
            // Create folder button — always visible so a new folder can be created at any time.
            // Shows the selected count only when photos are selected (those would be moved into it).
            Button(action: onCreateFolder) {
                HStack(spacing: 6) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 11))
                    Text("Nouveau dossier")
                        .font(.system(size: 11.5, weight: .medium))
                    if selectedPhotoCount > 0 {
                        Text("(\(selectedPhotoCount))")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Color.fpTextSecondary.opacity(0.8))
                    }
                }
                .foregroundStyle(Color.fpText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.fpAccent.opacity(0.16))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.fpAccent.opacity(0.4), lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
            
            Divider()
                .frame(height: 16)
            
            Spacer()
            
            // Count display
            Text("\(filteredCount) / \(totalCount)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Color.fpTextSecondary)
        }
        .padding(.horizontal, 18)
        .frame(height: 50)
        .background(Color.fpContent.opacity(0.6))
        .overlay(
            Rectangle()
                .fill(Color.fpBorder)
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
    
    // MARK: - Helper Methods
    
    private func flagTitle(for flag: FilterFlag) -> String {
        switch flag {
        case .all: return "Tous · \(totalCount)"
        case .pick: return "Pick · \(pickCount)"
        case .reject: return "Reject · \(rejectCount)"
        case .unflagged: return "Non triés · \(unflaggedCount)"
        }
    }
    
    private func count(for flag: FilterFlag) -> Int {
        switch flag {
        case .all: return totalCount
        case .pick: return pickCount
        case .reject: return rejectCount
        case .unflagged: return unflaggedCount
        }
    }
    
    private func flagColor(for flag: FilterFlag) -> Color? {
        switch flag {
        case .pick: return Color(red: 0.18, green: 0.82, blue: 0.35) // #30d158
        case .reject: return Color(red: 1.0, green: 0.27, blue: 0.23) // #ff453a
        default: return nil
        }
    }
}

// MARK: - Flag Filter Button

struct FlagFilterButton: View {
    let title: String
    let count: Int
    let isActive: Bool
    let color: Color?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11.5, weight: isActive ? .semibold : .medium))
                .foregroundStyle(isActive ? Color.fpText : Color.fpTextSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isActive ? Color.fpControlActive : Color.clear)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Star Filter Chip

struct StarFilterChip: View {
    @Binding var minStars: Int
    
    var body: some View {
        HStack(spacing: 3) {
            Text("≥")
                .font(.system(size: 11))
                .foregroundStyle(Color.fpTextSecondary)
            
            ForEach(1...5, id: \.self) { star in
                Button(action: {
                    minStars = minStars == star ? 0 : star
                }) {
                    Image(systemName: star <= minStars ? "star.fill" : "star")
                        .font(.system(size: 11))
                        .foregroundStyle(star <= minStars ? Color.fpAccent : Color.fpTextSecondary.opacity(0.55))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(minStars > 0 ? Color.fpAccent.opacity(0.16) : Color.fpChipBackground)
        .cornerRadius(999)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(minStars > 0 ? Color.fpAccent.opacity(0.4) : Color.fpBorder, lineWidth: 0.5)
        )
    }
}

// MARK: - Color Label Chips

struct ColorLabelChips: View {
    @Binding var selectedLabels: Set<ColorLabel>
    let colorHex: [ColorLabel: Color]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach([ColorLabel.red, .yellow, .green, .blue, .purple], id: \.self) { label in
                Button(action: {
                    if selectedLabels.contains(label) {
                        selectedLabels.remove(label)
                    } else {
                        selectedLabels.insert(label)
                    }
                }) {
                    let isSelected = selectedLabels.contains(label)
                    Circle()
                        .fill(colorHex[label] ?? .gray)
                        .frame(width: 14, height: 14)
                        .opacity(isSelected ? 1.0 : 0.35)
                        .overlay(
                            Circle()
                                .stroke(Color.fpText.opacity(0.85), lineWidth: isSelected ? 1.5 : 0)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.fpChipBackground)
        .cornerRadius(999)
        .overlay(
            RoundedRectangle(cornerRadius: 999)
                .stroke(Color.fpBorder, lineWidth: 0.5)
        )
    }
}

#Preview {
    @Previewable @State var filterFlag: FilterFlag = .all
    @Previewable @State var minStars: Int = 0
    @Previewable @State var selectedColorLabels: Set<ColorLabel> = []
    
    return FilterBar(
        filterFlag: $filterFlag,
        minStars: $minStars,
        selectedColorLabels: $selectedColorLabels,
        totalCount: 150,
        pickCount: 45,
        rejectCount: 12,
        unflaggedCount: 93,
        filteredCount: 150,
        selectedPhotoCount: 5,
        onCreateFolder: {
            debugPrint("Create folder clicked")
        }
    )
    .background(Color.fpBackground)
}
