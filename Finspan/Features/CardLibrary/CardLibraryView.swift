import SwiftUI

struct CardLibraryView: View {
    @ObservedObject var viewModel: CardLibraryViewModel
    var onBack: (() -> Void)?

    var body: some View {
        let viewState = viewModel.viewState
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Button(AppStrings.Lobby.back) {
                    onBack?()
                }
                .buttonStyle(.bordered)

                Spacer()

                Picker(AppStrings.Lobby.CardLibrary.title, selection: $viewModel.displayMode) {
                    Text(AppStrings.Lobby.CardLibrary.discoveredMode)
                        .tag(CardLibraryDisplayMode.discovered)
                    Text(AppStrings.Lobby.CardLibrary.allMode)
                        .tag(CardLibraryDisplayMode.all)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)
            }

#if DEBUG
            TextField(AppStrings.Lobby.CardLibrary.qaSearchPlaceholder, text: $viewModel.qaSearchText)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
#endif

            if viewState.cards.isEmpty {
                ContentUnavailableView(
                    viewState.emptyText,
                    systemImage: "rectangle.stack"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 150), spacing: 14)],
                        spacing: 16
                    ) {
                        ForEach(viewState.cards) { card in
                            cardTile(card)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(24)
    }

    private func cardTile(_ card: CardLibraryCardViewState) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                FishCardFaceView(viewState: card.cardFace)
                    .aspectRatio(CardRenderMetrics.cardAspectRatio, contentMode: .fit)
                    .blur(radius: card.isLocked ? 4 : 0)
                    .opacity(card.isLocked ? 0.72 : 1)

                if card.isLocked {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black.opacity(0.48))
                    VStack(spacing: 6) {
                        Image(systemName: "lock.fill")
                            .font(.headline.weight(.bold))
                        Text(AppStrings.Lobby.CardLibrary.locked)
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                }
            }
            .overlay(alignment: .topTrailing) {
                Text(card.expansionBadgeText)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.58)))
                    .padding(6)
            }

            Text(card.cardFace.displayName)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(card.isLocked ? .secondary : .primary)
        }
    }
}
