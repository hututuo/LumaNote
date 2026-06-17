enum ClipboardExtractionTextWrapping {
    private static let breakScalars = Set("/\\?&=#:-_@.,，;；:： ".unicodeScalars)

    static func wrappingValue(_ value: String) -> String {
        var output = ""
        output.reserveCapacity(value.count + value.count / 4)

        for scalar in value.unicodeScalars {
            output.unicodeScalars.append(scalar)
            if breakScalars.contains(scalar) {
                output.unicodeScalars.append("\u{200B}")
            }
        }

        return output
    }
}
