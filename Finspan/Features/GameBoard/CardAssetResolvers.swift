import CoreText
import Foundation
import SwiftUI

enum CardAssetKind: String, Equatable {
    case background
    case fishImage
    case font
    case icon
    case triggerBand
}

struct CardAssetReference: Equatable {
    let kind: CardAssetKind
    let logicalName: String
    let resourceName: String
    let fileExtension: String
    let fileName: String
    let subdirectory: String?
    let url: URL
}

struct MissingCardAsset: Equatable {
    let kind: CardAssetKind
    let logicalName: String
    let canonicalName: String
    let searchedSubdirectories: [String]
    let searchedExtensions: [String]
}

struct CardAssetLookup: Equatable {
    let requestedName: String
    let canonicalName: String
    let asset: CardAssetReference?
    let missingAsset: MissingCardAsset?

    var isResolved: Bool {
        asset != nil
    }
}

final class CardAssetResolver: @unchecked Sendable {
    static let shared = CardAssetResolver()

    private struct CacheKey: Hashable {
        let kind: CardAssetKind
        let requestedName: String
        let canonicalName: String
        let subdirectories: [String]
        let fileExtensions: [String]
    }

    private let bundle: Bundle
    private let lock = NSLock()
    private var cache: [CacheKey: CardAssetLookup] = [:]

    init(bundle: Bundle = Bundle(for: CardAssetResolverBundleToken.self)) {
        self.bundle = bundle
    }

    func resolve(
        kind: CardAssetKind,
        requestedName: String,
        canonicalName: String? = nil,
        subdirectories: [String],
        fileExtensions: [String]
    ) -> CardAssetLookup {
        let resolvedCanonicalName = canonicalName ?? requestedName
        let key = CacheKey(
            kind: kind,
            requestedName: requestedName,
            canonicalName: resolvedCanonicalName,
            subdirectories: subdirectories,
            fileExtensions: fileExtensions
        )

        lock.lock()
        if let cached = cache[key] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        let lookup = makeLookup(
            kind: kind,
            requestedName: requestedName,
            canonicalName: resolvedCanonicalName,
            subdirectories: subdirectories,
            fileExtensions: fileExtensions
        )

        lock.lock()
        cache[key] = lookup
        lock.unlock()
        return lookup
    }

    private func makeLookup(
        kind: CardAssetKind,
        requestedName: String,
        canonicalName: String,
        subdirectories: [String],
        fileExtensions: [String]
    ) -> CardAssetLookup {
        for subdirectory in subdirectories {
            for fileExtension in fileExtensions {
                if let exact = exactURL(
                    resourceName: canonicalName,
                    fileExtension: fileExtension,
                    subdirectory: subdirectory
                ) {
                    return resolvedLookup(
                        kind: kind,
                        requestedName: requestedName,
                        canonicalName: canonicalName,
                        url: exact,
                        subdirectory: subdirectory
                    )
                }
                if let prefixed = prefixedURL(
                    resourceNamePrefix: canonicalName,
                    fileExtension: fileExtension,
                    subdirectory: subdirectory
                ) {
                    return resolvedLookup(
                        kind: kind,
                        requestedName: requestedName,
                        canonicalName: canonicalName,
                        url: prefixed,
                        subdirectory: subdirectory
                    )
                }
            }
        }

        return CardAssetLookup(
            requestedName: requestedName,
            canonicalName: canonicalName,
            asset: nil,
            missingAsset: MissingCardAsset(
                kind: kind,
                logicalName: requestedName,
                canonicalName: canonicalName,
                searchedSubdirectories: subdirectories,
                searchedExtensions: fileExtensions
            )
        )
    }

    private func resolvedLookup(
        kind: CardAssetKind,
        requestedName: String,
        canonicalName: String,
        url: URL,
        subdirectory: String
    ) -> CardAssetLookup {
        let resourceName = url.deletingPathExtension().lastPathComponent
        return CardAssetLookup(
            requestedName: requestedName,
            canonicalName: canonicalName,
            asset: CardAssetReference(
                kind: kind,
                logicalName: requestedName,
                resourceName: resourceName,
                fileExtension: url.pathExtension,
                fileName: url.lastPathComponent,
                subdirectory: subdirectory.isEmpty ? nil : subdirectory,
                url: url
            ),
            missingAsset: nil
        )
    }

    private func exactURL(
        resourceName: String,
        fileExtension: String,
        subdirectory: String
    ) -> URL? {
        if subdirectory.isEmpty {
            return bundle.url(forResource: resourceName, withExtension: fileExtension)
        }
        return bundle.url(forResource: resourceName, withExtension: fileExtension, subdirectory: subdirectory)
    }

