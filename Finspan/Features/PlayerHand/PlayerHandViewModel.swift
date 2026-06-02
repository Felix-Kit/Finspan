import Combine

final class PlayerHandViewModel: ObservableObject {
    @Published var cards: [Card] = []
}
