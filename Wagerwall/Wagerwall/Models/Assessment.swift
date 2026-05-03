import Foundation

struct Assessment: Codable, Sendable {
    let title: String
    let description: String
    let questions: [AssessmentQuestion]
    let options: [AssessmentOption]
    let scoring: AssessmentScoring
}

struct AssessmentQuestion: Codable, Identifiable, Sendable {
    let id: Int
    let text: String
}

struct AssessmentOption: Codable, Sendable {
    let label: String
    let score: Int
}

struct AssessmentScoring: Codable, Sendable {
    let ranges: [SeverityRange]
}

struct SeverityRange: Codable, Sendable {
    let min: Int
    let max: Int
    let severity: String
    let label: String
}

extension Assessment {
    static func load() -> Assessment {
        guard let url = Bundle.main.url(forResource: "Assessment", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let assessment = try? JSONDecoder().decode(Assessment.self, from: data) else {
            fatalError("Failed to load Assessment.json")
        }
        return assessment
    }

    func severity(for score: Int) -> GamblingSeverity {
        for range in scoring.ranges where score >= range.min && score <= range.max {
            return GamblingSeverity(rawValue: range.severity) ?? .moderate
        }
        return .severe
    }

    func severityLabel(for score: Int) -> String {
        for range in scoring.ranges where score >= range.min && score <= range.max {
            return range.label
        }
        return "Problem gambling"
    }
}
