import Foundation

nonisolated struct ENTChatQuestion: Codable, Equatable, Sendable {
    let text: String
    let query: String
}

nonisolated struct ENTChatQuestionCard: Codable, Equatable, Sendable {
    let title: String
    let questions: [ENTChatQuestion]

    var stableID: String {
        title + "|" + questions.map { "\($0.text):\($0.query)" }.joined(separator: "|")
    }
}

nonisolated struct ENTChatParseResult: Equatable, Sendable {
    let visibleMarkdown: String
    let questionCards: [ENTChatQuestionCard]
    let status: Status

    enum Status: Equatable, Sendable {
        case plainText
        case componentSuppressed
        case componentParsed
        case componentInvalid
    }
}

nonisolated struct ENTChatStreamParseSnapshot: Equatable, Sendable {
    let visibleMarkdown: String
    let questionCards: [ENTChatQuestionCard]
    let componentSuppressed: Bool
}

nonisolated final class ENTChatAnswerStreamParser: @unchecked Sendable {
    private var raw = ""

    func append(_ delta: String) -> ENTChatStreamParseSnapshot {
        raw += delta
        let parsed = ENTChatAnswerParser.parse(raw)
        let hasIncompleteComponent = ENTChatAnswerParser.hasIncompleteComponent(in: raw)
        return ENTChatStreamParseSnapshot(
            visibleMarkdown: parsed.visibleMarkdown,
            questionCards: parsed.questionCards,
            componentSuppressed: hasIncompleteComponent || !parsed.questionCards.isEmpty
        )
    }

    func finish(finalText: String? = nil) -> ENTChatParseResult {
        ENTChatAnswerParser.parse(finalText ?? raw)
    }

    func reset() {
        raw = ""
    }
}

nonisolated enum ENTChatAnswerParser {
    private static let openingPrefix = "<vb-component"
    private static let closingTag = "</vb-component>"
    private static let questionCardType = "QuestionCard"
    private static let defaultTitle = "还可以继续问"
    private static let maxQuestions = 3

    private static let openingTagRegex = try! NSRegularExpression(
        pattern: #"<vb-component\b[^>]*>"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )
    private static let typeRegex = try! NSRegularExpression(
        pattern: #"\btype\s*=\s*([\"'])(.*?)\1"#,
        options: [.caseInsensitive, .dotMatchesLineSeparators]
    )

    static func parse(_ text: String) -> ENTChatParseResult {
        guard !text.isEmpty else {
            return ENTChatParseResult(visibleMarkdown: "", questionCards: [], status: .plainText)
        }

        var visible = ""
        var cards: [ENTChatQuestionCard] = []
        var cursor = text.startIndex
        var sawComponent = false
        var invalidComponent = false

        while cursor < text.endIndex {
            guard let opening = openingTag(in: text, from: cursor) else {
                if let incompleteStart = openingPrefix(in: text, from: cursor) {
                    visible += String(text[cursor..<incompleteStart])
                    invalidComponent = true
                } else {
                    visible += String(text[cursor...])
                }
                break
            }

            visible += String(text[cursor..<opening.range.lowerBound])
            sawComponent = true
            guard let closeRange = text.range(of: closingTag, range: opening.range.upperBound..<text.endIndex) else {
                let inner = String(text[opening.range.upperBound...])
                if !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    visible += inner
                }
                invalidComponent = true
                break
            }

            let componentText = String(text[opening.range.lowerBound..<closeRange.upperBound])
            switch parseComponent(componentText) {
            case .success(let card):
                cards.append(card)
            case .invalid(let preserveInnerText):
                if preserveInnerText {
                    let inner = String(text[opening.range.upperBound..<closeRange.lowerBound])
                    if !inner.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        visible += inner
                    }
                }
                invalidComponent = true
            }
            cursor = closeRange.upperBound
        }

        let status: ENTChatParseResult.Status
        if invalidComponent {
            status = .componentInvalid
        } else if !cards.isEmpty {
            status = .componentParsed
        } else if sawComponent {
            status = .componentSuppressed
        } else {
            status = .plainText
        }
        return ENTChatParseResult(visibleMarkdown: visible, questionCards: cards, status: status)
    }

    static func hasIncompleteComponent(in text: String) -> Bool {
        guard let candidate = openingPrefix(in: text, from: text.startIndex) else { return false }
        guard let opening = openingTag(in: text, from: candidate) else { return true }
        return text.range(of: closingTag, range: opening.range.upperBound..<text.endIndex) == nil
    }

    private enum ComponentParse {
        case success(ENTChatQuestionCard)
        case invalid(preserveInnerText: Bool)
    }

    private static func parseComponent(_ text: String) -> ComponentParse {
        guard let opening = openingTag(in: text, from: text.startIndex) else {
            return .invalid(preserveInnerText: true)
        }
        let type = attributeValue(named: "type", in: String(text[opening.range]))
        guard type == questionCardType else { return .invalid(preserveInnerText: false) }
        guard let closeRange = text.range(of: closingTag, range: opening.range.upperBound..<text.endIndex) else {
            return .invalid(preserveInnerText: true)
        }

        let payload = String(text[opening.range.upperBound..<closeRange.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = payload.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rawQuestions = object["questions"] as? [[String: Any]] else {
            return .invalid(preserveInnerText: true)
        }

        let titleValue = (object["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = titleValue?.isEmpty == false ? titleValue! : defaultTitle
        let questions = rawQuestions.prefix(maxQuestions).compactMap { item -> ENTChatQuestion? in
            guard let text = item["text"] as? String,
                  let query = item["query"] as? String else { return nil }
            let displayText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let sendQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayText.isEmpty, !sendQuery.isEmpty else { return nil }
            return ENTChatQuestion(text: displayText, query: sendQuery)
        }
        guard !questions.isEmpty else { return .invalid(preserveInnerText: true) }
        return .success(ENTChatQuestionCard(title: title, questions: questions))
    }

    private static func openingTag(in text: String, from index: String.Index) -> (range: Range<String.Index>, type: String?)? {
        let nsRange = NSRange(index..<text.endIndex, in: text)
        guard let match = openingTagRegex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range, in: text) else { return nil }
        return (range, attributeValue(named: "type", in: String(text[range])))
    }

    private static func openingPrefix(in text: String, from index: String.Index) -> String.Index? {
        let searchStart = text.distance(from: text.startIndex, to: index)
        let lowerBound = max(searchStart, text.count - (openingPrefix.count - 1))
        guard lowerBound <= text.count else { return nil }
        for offset in lowerBound..<text.count {
            let candidate = String(text.dropFirst(offset))
            if openingPrefix.lowercased().hasPrefix(candidate.lowercased()) {
                return text.index(text.startIndex, offsetBy: offset)
            }
        }
        return nil
    }

    private static func attributeValue(named name: String, in text: String) -> String? {
        guard name.caseInsensitiveCompare("type") == .orderedSame else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = typeRegex.firstMatch(in: text, range: range), match.numberOfRanges > 2,
              let valueRange = Range(match.range(at: 2), in: text) else { return nil }
        return String(text[valueRange]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
