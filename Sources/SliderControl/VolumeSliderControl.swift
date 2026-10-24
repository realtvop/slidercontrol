import UIKit

/// A volume slider flanked by minimum and maximum volume icons.
/// Configure values, colors and callbacks through `slider`.
public final class VolumeSliderControl: UIView {
    public let slider = SliderControl()
    public let minimumImageView = UIImageView()
    public let maximumImageView = UIImageView()

    public var minimumImage: UIImage? {
        get { minimumImageView.image }
        set { minimumImageView.image = newValue }
    }

    public var maximumImage: UIImage? {
        get { maximumImageView.image }
        set { maximumImageView.image = newValue }
    }

    private let stack = UIStackView()

    public override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    public override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 24)
    }

    public override func layoutSubviews() {
        let direction: UISemanticContentAttribute = effectiveUserInterfaceLayoutDirection == .leftToRight
            ? .forceLeftToRight : .forceRightToLeft
        if stack.semanticContentAttribute != direction {
            stack.semanticContentAttribute = direction
            slider.semanticContentAttribute = direction
        }
        super.layoutSubviews()
    }

    private func setup() {
        slider.behavior = .volume
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let configuration = UIImage.SymbolConfiguration(pointSize: 14)
        minimumImage = UIImage(systemName: "speaker.fill", withConfiguration: configuration)
        maximumImage = UIImage(systemName: "speaker.wave.3.fill", withConfiguration: configuration)

        for imageView in [minimumImageView, maximumImageView] {
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = .secondaryLabel
            imageView.isAccessibilityElement = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 20),
                imageView.heightAnchor.constraint(equalToConstant: 20)
            ])
        }

        stack.alignment = .center
        stack.spacing = 12
        stack.addArrangedSubview(minimumImageView)
        stack.addArrangedSubview(slider)
        stack.addArrangedSubview(maximumImageView)
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: topAnchor),
            stack.leadingAnchor.constraint(equalTo: leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor),
            slider.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
}
