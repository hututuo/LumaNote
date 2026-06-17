import SwiftUI

struct ReadablePopupPanelBackground: View {
    let accentColor: Color
    var cornerRadius: CGFloat = 15
    var materialOpacity = 0.60
    var whiteOpacity = 0.08
    var accentOpacity = 0.024

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    var body: some View {
        shape
            .fill(.regularMaterial)
            .opacity(materialOpacity)
            .overlay {
                shape
                    .fill(Color.white.opacity(whiteOpacity))
            }
            .overlay {
                shape
                    .fill(accentColor.opacity(accentOpacity))
                    .blendMode(.plusLighter)
            }
            .overlay {
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.18),
                                .white.opacity(0.05),
                                .black.opacity(0.025)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            }
    }
}

private struct PopupPanelBorderModifier: ViewModifier {
    var cornerRadius: CGFloat = 15

    func body(content: Content) -> some View {
        content
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.62),
                                .white.opacity(0.18),
                                .black.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func readablePopupPanel(
        accentColor: Color,
        cornerRadius: CGFloat = 15,
        materialOpacity: Double = 0.60,
        whiteOpacity: Double = 0.08,
        accentOpacity: Double = 0.024
    ) -> some View {
        background {
            ReadablePopupPanelBackground(
                accentColor: accentColor,
                cornerRadius: cornerRadius,
                materialOpacity: materialOpacity,
                whiteOpacity: whiteOpacity,
                accentOpacity: accentOpacity
            )
        }
        .popupPanelBorder(cornerRadius: cornerRadius)
    }

    func floatingReadablePopupPanel(
        accentColor: Color,
        cornerRadius: CGFloat = 15,
        materialOpacity: Double = 0.60,
        whiteOpacity: Double = 0.08,
        accentOpacity: Double = 0.024
    ) -> some View {
        readablePopupPanel(
            accentColor: accentColor,
            cornerRadius: cornerRadius,
            materialOpacity: materialOpacity,
            whiteOpacity: whiteOpacity,
            accentOpacity: accentOpacity
        )
        .shadow(color: .white.opacity(0.055), radius: 1.2, x: -0.4, y: -0.4)
        .shadow(color: .black.opacity(0.055), radius: 2.2, y: 1.1)
    }

    func popupPanelBorder(cornerRadius: CGFloat = 15) -> some View {
        modifier(PopupPanelBorderModifier(cornerRadius: cornerRadius))
    }
}
