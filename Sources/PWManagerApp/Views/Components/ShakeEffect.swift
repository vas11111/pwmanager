import SwiftUI

struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 3
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: amount * sin(shakes * 3 * .pi), y: 0)
        )
    }
}

extension View {
    func shake(_ trigger: Bool) -> some View {
        modifier(ShakeEffect(shakes: trigger ? 2 : 0))
            .animation(.default, value: trigger)
    }

    func annotation(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            self
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.text3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
