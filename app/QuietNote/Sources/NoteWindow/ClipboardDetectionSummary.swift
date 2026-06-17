extension AppText {
    func clipboardKindSummary(for detections: [ClipboardDetection], prefix: String) -> String {
        var seen: Set<ClipboardDetection.Kind> = []
        let names = detections.compactMap { detection -> String? in
            guard seen.insert(detection.kind).inserted else { return nil }
            return clipboardKindName(detection.kind)
        }
        return prefix + names.joined(separator: listSeparator)
    }
}
