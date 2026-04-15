//
//  LeftSideBar.swift
//  FirstPass
//
//  Created by Mathieu Bazin on 15/04/2026.
//

import SwiftUI

struct LeftSideBar: View {
    @StateObject private var vm = LeftSideBarVM()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button("Ouvrir +") {
                vm.open()
            }
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
