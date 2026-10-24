import UIKit

/// A volume slider flanked by minimum and maximum volume icons.
/// Each icon follows its track end when that end stretches and springs back.
/// Configure values, colors and callbacks through `slider`.
public final class VolumeSliderControl: UIView {
    public let slider = SliderControl()
    public let minimumImageView = UIImageView()
    public let maximumImageView = UIImageView()

    public var minimumImage: UIImage? {
        get { minimumImageView.image }
        set {
            minimumImageView.image = newValue
            minimumImageView.contentMode = newValue?.isSymbolImage == true ? .center : .scaleAspectFit
        }
    }

    public var maximumImage: UIImage? {
        get { maximumImageView.image }
        set {
            maximumImageView.image = newValue
            maximumImageView.contentMode = newValue?.isSymbolImage == true ? .center : .scaleAspectFit
        }
    }

    private let stack = UIStackView()
    private let minimumSlot = UIView()
    private let maximumSlot = UIView()
    private let minimumDisplacement = UIView()
    private let maximumDisplacement = UIView()
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
        updateIconOutsets()
    }

    private func setup() {
        slider.behavior = .volume
        slider.addTarget(self, action: #selector(editingBegan), for: .editingDidBegin)
        slider.addTarget(self, action: #selector(editingEnded), for: .editingDidEnd)
        slider.onTrackStretchChanged = { [weak self] stretch in
            // Follow the same per-frame displacement as the track, including its spring return.
            self?.minimumDisplacement.transform = CGAffineTransform(translationX: stretch.minimumOffset, y: 0)
            self?.maximumDisplacement.transform = CGAffineTransform(translationX: stretch.maximumOffset, y: 0)
        }
        slider.onBoundaryReached = { [weak self] minimum in
            guard let self = self else { return }
            self.pulse(minimum ? self.minimumImageView : self.maximumImageView)
        }
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let configuration = UIImage.SymbolConfiguration(pointSize: 14)
        minimumImage = UIImage(systemName: "speaker.fill", withConfiguration: configuration)
        maximumImage = UIImage(systemName: "speaker.wave.3.fill", withConfiguration: configuration)

        for imageView in [minimumImageView, maximumImageView] {
            imageView.tintColor = .label
            imageView.alpha = 0.6
            imageView.isAccessibilityElement = false
            NSLayoutConstraint.activate([
                imageView.widthAnchor.constraint(equalToConstant: 20),
                imageView.heightAnchor.constraint(equalToConstant: 20)
            ])
        }

        // Separate activation, stretch and symbol scaling so a pulse cannot delay track following.
        for (slot, displacement, image) in [
            (minimumSlot, minimumDisplacement, minimumImageView),
            (maximumSlot, maximumDisplacement, maximumImageView)
        ] {
            slot.isUserInteractionEnabled = false
            slot.addSubview(displacement)
            displacement.addSubview(image)
            displacement.translatesAutoresizingMaskIntoConstraints = false
            image.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                slot.widthAnchor.constraint(equalToConstant: 20),
                slot.heightAnchor.constraint(equalToConstant: 20),
                displacement.leadingAnchor.constraint(equalTo: slot.leadingAnchor),
                displacement.topAnchor.constraint(equalTo: slot.topAnchor),
                displacement.widthAnchor.constraint(equalTo: slot.widthAnchor),
                displacement.heightAnchor.constraint(equalTo: slot.heightAnchor),
                image.centerXAnchor.constraint(equalTo: displacement.centerXAnchor),
                image.centerYAnchor.constraint(equalTo: displacement.centerYAnchor)
            ])
        }

        stack.alignment = .center
        stack.spacing = 12
        stack.addArrangedSubview(minimumSlot)
        stack.addArrangedSubview(slider)
        stack.addArrangedSubview(maximumSlot)
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

    @objc private func editingBegan() { setActive(true) }
    @objc private func editingEnded() { setActive(false) }

    private func setActive(_ active: Bool) {
        layoutIfNeeded()
        isActive = active
        UIView.animate(withDuration: active ? 0.2 : 0.3, delay: 0,
            options: [.beginFromCurrentState, .allowUserInteraction]) {
            self.updateIconOutsets()
            for image in [self.minimumImageView, self.maximumImageView] {
                image.alpha = active ? 1 : 0.6
                image.transform = CGAffineTransform(scaleX: active ? 1.08 : 1, y: active ? 1.08 : 1)
            }
        }
    }

    private func updateIconOutsets() {
        let direction: CGFloat = effectiveUserInterfaceLayoutDirection == .leftToRight ? 1 : -1
        let outset = isActive ? slider.activeTrackOutset * direction : 0
        minimumSlot.transform = CGAffineTransform(translationX: -outset, y: 0)
        maximumSlot.transform = CGAffineTransform(translationX: outset, y: 0)
    }

    private func pulse(_ image: UIImageView) {
        // The reference briefly emphasizes just the reached end, then returns while still held.
        // An additive scale leaves activation and per-frame displacement independent.
        let animation = CAKeyframeAnimation(keyPath: "transform.scale")
        animation.values = [0, 0.25, -0.025, 0]
        animation.keyTimes = [0, 0.32, 0.72, 1]
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: 3)
        animation.duration = 0.55
        animation.isAdditive = true
        image.layer.add(animation, forKey: "volumeBoundaryPulse")
    }
}
