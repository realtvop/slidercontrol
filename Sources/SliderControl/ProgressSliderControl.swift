import UIKit

/// A progress slider with two text labels below the track and an optional center view.
/// Configure values, colors and callbacks through `slider`.
public final class ProgressSliderControl: UIView {
    public let slider = SliderControl()
    public let leadingTextLabel = UILabel()
    public let trailingTextLabel = UILabel()

    public var leadingText: String? {
        get { leadingTextLabel.text }
        set { leadingTextLabel.text = newValue }
    }

    public var trailingText: String? {
        get { trailingTextLabel.text }
        set { trailingTextLabel.text = newValue }
    }

    /// The view retains its own size and interaction while the slider is active.
    /// Supply an intrinsic content size or explicit size constraints, as usual in Auto Layout.
    public var centerAccessoryView: UIView? {
        didSet {
            guard oldValue !== centerAccessoryView else { return }
            oldValue?.removeFromSuperview()
            if let view = centerAccessoryView {
                centerStack.addArrangedSubview(view)
            }
            invalidateIntrinsicContentSize()
            setNeedsLayout()
        }
    }

    private let stack = UIStackView()
    private let footer = UIStackView()
    private let centerStack = UIStackView()
    private var isActive = false

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: stack.systemLayoutSizeFitting(UIView.layoutFittingCompressedSize).height)
    }

    public override func layoutSubviews() {
        let isRTL = effectiveUserInterfaceLayoutDirection == .rightToLeft
        let direction: UISemanticContentAttribute = isRTL ? .forceRightToLeft : .forceLeftToRight
        stack.semanticContentAttribute = direction
        footer.semanticContentAttribute = direction
        slider.semanticContentAttribute = direction
        leadingTextLabel.textAlignment = isRTL ? .right : .left
        trailingTextLabel.textAlignment = isRTL ? .left : .right
        super.layoutSubviews()
        updateLabelTransforms()
    }

    private func setup() {
        slider.behavior = .progress
        slider.addTarget(self, action: #selector(editingBegan), for: .editingDidBegin)
        slider.addTarget(self, action: #selector(editingEnded), for: .editingDidEnd)

        for label in [leadingTextLabel, trailingTextLabel] {
            label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            label.textColor = .secondaryLabel
            label.lineBreakMode = .byTruncatingTail
        }

        centerStack.alignment = .center
        centerStack.setContentHuggingPriority(.required, for: .horizontal)
        centerStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        footer.alignment = .center
        footer.spacing = 8
        footer.addArrangedSubview(leadingTextLabel)
        footer.addArrangedSubview(centerStack)
        footer.addArrangedSubview(trailingTextLabel)

        stack.axis = .vertical
        stack.addArrangedSubview(slider)
        stack.addArrangedSubview(footer)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            slider.heightAnchor.constraint(equalToConstant: 24),
            footer.heightAnchor.constraint(greaterThanOrEqualToConstant: 20),
            leadingTextLabel.widthAnchor.constraint(equalTo: trailingTextLabel.widthAnchor)
        ])
    }

    @objc private func editingBegan() {
        setActive(true)
    }

    @objc private func editingEnded() {
        setActive(false)
    }

    private func setActive(_ active: Bool) {
        layoutIfNeeded()
        isActive = active
        UIView.animate(withDuration: active ? 0.2 : 0.3, delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.updateLabelTransforms()
        }
    }

    private func updateLabelTransforms() {
        let scale: CGFloat = isActive ? 1.1 : 1
        let direction: CGFloat = effectiveUserInterfaceLayoutDirection == .leftToRight ? 1 : -1
        // Anchor the text to the outside edges. The center stack is never transformed.
        leadingTextLabel.transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
            tx: direction * leadingTextLabel.bounds.width * (scale - 1) / 2, ty: 0)
        trailingTextLabel.transform = CGAffineTransform(a: scale, b: 0, c: 0, d: scale,
            tx: -direction * trailingTextLabel.bounds.width * (scale - 1) / 2, ty: 0)
    }
}
