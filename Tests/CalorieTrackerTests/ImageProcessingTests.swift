import XCTest
import UIKit
@testable import CalorieTracker

final class ImageProcessingTests: XCTestCase {

    private func makeImage(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
            .image { context in
                UIColor.systemGreen.setFill()
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
    }

    func testDownscalesToLongEdgeLimit() {
        let image = makeImage(width: 3000, height: 1500)

        let result = ImageProcessing.downscale(image, maxLongEdge: 1568)

        XCTAssertEqual(result.size.width, 1568, accuracy: 1)
        XCTAssertEqual(result.size.height, 784, accuracy: 1)
    }

    func testPreservesAspectRatioWhenPortrait() {
        let image = makeImage(width: 1000, height: 2500)

        let result = ImageProcessing.downscale(image, maxLongEdge: 1568)

        XCTAssertEqual(result.size.height, 1568, accuracy: 1)
        XCTAssertEqual(result.size.width / result.size.height, 0.4, accuracy: 0.01)
    }

    func testDoesNotUpscaleSmallImages() {
        let image = makeImage(width: 400, height: 300)

        let result = ImageProcessing.downscale(image, maxLongEdge: 1568)

        XCTAssertEqual(result.size.width, 400, accuracy: 1)
        XCTAssertEqual(result.size.height, 300, accuracy: 1)
    }

    func testPrepareForUploadProducesJPEGData() throws {
        let image = makeImage(width: 2400, height: 1800)

        let data = try XCTUnwrap(ImageProcessing.prepareForUpload(image))

        XCTAssertFalse(data.isEmpty)
        // JPEG magic number.
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8])

        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(decoded.size.width, decoded.size.height), ImageProcessing.maxLongEdge + 1)
    }
}
