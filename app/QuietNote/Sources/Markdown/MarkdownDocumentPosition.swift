import Foundation

struct MarkdownDocumentPosition: Codable, Equatable {
    var selectedLocation: Int
    var selectedLength: Int
    var scrollY: Double

    static let top = MarkdownDocumentPosition(selectedLocation: 0, selectedLength: 0, scrollY: 0)
}
