import SwiftUI
import UIKit

/// A page that can be pinched and double-tapped.
///
/// The pager on top of this is a SwiftUI scroll view, so the two have to agree
/// on who owns a gesture: the reader disables paging while this view is zoomed
/// (see `onZoomChanged`), and while it is not, this view does not pan anywhere.
struct ZoomableImage: UIViewRepresentable {
    let image: UIImage
    var onSingleTap: () -> Void = {}
    var onZoomChanged: (Bool) -> Void = { _ in }

    func makeUIView(context: Context) -> ZoomScene {
        let view = ZoomScene()
        view.onSingleTap = onSingleTap
        view.onZoomChanged = onZoomChanged
        view.setImage(image)
        return view
    }

    func updateUIView(_ view: ZoomScene, context: Context) {
        view.onSingleTap = onSingleTap
        view.onZoomChanged = onZoomChanged
        view.setImage(image)
    }
}

final class ZoomScene: UIView, UIScrollViewDelegate {
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()

    var onSingleTap: (() -> Void)?
    var onZoomChanged: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black

        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.backgroundColor = .black
        addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(doubleTapped(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        let singleTap = UITapGestureRecognizer(target: self, action: #selector(singleTapped))
        singleTap.require(toFail: doubleTap)
        scrollView.addGestureRecognizer(singleTap)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        scrollView.frame = bounds
        // Only lay the page out again while it is at rest: relaying it out
        // mid-zoom would undo the zoom.
        if scrollView.zoomScale <= scrollView.minimumZoomScale + 0.001 {
            imageView.frame = CGRect(origin: .zero, size: bounds.size)
            scrollView.contentSize = bounds.size
            scrollView.zoomScale = scrollView.minimumZoomScale
        }
    }

    func setImage(_ image: UIImage) {
        guard imageView.image !== image else { return }
        scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
        imageView.image = image
        setNeedsLayout()
    }

    // MARK: - Zooming

    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        imageView
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        // Keep the page centred while it is smaller than the viewport in either
        // direction — at rest both, while zoomed out.
        let horizontal = max((scrollView.bounds.width - scrollView.contentSize.width) * 0.5, 0)
        let vertical = max((scrollView.bounds.height - scrollView.contentSize.height) * 0.5, 0)
        imageView.center = CGPoint(
            x: scrollView.contentSize.width * 0.5 + horizontal,
            y: scrollView.contentSize.height * 0.5 + vertical
        )
    }

    func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
        reportZoom()
    }

    private func reportZoom() {
        onZoomChanged?(scrollView.zoomScale > scrollView.minimumZoomScale + 0.01)
    }

    // MARK: - Taps

    @objc private func singleTapped() {
        onSingleTap?()
    }

    @objc private func doubleTapped(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > scrollView.minimumZoomScale {
            scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            return
        }
        let point = gesture.location(in: imageView)
        let scale: CGFloat = 2.5
        let width = scrollView.bounds.width / scale
        let height = scrollView.bounds.height / scale
        let rect = CGRect(
            x: point.x - width * 0.5,
            y: point.y - height * 0.5,
            width: width,
            height: height
        )
        scrollView.zoom(to: rect, animated: true)
    }
}