    private func prefixedURL(
        resourceNamePrefix: String,
        fileExtension: String,
        subdirectory: String
    ) -> URL? {
        let urls: [URL]?
        if subdirectory.isEmpty {
            urls = bundle.urls(forResourcesWithExtension: fileExtension, subdirectory: nil)
        } else {
            urls = bundle.urls(forResourcesWithExtension: fileExtension, subdirectory: subdirectory)
        }
        return urls?
            .filter { $0.lastPathComponent.hasPrefix("\(resourceNamePrefix).") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .first
    }
}

final class CardSymbolAssetResolver: @unchecked Sendable {
    static let shared = CardSymbolAssetResolver()

    private static let aliases: [String: String] = [
        "Card": "FishFromHand",
        "ConsumeFishFromHand": "FishFromHandConsume",
        "Midnight": "Night",
        "Night": "Night",
        "School": "SchoolFish",
        "Sunlit": "Sun",
        "Twilight": "Dusk"
    ]

    private let assetResolver: CardAssetResolver

    init(assetResolver: CardAssetResolver = .shared) {
        self.assetResolver = assetResolver
    }

    func icon(
        named name: String,
        fallbackText: String,
        accessibilityText: String
    ) -> FishCardFaceIconViewState {
        let canonicalName = Self.aliases[name] ?? name
        let lookup = assetResolver.resolve(
            kind: .icon,
            requestedName: name,
            canonicalName: canonicalName,
            subdirectories: CardAssetDirectories.icons,
            fileExtensions: ["svg", "png", "webp"]
        )
        return FishCardFaceIconViewState(
            assetName: canonicalName,
            fallbackText: fallbackText,
            accessibilityText: accessibilityText,
            asset: lookup.asset,
            missingAsset: lookup.missingAsset
        )
    }

    func lookup(named name: String) -> CardAssetLookup {
        let canonicalName = Self.aliases[name] ?? name
        return assetResolver.resolve(
            kind: .icon,
            requestedName: name,
            canonicalName: canonicalName,
            subdirectories: CardAssetDirectories.icons,
            fileExtensions: ["svg", "png", "webp"]
        )
    }
}

final class AbilityTokenAssetResolver: @unchecked Sendable {
    static let shared = AbilityTokenAssetResolver()

    static let supportedTokenNames: Set<String> = [
        "AllPlayers",
        "AnyCoral",
        "ArrowDown",
        "Bioluminescent",
        "BlueCoral",
        "Camouflage",
        "Card",
        "ConsumeFish",
        "ConsumeFish1",
        "ConsumeFish2",
        "ConsumeFish3",
        "Discard",
        "DrawCard",
        "Dusk",
        "Electric",
        "Estuary",
        "FishEgg",
        "FishFromHand",
        "FishFromHandConsume",
        "FishHatch",
        "FishLengthLarge",
        "FishLengthMedium",
        "FishLengthSmall",
        "FlipperBlue",
        "FlipperGreen",
        "FlipperPurple",
        "FreePlayFishFromHand",
        "GreenCoral",
        "Midnight",
        "Night",
        "PlayFishAny",
        "PlayFishBottomRow",
        "PlayFishTopRow",
        "Predator",
        "PurpleCoral",
        "School",
        "SchoolFeederMove",
        "SchoolFish",
        "Sun",
        "Sunlit",
        "Twilight",
        "UnSchoolFish",
        "Venomous",
        "Wave",
        "YoungFish"
    ]

    private let symbolResolver: CardSymbolAssetResolver

    init(symbolResolver: CardSymbolAssetResolver = .shared) {
        self.symbolResolver = symbolResolver
    }

    func icon(
        for token: String,
        fallbackText: String,
        accessibilityText: String
    ) -> FishCardFaceIconViewState {
        symbolResolver.icon(
            named: token,
            fallbackText: fallbackText,
            accessibilityText: accessibilityText
        )
    }

    func lookup(for token: String) -> CardAssetLookup {
        symbolResolver.lookup(named: token)
    }
}

final class FishImageAssetResolver: @unchecked Sendable {
    static let shared = FishImageAssetResolver()

    private let assetResolver: CardAssetResolver

    init(assetResolver: CardAssetResolver = .shared) {
        self.assetResolver = assetResolver
    }

    func image(forSourceId sourceId: Int) -> CardAssetLookup {
        assetResolver.resolve(
            kind: .fishImage,
            requestedName: "\(sourceId)",
            subdirectories: CardAssetDirectories.fish,
            fileExtensions: ["webp", "png"]
        )
    }

    func image(forCardId cardId: CardID, visualAssetName: String?) -> CardAssetLookup {
        if let sourceId = sourceId(fromVisualAssetName: visualAssetName) ?? sourceId(fromCardId: cardId) {
            return image(forSourceId: sourceId)
        }
        let requestedName = visualAssetName?.removingPathExtension ?? cardId.replacingOccurrences(of: ".", with: "_")
        return assetResolver.resolve(
            kind: .fishImage,
            requestedName: requestedName,
            subdirectories: CardAssetDirectories.fish,
            fileExtensions: ["webp", "png"]
        )
    }

