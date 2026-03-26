//
//  ScreenLoadingOverlayView.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.

import SwiftUI

struct ScreenLoadingOverlayView: View {
    private enum UI {
        static let opacity: Double = 0.8
        static let scale: CGFloat = 1.5
        static let topPadding: CGFloat = 16
    }

    let title: String

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .opacity(UI.opacity)

            VStack {
                ProgressView()
                    .scaleEffect(UI.scale)

                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                    .padding(.top, UI.topPadding)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
