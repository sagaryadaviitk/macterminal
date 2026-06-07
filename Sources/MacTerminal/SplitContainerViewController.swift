import AppKit
import MacTerminalCore

final class SplitContainerViewController: NSSplitViewController {
    private let axis: SplitAxis
    private let ratio: Double
    private var appliedInitialRatio = false

    init(axis: SplitAxis, ratio: Double) {
        self.axis = axis
        self.ratio = ratio
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.isVertical = axis == .leftRight
        splitView.dividerStyle = .thin
        splitView.wantsLayer = true
        splitView.layer?.backgroundColor = NSColor.black.cgColor
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        guard !appliedInitialRatio, splitView.arrangedSubviews.count == 2 else {
            return
        }

        let length = splitView.isVertical ? splitView.bounds.width : splitView.bounds.height
        guard length > 80 else {
            return
        }

        splitView.setPosition(length * min(max(ratio, 0.15), 0.85), ofDividerAt: 0)
        appliedInitialRatio = true
    }
}
