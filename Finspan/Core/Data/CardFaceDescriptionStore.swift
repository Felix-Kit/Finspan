import Foundation

struct CardFaceDescriptionStore: Sendable {
    private let descriptionsByCardId: [CardID: String]

    init(bundle: Bundle) {
        guard let url = bundle.url(
            forResource: "card_face_descriptions",
            withExtension: "json",
            subdirectory: "Resources/CardAssets"
        ) ?? bundle.url(
            forResource: "card_face_descriptions",
            withExtension: "json",
            subdirectory: "CardAssets"
        ) ?? bundle.url(forResource: "card_face_descriptions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let descriptions = try? JSONDecoder().decode([CardID: String].self, from: data)
        else {
            descriptionsByCardId = [:]
            return
        }

        descriptionsByCardId = descriptions
    }

    func description(for cardId: CardID) -> String? {
        guard let description = descriptionsByCardId[cardId]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty
        else {
            return nil
        }
        return description
    }
}
