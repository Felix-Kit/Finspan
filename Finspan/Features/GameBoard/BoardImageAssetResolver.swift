import Foundation

#if canImport(UIKit)
import UIKit

/// Loads board artwork copied into the app bundle as standalone raster files.
///
/// `Image(_:)` only resolved the asset-catalog namespace in this project, while
/// board artwork is intentionally kept under `Resources/BoardAssets`. Keeping
/// the decoded image cached also avoids repeatedly decoding the large player mat
/// whenever transient board presentation state changes.
@MainActor
enum BoardImageAssetResolver {
    private static var imageCache: [String: UIImage] = [:]

    static func image(
        named resourceName: String,
        bundle: Bundle = .main
    ) -> UIImage? {
        let cacheKey = "\(bundle.bundlePath)|\(resourceName)"
        if let cachedImage = imageCache[cacheKey] {
            return cachedImage
        }

        guard let url = resourceURL(named: resourceName, bundle: bundle),
              let image = UIImage(contentsOfFile: url.path)
        else {
            return nil
        }

        imageCache[cacheKey] = image
        return image
    }

    static func resourceURL(
        named resourceName: String,
        bundle: Bundle = .main
    ) -> URL? {
        let resource = resourceName as NSString
        let pathExtension = resource.pathExtension.isEmpty ? "png" : resource.pathExtension
        let baseName = resource.deletingPathExtension

        return bundle.url(forResource: baseName, withExtension: pathExtension)
            ?? bundle.url(
                forResource: baseName,
                withExtension: pathExtension,
                subdirectory: "BoardAssets"
            )
    }
}
#endif
