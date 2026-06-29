import XCTest
@testable import Feedflow

@MainActor
final class FourD4YImageViewerTests: XCTestCase {

    private let service = FourD4YService()

    func testDiscuzFileAttributeProvidesOriginalImage() throws {
        let tag = #"<img src="attachments/month_2606/photo.thumb.jpg" file="attachments/month_2606/photo.jpg">"#

        let source = try XCTUnwrap(service.contentImageSource(from: tag))

        XCTAssertEqual(
            source.thumbnailURL,
            "https://www.4d4y.com/forum/attachments/month_2606/photo.thumb.jpg"
        )
        XCTAssertEqual(
            source.originalURL,
            "https://www.4d4y.com/forum/attachments/month_2606/photo.jpg"
        )
    }

    func testZoomfileTakesPriorityAsOriginalImage() throws {
        let tag = #"<img src="https://img.4d4y.com/photo.thumb.jpg" file="https://img.4d4y.com/photo.medium.jpg" zoomfile="https://img.4d4y.com/photo.jpg">"#

        let source = try XCTUnwrap(service.contentImageSource(from: tag))

        XCTAssertEqual(source.thumbnailURL, "https://img.4d4y.com/photo.thumb.jpg")
        XCTAssertEqual(source.originalURL, "https://img.4d4y.com/photo.jpg")
    }

    func testThumbFilenameFallsBackToOriginalFilename() throws {
        let tag = #"<img src="//img.4d4y.com/photo.thumb.png">"#

        let source = try XCTUnwrap(service.contentImageSource(from: tag))

        XCTAssertEqual(source.thumbnailURL, "https://img.4d4y.com/photo.thumb.png")
        XCTAssertEqual(source.originalURL, "https://img.4d4y.com/photo.png")
    }

    func testImageMarkerKeepsThumbnailAndOriginalSeparate() throws {
        let urls = try XCTUnwrap(
            ParsedContentView.imageURLs(
                fromMarkerPayload: "https://img/thumb.jpg|https://img/original.jpg"
            )
        )

        XCTAssertEqual(urls.thumbnailURL, "https://img/thumb.jpg")
        XCTAssertEqual(urls.originalURL, "https://img/original.jpg")
    }

    func testLegacyImageMarkerUsesSameURLForBothViews() throws {
        let urls = try XCTUnwrap(
            ParsedContentView.imageURLs(fromMarkerPayload: "https://img/image.jpg")
        )

        XCTAssertEqual(urls.thumbnailURL, "https://img/image.jpg")
        XCTAssertEqual(urls.originalURL, "https://img/image.jpg")
    }

    func testDoubleTapTogglesZoomInAndOut() {
        XCTAssertEqual(
            FullScreenImageView.scaleAfterDoubleTap(
                currentScale: 1,
                minScale: 1,
                zoomScale: 2.5
            ),
            2.5
        )
        XCTAssertEqual(
            FullScreenImageView.scaleAfterDoubleTap(
                currentScale: 2.5,
                minScale: 1,
                zoomScale: 2.5
            ),
            1
        )
    }

    func testZoomedImageCanMoveLeftAndRight() {
        let movedRight = FullScreenImageView.offsetAfterDrag(
            lastOffset: .zero,
            translation: CGSize(width: 80, height: 0),
            scale: 2.5,
            minScale: 1
        )
        let movedLeft = FullScreenImageView.offsetAfterDrag(
            lastOffset: movedRight,
            translation: CGSize(width: -140, height: 0),
            scale: 2.5,
            minScale: 1
        )

        XCTAssertEqual(movedRight.width, 80)
        XCTAssertEqual(movedLeft.width, -60)
    }

    func testUnzoomedImageDoesNotMove() {
        let offset = FullScreenImageView.offsetAfterDrag(
            lastOffset: .zero,
            translation: CGSize(width: 80, height: 0),
            scale: 1,
            minScale: 1
        )

        XCTAssertEqual(offset, .zero)
    }
}
