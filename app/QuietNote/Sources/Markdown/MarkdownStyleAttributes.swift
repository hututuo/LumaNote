import AppKit

struct MarkdownStyleAttributes {
    let fontSize: CGFloat
    private let baseFont: NSFont
    private let boldFont: NSFont
    private let markerFont: NSFont
    private let markerBoldFont: NSFont
    private let monoRegularFont: NSFont
    private let monoMediumFont: NSFont
    private let monoSemiboldFont: NSFont
    private let heading1Font: NSFont
    private let heading2Font: NSFont
    private let heading3Font: NSFont

    init(fontSize: CGFloat) {
        self.fontSize = MarkdownTaskLayout.normalizedFontSize(fontSize)
        baseFont = NSFont.systemFont(ofSize: self.fontSize)
        boldFont = NSFont.boldSystemFont(ofSize: self.fontSize)
        markerFont = NSFont.monospacedSystemFont(
            ofSize: MarkdownTaskLayout.markerFontSize(for: self.fontSize),
            weight: .regular
        )
        markerBoldFont = NSFont.boldSystemFont(ofSize: MarkdownTaskLayout.markerFontSize(for: self.fontSize))
        monoRegularFont = NSFont.monospacedSystemFont(
            ofSize: MarkdownTaskLayout.monoFontSize(for: self.fontSize),
            weight: .regular
        )
        monoMediumFont = NSFont.monospacedSystemFont(
            ofSize: MarkdownTaskLayout.monoFontSize(for: self.fontSize),
            weight: .medium
        )
        monoSemiboldFont = NSFont.monospacedSystemFont(
            ofSize: MarkdownTaskLayout.monoFontSize(for: self.fontSize),
            weight: .semibold
        )
        heading1Font = NSFont.boldSystemFont(ofSize: self.fontSize + 8.5)
        heading2Font = NSFont.boldSystemFont(ofSize: self.fontSize + 4.5)
        heading3Font = NSFont.boldSystemFont(ofSize: self.fontSize + 1.5)
    }

    func attributes(for style: MarkdownInlineStyle) -> [NSAttributedString.Key: Any] {
        switch style {
        case .inlineCode:
            inlineCodeAttributes()
        case .boldItalic:
            boldItalicAttributes()
        case .bold:
            [.font: boldFont]
        case .italic:
            [.obliqueness: 0.12]
        case .strikethrough:
            [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
        case .highlight:
            highlightAttributes()
        case .image:
            imageAttributes()
        case .link:
            linkAttributes()
        case .wikiLink:
            wikiLinkAttributes()
        case .shortcode:
            shortcodeAttributes()
        }
    }

    func baseAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 3
        paragraph.paragraphSpacing = 7
        return [
            .font: baseFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.paragraphSpacingBefore = level == 1 ? 6 : 4
        paragraph.paragraphSpacing = 9
        return [
            .font: headingFont(level: level),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    func quoteAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        let indent = CGFloat(max(1, level)) * 12
        paragraph.headIndent = indent
        paragraph.firstLineHeadIndent = indent
        paragraph.lineSpacing = 4
        return [
            .font: baseFont,
            .foregroundColor: NSColor.secondaryLabelColor,
            .obliqueness: 0.12,
            .paragraphStyle: paragraph
        ]
    }

    func alertAttributes(kind: String, level: Int) -> [NSAttributedString.Key: Any] {
        var attributes = quoteAttributes(level: level)
        attributes[.backgroundColor] = Self.alertColor(kind: kind).withAlphaComponent(0.08)
        return attributes
    }

    func alertKindAttributes(kind: String) -> [NSAttributedString.Key: Any] {
        [
            .font: markerBoldFont,
            .foregroundColor: Self.alertColor(kind: kind)
        ]
    }

    func taskAttributes(done: Bool, indentationWidth: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        let contentIndent = indentationWidth + MarkdownTaskLayout.slotWidth(for: fontSize)
        paragraph.headIndent = contentIndent
        paragraph.firstLineHeadIndent = 0
        paragraph.lineSpacing = 3
        paragraph.tabStops = [
            NSTextTab(textAlignment: .left, location: contentIndent)
        ]
        paragraph.defaultTabInterval = contentIndent

        if done {
            return [
                .foregroundColor: NSColor.secondaryLabelColor,
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .paragraphStyle: paragraph
            ]
        }

        return [
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    func listAttributes(indentationWidth: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        let contentIndent = indentationWidth + fontSize + 2.5
        paragraph.headIndent = contentIndent
        paragraph.firstLineHeadIndent = indentationWidth
        paragraph.lineSpacing = 3
        return [.paragraphStyle: paragraph]
    }

    func tableAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: monoRegularFont,
            .backgroundColor: NSColor.controlAccentColor.withAlphaComponent(0.06)
        ]
    }

    func codeFenceAttributes(isActive: Bool, isOpening: Bool) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 1.5
        paragraph.paragraphSpacingBefore = isOpening ? 3 : 0
        paragraph.paragraphSpacing = isOpening ? 3 : 11

        return [
            .font: monoSemiboldFont,
            .foregroundColor: isActive ? NSColor.secondaryLabelColor : NSColor.clear,
            .paragraphStyle: paragraph
        ]
    }

    func codeBlockAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 2
        paragraph.firstLineHeadIndent = 14
        paragraph.headIndent = 14
        paragraph.tailIndent = -14
        return [
            .font: monoRegularFont,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]
    }

    func markerAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.tertiaryLabelColor,
            .font: markerFont
        ]
    }

    func headingMarkerAttributes(isActive: Bool) -> [NSAttributedString.Key: Any] {
        var attributes = markerAttributes()
        if !isActive {
            attributes[.foregroundColor] = NSColor.clear
            attributes[.markdownHiddenSyntax] = true
        }
        return attributes
    }

    func hiddenSyntaxAttributes() -> [NSAttributedString.Key: Any] {
        [
            .markdownHiddenSyntax: true,
            .foregroundColor: NSColor.clear
        ]
    }

    func ruleAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.tertiaryLabelColor,
            .strikethroughStyle: NSUnderlineStyle.thick.rawValue
        ]
    }

    private func inlineCodeAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: monoRegularFont,
            .backgroundColor: NSColor.black.withAlphaComponent(0.08)
        ]
    }

    private func boldItalicAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: boldFont,
            .obliqueness: 0.12
        ]
    }

    private func highlightAttributes() -> [NSAttributedString.Key: Any] {
        [
            .backgroundColor: NSColor.systemYellow.withAlphaComponent(0.24)
        ]
    }

    private func linkAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.systemBlue,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    private func wikiLinkAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.systemPurple,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    func imageAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.systemTeal,
            .font: monoMediumFont,
            .backgroundColor: NSColor.systemTeal.withAlphaComponent(0.08)
        ]
    }

    func referenceDefinitionAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: monoRegularFont,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
    }

    private func shortcodeAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: NSColor.systemOrange,
            .font: monoRegularFont
        ]
    }

    private func headingFont(level: Int) -> NSFont {
        switch level {
        case 1: heading1Font
        case 2: heading2Font
        case 3: heading3Font
        default: boldFont
        }
    }

    private static func alertColor(kind: String) -> NSColor {
        switch kind.uppercased() {
        case "TIP": return .systemGreen
        case "IMPORTANT": return .systemPurple
        case "WARNING": return .systemOrange
        case "CAUTION": return .systemRed
        default: return .systemBlue
        }
    }
}
