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
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 16
    }

    @ScaledMetric(relativeTo: .title) private var iconSize: CGFloat = 36

    let title: LocalizedStringKey
    let systemImage: String
    let description: Text?
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?
    let isProminentAction: Bool

    init(
        title: LocalizedStringKey,
        systemImage: String,
        description: Text? = nil,
        actionTitle: LocalizedStringKey? = nil,
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
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let description {
                description
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                if isProminentAction {
                    Button(action: action) {
                        Text(actionTitle)
                    }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button(action: action) {
                        Text(actionTitle)
                    }
                        .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, UI.verticalPadding)
        .padding(.horizontal, UI.horizontalPadding)
    }
}
