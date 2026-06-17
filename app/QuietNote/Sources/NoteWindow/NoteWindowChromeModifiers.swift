import SwiftUI

struct ExtractionIslandButtonModifier: ViewModifier {
    let isExpanded: Bool
    let opacity: Double
    let accentColor: Color
    var isHighlighted = false

    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .foregroundStyle(.primary.opacity(0.86))
            .background {
                islandShape
                    .fill(.regularMaterial)
                    .opacity(0.08 + opacity * 0.72)
            }
            .background(
                islandShape
                    .fill(Color.white.opacity((isExpanded ? 0.025 : 0.04) + opacity * (isExpanded ? 0.075 : 0.1)))
                    .blendMode(.plusLighter)
            )
            .background(
                islandShape
                    .fill(accentColor.opacity(0.004 + opacity * 0.024))
                    .blendMode(.plusLighter)
            )
            .overlay {
                if isHighlighted {
                    DetectionIslandFlowLayer(
                        shape: islandShape,
                        accentColor: accentColor,
                        opacity: opacity
                    )
                }
            }
            .overlay(
                islandShape
                    .strokeBorder(
                        LinearGradient(
                            colors: borderColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isHighlighted ? 1.35 : 1
                    )
            )
            .overlay {
                if isHighlighted {
                    islandShape
                        .inset(by: 1.5)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    accentColor.opacity(0.42),
                                    .white.opacity(0.24),
                                    accentColor.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.55
                        )
                        .blendMode(.plusLighter)
                        .opacity(0.58 + opacity * 0.2)
                }
            }
            .shadow(color: isHighlighted ? accentColor.opacity(0.05 + opacity * 0.05) : .clear, radius: 2, y: 0.6)
            .shadow(color: .white.opacity(0.025 + opacity * 0.07), radius: 1.2, x: -0.5, y: -0.5)
            .shadow(color: .black.opacity(0.025 + opacity * 0.055), radius: 2, y: 1)
    }

    private var borderColors: [Color] {
        if isHighlighted {
            [
                accentColor.opacity(0.48 + opacity * 0.2),
                .white.opacity(0.30 + opacity * 0.24),
                accentColor.opacity(0.28 + opacity * 0.18),
                .white.opacity(0.12 + opacity * 0.1),
                accentColor.opacity(0.44 + opacity * 0.18)
            ]
        } else {
            [
                .white.opacity((isExpanded ? 0.18 : 0.22) + opacity * (isExpanded ? 0.56 : 0.6)),
                accentColor.opacity(0.045 + opacity * 0.11),
                .white.opacity(0.08 + opacity * 0.14),
                .white.opacity(0.02 + opacity * 0.04)
            ]
        }
    }

    private var islandShape: AnyInsettableShape {
        if isExpanded {
            AnyInsettableShape(Capsule(style: .continuous))
        } else {
            AnyInsettableShape(Circle())
        }
    }
}

extension View {
    func delayedInlineHelp(_ text: String, delay: TimeInterval, yOffset: CGFloat) -> some View {
        modifier(DelayedInlineHelpModifier(text: text, delay: delay, yOffset: yOffset))
    }
}

private struct DelayedInlineHelpModifier: ViewModifier {
    let text: String
    let delay: TimeInterval
    let yOffset: CGFloat

    @State private var controller = NoteDelayedInlineHelpController()

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if controller.isVisible {
                    Text(text)
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary.opacity(0.84))
                        .lineLimit(1)
                        .fixedSize()
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.regularMaterial, in: Capsule(style: .continuous))
                        .overlay(
                            Capsule(style: .continuous)
                                .strokeBorder(.white.opacity(0.34), lineWidth: 0.7)
                        )
                        .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                        .offset(y: yOffset)
                        .transition(.scale(scale: 0.94, anchor: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .onHover { isHovering in
                controller.setHovering(isHovering, delay: delay)
            }
            .onDisappear {
                controller.cancel()
            }
    }
}
