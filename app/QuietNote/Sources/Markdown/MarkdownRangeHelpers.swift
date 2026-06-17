import Foundation

enum MarkdownRangeHelpers {
    static func syntaxRanges(in fullRange: NSRange, visibleRanges: [NSRange]) -> [NSRange] {
        let fullEnd = fullRange.location + fullRange.length
        var cursor = fullRange.location
        var hidden: [NSRange] = []
        let visible = normalizedRanges(visibleRanges, upperBound: fullEnd)

        for range in visible {
            let visibleStart = max(range.location, fullRange.location)
            let visibleEnd = min(range.location + range.length, fullEnd)
            guard visibleEnd > cursor else { continue }
            if visibleStart > cursor {
                hidden.append(NSRange(location: cursor, length: visibleStart - cursor))
            }
            cursor = max(cursor, visibleEnd)
        }

        if cursor < fullEnd {
            hidden.append(NSRange(location: cursor, length: fullEnd - cursor))
        }
        return hidden.filter { $0.length > 0 }
    }

    static func nsRanges(from selectedRanges: [NSValue]) -> [NSRange] {
        selectedRanges.map(\.rangeValue)
    }

    static func ranges(_ ranges: [NSRange], touch target: NSRange) -> Bool {
        guard target.location != NSNotFound, target.length > 0 else { return false }
        let targetEnd = target.location + target.length

        return ranges.contains { range in
            guard range.location != NSNotFound else { return false }
            if range.length == 0 {
                if range.location == target.location, target.location == 0 {
                    return false
                }
                return range.location >= target.location && range.location <= targetEnd
            }
            return NSIntersectionRange(range, target).length > 0
        }
    }

    static func ranges(_ ranges: [NSRange], activateCodeBlock target: NSRange) -> Bool {
        guard target.location != NSNotFound, target.length > 0 else { return false }
        let targetEnd = target.location + target.length

        return ranges.contains { range in
            guard range.location != NSNotFound else { return false }
            if range.length == 0 {
                return range.location > target.location && range.location < targetEnd
            }
            return NSIntersectionRange(range, target).length > 0
        }
    }

    static func normalizedRanges(_ ranges: [NSRange], upperBound: Int) -> [NSRange] {
        var validRanges: [NSRange] = []
        for range in ranges where range.length > 0 && range.location < upperBound {
            let location = max(0, range.location)
            let end = min(upperBound, range.location + range.length)
            let length = max(0, end - location)
            if length > 0 {
                validRanges.append(NSRange(location: location, length: length))
            }
        }

        validRanges.sort { lhs, rhs in
            lhs.location == rhs.location ? lhs.length < rhs.length : lhs.location < rhs.location
        }

        var mergedRanges: [NSRange] = []
        for range in validRanges {
            guard let last = mergedRanges.last else {
                mergedRanges.append(range)
                continue
            }
            let lastEnd = last.location + last.length
            let rangeEnd = range.location + range.length
            if range.location <= lastEnd {
                mergedRanges[mergedRanges.count - 1] = NSRange(
                    location: last.location,
                    length: max(lastEnd, rangeEnd) - last.location
                )
            } else {
                mergedRanges.append(range)
            }
        }

        return mergedRanges
    }

    static func availableRanges(in range: NSRange, excluding exclusions: [NSRange]) -> [NSRange] {
        let rangeEnd = range.location + range.length
        var cursor = range.location
        var available: [NSRange] = []

        normalizedRanges(exclusions, upperBound: rangeEnd).forEach { exclusion in
            let exclusionStart = max(exclusion.location, range.location)
            let exclusionEnd = min(exclusion.location + exclusion.length, rangeEnd)
            guard exclusionEnd > cursor else { return }

            if exclusionStart > cursor {
                available.append(NSRange(location: cursor, length: exclusionStart - cursor))
            }
            cursor = max(cursor, exclusionEnd)
        }

        if cursor < rangeEnd {
            available.append(NSRange(location: cursor, length: rangeEnd - cursor))
        }

        return available.filter { $0.length > 0 }
    }

    static func range(from start: Int, to end: Int) -> NSRange {
        let lower = min(start, end)
        let upper = max(start, end)
        return NSRange(location: lower, length: upper - lower)
    }
}
