//
//  OnboardingIndicatorView.swift
//  TrailMark
//

import SwiftUI

struct OnboardingIndicatorView: View {
    let itemCount: Int
    let currentIndex: Int
    let textColor: Color

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<itemCount, id: \.self) { index in
                let isActive = currentIndex == index

                Capsule()
                    .fill(textColor.opacity(isActive ? 1 : 0.4))
                    .frame(width: isActive ? 25 : 6, height: 6)
            }
        }
    }
}
