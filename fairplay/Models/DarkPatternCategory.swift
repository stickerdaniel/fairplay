import Foundation

struct DarkPatternCategory: Codable, Identifiable, Equatable {
    let id: String
    let name: String
    let scanDescription: String
    let fixInstructions: String
}

struct DarkPatternCategoryConfig: Codable {
    let categories: [DarkPatternCategory]
}

enum CategoryLoader {
    static var shared: [DarkPatternCategory] = {
        guard let url = Bundle.main.url(forResource: "dark-pattern-categories", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(DarkPatternCategoryConfig.self, from: data) else {
            fatalError("Failed to load dark-pattern-categories.json")
        }
        return config.categories
    }()

    static func category(forName name: String) -> DarkPatternCategory? {
        shared.first { $0.name == name }
    }

    static func category(forId id: String) -> DarkPatternCategory? {
        shared.first { $0.id == id }
    }
}
