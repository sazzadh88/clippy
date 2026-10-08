import SwiftUI

enum NotchState { case collapsed, hovered, expanded }

@MainActor @Observable
final class NotchViewModel {
    var geometry = NotchGeometry(notchSize: NotchGeometry.fallbackSize, centerX: 0, hasNotch: false)
    var state: NotchState = .collapsed
}

struct NotchRootView: View {
    let model: NotchViewModel

    var body: some View {
        let size = model.geometry.notchSize
        VStack(spacing: 0) {
            Rectangle()
                .fill(.black)
                .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: size.height / 2,
                                                  bottomTrailingRadius: size.height / 2))
                .frame(width: size.width, height: size.height)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
