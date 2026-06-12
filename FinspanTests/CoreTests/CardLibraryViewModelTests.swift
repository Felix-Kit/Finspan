import XCTest
@testable import Finspan

@MainActor
final class CardLibraryViewModelTests: XCTestCase {
    func testCardLibraryDefaultsToDiscoveredModeAndKeepsAllCardSlots() {
        let store = makeStore()
        let catalog = SampleCardCatalog()
        let viewModel = CardLibraryViewModel(catalog: catalog, discoveredStore: store)

        let viewState = viewModel.viewState

        XCTAssertEqual(viewState.displayMode, .discovered)
        XCTAssertEqual(viewState.cards.count, catalog.starterFishCards.count + catalog.fishCards.count)
        XCTAssertTrue(viewState.cards.allSatisfy(\.isLocked))
    }

    func testDiscoveredModeDoesNotLockDiscoveredCards() {
        let store = makeStore()
        store.markDiscovered("starter-fish-1")
        let viewModel = CardLibraryViewModel(catalog: SampleCardCatalog(), discoveredStore: store)

        let card = viewModel.viewState.cards.first { $0.cardId == "starter-fish-1" }

        XCTAssertEqual(card?.isDiscovered, true)
        XCTAssertEqual(card?.isLocked, false)
    }

    func testAllModeShowsEveryCardUnlocked() {
        let viewModel = CardLibraryViewModel(catalog: SampleCardCatalog(), discoveredStore: makeStore())

        viewModel.displayMode = .all

        XCTAssertEqual(viewModel.viewState.displayMode, .all)
        XCTAssertTrue(viewModel.viewState.cards.allSatisfy { !$0.isLocked })
    }

    func testDiscoveredCardStorePersistsCardIds() {
        let defaults = makeDefaults()
        let firstStore = DiscoveredCardStore(defaults: defaults, key: "cards")
        firstStore.markDiscovered("fish-1")

        let secondStore = DiscoveredCardStore(defaults: defaults, key: "cards")

        XCTAssertEqual(secondStore.discoveredCardIds, Set(["fish-1"]))
    }

    private func makeStore(
        suiteName: String = "FinspanTests.CardLibraryViewModelTests.\(#function)"
    ) -> DiscoveredCardStore {
        DiscoveredCardStore(defaults: makeDefaults(suiteName: suiteName), key: "cards")
    }

    private func makeDefaults(
        suiteName: String = "FinspanTests.CardLibraryViewModelTests.\(#function)"
    ) -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
