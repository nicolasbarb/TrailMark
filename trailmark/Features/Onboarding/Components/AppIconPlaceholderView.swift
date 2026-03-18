//
//  AppIconPlaceholderView.swift
//  TrailMark
//

import SwiftUI

struct AppIconPlaceholderView: View {
    let width: CGFloat
    let height: CGFloat

    var body: some View {
        ZStack {
            Color.clear

            Image("AppIcon")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28))
        }
        .frame(width: width, height: height)
    }
}