    func sourceId(fromCardId cardId: CardID) -> Int? {
        guard let trailing = cardId.split(separator: ".").last else {
            return nil
        }
        return Int(trailing)
    }

    private func sourceId(fromVisualAssetName visualAssetName: String?) -> Int? {
        guard let visualAssetName else {
            return nil
        }
        return Int(visualAssetName.removingPathExtension)
    }
}

struct CardTriggerStyle: Equatable {
    let abilityPanelStyle: FishCardAbilityPanelStyle
    let stripAssetPrefix: String?
    let stripAsset: CardAssetReference?
    let missingAsset: MissingCardAsset?
}

final class CardTriggerStyleResolver: @unchecked Sendable {
    static let shared = CardTriggerStyleResolver()

    private let assetResolver: CardAssetResolver

    init(assetResolver: CardAssetResolver = .shared) {
        self.assetResolver = assetResolver
    }

    func style(for triggerText: String?) -> CardTriggerStyle {
        guard let triggerText else {
            return CardTriggerStyle(
                abilityPanelStyle: .none,
                stripAssetPrefix: nil,
                stripAsset: nil,
                missingAsset: nil
            )
        }

        if triggerText == AppStrings.GameBoard.abilityTriggerIfActivated {
            return stripStyle(prefix: "IfActivated", panelStyle: .tanBrush)
        }
        if triggerText == AppStrings.GameBoard.abilityTriggerGameEnd {
            return stripStyle(prefix: "GameEnd", panelStyle: .yellowBrush)
        }
        return CardTriggerStyle(
            abilityPanelStyle: .none,
            stripAssetPrefix: nil,
            stripAsset: nil,
            missingAsset: nil
        )
    }

    private func stripStyle(prefix: String, panelStyle: FishCardAbilityPanelStyle) -> CardTriggerStyle {
        let lookup = assetResolver.resolve(
            kind: .triggerBand,
            requestedName: prefix,
            subdirectories: CardAssetDirectories.backgrounds,
            fileExtensions: ["png", "webp"]
        )
        return CardTriggerStyle(
            abilityPanelStyle: panelStyle,
            stripAssetPrefix: prefix,
            stripAsset: lookup.asset,
            missingAsset: lookup.missingAsset
        )
    }
}

final class CardFontStyleResolver: @unchecked Sendable {
    static let shared = CardFontStyleResolver()

    enum FontRole {
        case title
        case latin
        case body
    }

    private let assetResolver: CardAssetResolver
    private let lock = NSLock()
    private var didRegisterFonts = false

    init(assetResolver: CardAssetResolver = .shared) {
        self.assetResolver = assetResolver
    }

    func registerFontsIfNeeded() {
        lock.lock()
        if didRegisterFonts {
            lock.unlock()
            return
        }
        didRegisterFonts = true
        lock.unlock()

        for lookup in fontLookups() {
            guard let url = lookup.asset?.url else {
                continue
            }
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    func font(_ role: FontRole, size: CGFloat) -> Font {
        registerFontsIfNeeded()
        switch role {
        case .title:
            return .custom("Panforte Pro", size: size)
        case .latin:
            return .custom("Dolce", size: size)
        case .body:
            return .custom("Lexus Roman Optical", size: size)
        }
    }

    func fontLookups() -> [CardAssetLookup] {
        [
            assetResolver.resolve(
                kind: .font,
                requestedName: "Panforte-Pro.ttf",
                canonicalName: "Panforte-Pro.ttf",
                subdirectories: CardAssetDirectories.fonts,
                fileExtensions: ["woff"]
            ),
            assetResolver.resolve(
                kind: .font,
                requestedName: "Dolce-Medium",
                canonicalName: "Dolce-Medium",
                subdirectories: CardAssetDirectories.fonts,
                fileExtensions: ["otf"]
            ),
            assetResolver.resolve(
                kind: .font,
                requestedName: "LexusRomanOpti-RegularIt",
                canonicalName: "LexusRomanOpti-RegularIt",
                subdirectories: CardAssetDirectories.fonts,
                fileExtensions: ["otf"]
            )
        ]
    }
}

enum CardAssetDirectories {
    static let backgrounds = [
        "Resources/CardAssets/backgrounds",
        "CardAssets/backgrounds",
        "backgrounds",
        ""
    ]

    static let fish = [
        "Resources/CardAssets/fish",
        "CardAssets/fish",
        "fish",
        ""
    ]

    static let fonts = [
        "Resources/CardAssets/fonts",
        "CardAssets/fonts",
        "fonts",
        ""
    ]

    static let icons = [
        "Resources/CardAssets/icons",
        "CardAssets/icons",
        "icons",
        ""
    ]
}

private final class CardAssetResolverBundleToken: NSObject {}

private extension String {
    var removingPathExtension: String {
        (self as NSString).deletingPathExtension
    }
}
