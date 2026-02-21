//
//  DeviceFrameView.swift
//  TrailMark
//

import SwiftUI

struct DeviceFrameView: View {
    var body: some View {
        let shape = ConcentricRectangle(corners: .concentric, isUniform: true)

        ZStack {
            shape
                .stroke(.white, lineWidth: 6)

            shape
                .stroke(.black, lineWidth: 4)

            shape
                .stroke(.black, lineWidth: 6)
                .padding(4)
        }
        .padding(-7)
    }
}
