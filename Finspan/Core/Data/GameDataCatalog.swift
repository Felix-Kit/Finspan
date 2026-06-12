import Foundation

struct GameDataCatalog {
    var cards: [Card] = []
    var cardCatalog: any CardCatalog = EmptyCardCatalog()
}
