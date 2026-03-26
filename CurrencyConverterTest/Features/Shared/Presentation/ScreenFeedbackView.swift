//
//  ScreenFeedbackView.swift
//  CurrencyConverterTest
//
//  Created by Yauheni Kozich on 26.03.26.
//

import SwiftUI

struct ScreenFeedbackView: View {
    private enum UI {
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 36
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 16
    }

    let title: String
    let systemImage: String
    let description: String?
    let actionTitle: String?
    let action: (() -> Void)?
    let isProminentAction: Bool

    init(
        title: String,
        systemImage: String,
        description: String? = nil,
        actionTitle: String? = nil,
        isProminentAction: Bool = true,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.systemImage = systemImage
        self.description = description
        self.actionTitle = actionTitle
        self.isProminentAction = isProminentAction
        self.action = action
    }

    var body: some View {
        VStack(spacing: UI.spacing) {
            Image(systemName: systemImage)
                .font(.system(size: UI.iconSize, weight: .semibold))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let description {
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                if isProminentAction {
                    Button(actionTitle, action: action)
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(actionTitle, action: action)
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UI.verticalPadding)
        .padding(.horizontal, UI.horizontalPadding)
    }
}
