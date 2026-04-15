//
//  LeftSideBar.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import SwiftUI

struct LeftSideBar: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Ouvrir +") { }
                .frame(maxWidth: .infinity)
                .padding()
                .buttonStyle(.bordered)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

#Preview {
    LeftSideBar()
}
