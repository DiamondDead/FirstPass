//
//  SettingsView.swift
//  FirstPass
//
//  Preferences window (Cmd+,). Currently hosts the theme selection.
//

import SwiftUI

struct SettingsView: View {
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRaw = AppearanceMode.system.rawValue

    var body: some View {
        Form {
            Picker("Thème :", selection: $appearanceModeRaw) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .pickerStyle(.radioGroup)

            Text("La visionneuse conserve toujours un fond sombre pour ne pas biaiser la perception des couleurs.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 360)
    }
}

#Preview {
    SettingsView()
}
