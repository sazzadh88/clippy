import SwiftUI

/// Notch silhouette: flush with the top of `rect`, horizontally centered.
/// `earRadius` adds inverse curves outside the body where it meets the menu bar.
struct NotchShape: Shape {
    var width: CGFloat
    var height: CGFloat
    var bottomRadius: CGFloat
    var earRadius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { .init(.init(width, height), .init(bottomRadius, earRadius)) }
        set {
            width = newValue.first.first
            height = newValue.first.second
            bottomRadius = newValue.second.first
            earRadius = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let top = rect.minY, bottom = rect.minY + height
        let l = rect.midX - width / 2, r = rect.midX + width / 2
        let br = max(0, min(bottomRadius, width / 2, height / 2))
        let ear = max(0, min(earRadius, height - br))

        var p = Path()
        p.move(to: CGPoint(x: l - ear, y: top))
        p.addLine(to: CGPoint(x: r + ear, y: top))
        p.addQuadCurve(to: CGPoint(x: r, y: top + ear), control: CGPoint(x: r, y: top))
        p.addLine(to: CGPoint(x: r, y: bottom - br))
        p.addQuadCurve(to: CGPoint(x: r - br, y: bottom), control: CGPoint(x: r, y: bottom))
        p.addLine(to: CGPoint(x: l + br, y: bottom))
        p.addQuadCurve(to: CGPoint(x: l, y: bottom - br), control: CGPoint(x: l, y: bottom))
        p.addLine(to: CGPoint(x: l, y: top + ear))
        p.addQuadCurve(to: CGPoint(x: l - ear, y: top), control: CGPoint(x: l, y: top))
        p.closeSubpath()
        return p
    }
}

extension NotchShape {
    init(_ m: NotchMetrics) {
        self.init(width: m.width, height: m.height, bottomRadius: m.bottomRadius, earRadius: m.earRadius)
    }
}
