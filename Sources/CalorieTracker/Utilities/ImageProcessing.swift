import UIKit

enum ImageProcessing {

    /// Long-edge limit for uploads. Food photos do not need the full high-resolution
    /// tier, and this keeps image tokens — and so cost — to roughly a third.
    /// Raise it if you start photographing labels or menus with small text.
    static let maxLongEdge: CGFloat = 1568

    /// Downscale and JPEG-encode ready for upload. Returns nil only if encoding fails.
    static func prepareForUpload(
        _ image: UIImage,
        maxLongEdge: CGFloat = ImageProcessing.maxLongEdge,
        quality: CGFloat = 0.8
    ) -> Data? {
        downscale(image, maxLongEdge: maxLongEdge).jpegData(compressionQuality: quality)
    }

    /// Scales the image so its longest edge is at most `maxLongEdge`, preserving
    /// aspect ratio. Images already within the limit are returned redrawn upright
    /// so EXIF orientation does not survive into the upload.
    static func downscale(_ image: UIImage, maxLongEdge: CGFloat = ImageProcessing.maxLongEdge) -> UIImage {
        let size = image.size
        guard size.width > 0, size.height > 0 else { return image }

        let longest = max(size.width, size.height)
        let scale = longest > maxLongEdge ? maxLongEdge / longest : 1
        let target = CGSize(width: (size.width * scale).rounded(), height: (size.height * scale).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
