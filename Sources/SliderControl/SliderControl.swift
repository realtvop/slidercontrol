//
// SliderControl.swift
// SliderControl
//
// Created by Alexander Chekel on 09.09.2023.
// Copyright © 2023 Alexander Chekel. All rights reserved.
//

import Combine
import UIKit

/// Implements a slider control similar to one found in Apple Music on iOS 16.
open class SliderControl: UIControl {
    /// Progress stops at the finger; volume also coasts and stretches at its limits.
    public enum Behavior {
        case progress
        case volume
    }

    /// The interaction to reproduce. Defaults to `.progress`.
    public var behavior: Behavior = .progress {
        didSet {
            guard behavior != oldValue else { return }
            stopMotion()
            finishValueChanges()
        }
    }

    /// Indicates whether changes in the slider's value generate continuous update events.
    /// Volume includes inertial updates; when `false`, the final event waits for settling.
    /// Default value of this property is `true`.
    public var isContinuous: Bool = true
    /// A layout guide that follows track size changes in different states.
    public let trackLayoutGuide: UILayoutGuide = .init()
    /// Feedback generator used to provide haptic feedback when slider reaches minimum or maximum value.
    /// Set this property to `nil` to disable haptic feedback. Default value of this property is
    /// `ImpactFeedbackGenerator`.
    public var feedbackGenerator: (any SliderFeedbackGenerator)? = ImpactSliderFeedbackGenerator()
    /// A color set to track when user is not interacting with the slider.
    /// Default value of this property is `secondarySystemFill`.
    open var defaultTrackColor: UIColor = .secondarySystemFill {
        didSet {
            updateColors()
        }
    }
    /// A color set to progress when user is not interacting with the slider.
    /// Default value of this property is `.systemFill`.
    open var defaultProgressColor: UIColor = .systemFill {
        didSet {
            updateColors()
        }
    }
    /// A color set to track when user is interacting with the slider.
    /// Assigning `nil` to this property disables color changes in interactive state.
    /// Default value of this property is `nil`.
    open var enlargedTrackColor: UIColor? {
        didSet {
            updateColors()
        }
    }
    /// A color set to progress when user is interacting with the slider.
    /// Assigning `nil` to this property disables color changes in interactive state.
    /// Default value of this property is `nil`.
    open var enlargedProgressColor: UIColor? {
        didSet {
            updateColors()
        }
    }

    /// Range of slider values. Default value is `0...1`.
    public var valueRange: ClosedRange<Float> = 0...1 {
        didSet {
            guard valueRange != oldValue else { return }
            let previousValue = Self.internalValueRange.convert(value: Float(normalizedProgress), to: oldValue)
            stopMotion()
            hasPendingValueChange = false
            setValue(previousValue)
        }
    }

    /// The slider's current value in range set by `valueRange` property.
    public var value: Float {
        get {
            Self.internalValueRange.convert(value: Float(normalizedProgress), to: valueRange)
        }
        set {
            guard !isTracking, !isEditing, newValue != value, newValue.isFinite else { return }

            stopMotion()
            hasPendingValueChange = false
            setValue(newValue)
        }
    }

    /// Callback for editing changed event. It is called with `true` parameter
    /// when user starts dragging the slider, and then it is called again with
    /// `false` parameter when users lets go of the slider.
    public var onEditingChanged: ((Bool) -> Void)?

    /// A publisher that emits progress updates when user interacts with the slider.
    /// A Combine alternative to adding action for `UIControl.Event.valueChanged`.
    public var valuePublisher: AnyPublisher<Float, Never> {
        valueSubject.eraseToAnyPublisher()
    }

    // Lets the SwiftUI wrapper distinguish a stale binding from an external edit.
    var isAnimatingValue: Bool { displayLink != nil }

    public override var intrinsicContentSize: CGSize {
        return CGSize(width: UIView.noIntrinsicMetric, height: Self.intrinsicHeight)
    }

    private static let intrinsicHeight: CGFloat = 24
    private static let defaultTrackHeight: CGFloat = 7
    private static let enlargedTrackHeight: CGFloat = 12
    private static let internalValueRange: ClosedRange<Float> = 0...1

    private let trackView: UIView = .init()
    private let progressView: UIView = .init()

    private let valueSubject: PassthroughSubject<Float, Never> = .init()

    private var heightConstraint: NSLayoutConstraint = .init()
    private var progressConstraint: NSLayoutConstraint = .init()
    private var normalizedProgress: CGFloat = 0.5
    private var isEditing = false
    private var hasPendingValueChange = false
    private var motion = SliderMotion()
    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: TimeInterval = 0
    private var lastTouchTimestamp: TimeInterval = 0
    private var lastMovementTimestamp: TimeInterval = 0
    private var lastTouchX: CGFloat = 0
    private var dragVelocity: CGFloat = 0

    private final class DisplayLinkTarget: NSObject {
        weak var control: SliderControl?

        init(control: SliderControl) {
            self.control = control
        }

        @objc func tick(_ link: CADisplayLink) {
            guard let control = control else {
                link.invalidate()
                return
            }
            control.advanceMotion(link)
        }
    }

    override public init(frame: CGRect) {
        super.init(frame: frame)

        setup()
    }

    required public init?(coder: NSCoder) {
        super.init(coder: coder)

        setup()
    }

    deinit {
        displayLink?.invalidate()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil {
            stopMotion()
            finishEditing()
            finishValueChanges()
        }
    }

    public override func layoutSubviews() {
        let direction: UISemanticContentAttribute = effectiveUserInterfaceLayoutDirection == .leftToRight
            ? .forceLeftToRight : .forceRightToLeft
        if trackView.semanticContentAttribute != direction {
            trackView.semanticContentAttribute = direction
            progressView.semanticContentAttribute = direction
        }
        super.layoutSubviews()

        trackView.layer.cornerRadius = trackView.bounds.height / 2
        progressConstraint.constant = normalizedProgress * trackView.bounds.width
        trackView.layoutIfNeeded()
        updateStretch()
    }

    public override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        guard isEnabled else { return false }
        stopMotion()
        finishValueChanges()
        lastTouchX = touch.location(in: self).x
        lastTouchTimestamp = touch.timestamp
        lastMovementTimestamp = touch.timestamp
        dragVelocity = 0
        isEditing = true
        hasPendingValueChange = false
        sendActions(for: .editingDidBegin)
        onEditingChanged?(true)
        enlargeTrack()
        feedbackGenerator?.preapre()

        return true
    }

    public override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        updateTracking(touch)
        return true
    }

    public override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        guard isEditing else { return }
        if let touch = touch {
            updateTracking(touch)
            if touch.timestamp - lastMovementTimestamp > 0.08 {
                dragVelocity = 0
            }
        } else {
            dragVelocity = 0
        }
        if behavior == .volume && motion.release(velocity: dragVelocity) {
            startMotion()
        } else {
            stopMotion()
        }
        finishEditing()
        if displayLink == nil {
            finishValueChanges()
        }
    }

    public override func cancelTracking(with event: UIEvent?) {
        stopMotion()
        finishEditing()
        finishValueChanges()
    }

    private func finishEditing() {
        guard isEditing else { return }
        isEditing = false
        reduceTrack()

        sendActions(for: .editingDidEnd)
        onEditingChanged?(false)
    }

    private func finishValueChanges() {
        guard hasPendingValueChange else { return }
        hasPendingValueChange = false
        sendActions(for: .valueChanged)
    }

    private var layoutDirection: CGFloat {
        effectiveUserInterfaceLayoutDirection == .leftToRight ? 1 : -1
    }

    private func updateTracking(_ touch: UITouch) {
        guard isEditing else { return }
        let x = touch.location(in: self).x
        let elapsed = touch.timestamp - lastTouchTimestamp
        let width = trackView.bounds.width
        let translation = width > 0 ? (x - lastTouchX) * layoutDirection / width : 0
        if elapsed > 0 {
            let velocity = translation / CGFloat(elapsed)
            let weight = 1 - exp(-CGFloat(elapsed) / 0.025)
            dragVelocity += weight * (velocity - dragVelocity)
        }
        if translation != 0 {
            lastMovementTimestamp = touch.timestamp
        }
        lastTouchX = x
        lastTouchTimestamp = touch.timestamp
        motion.drag(by: translation, allowsOvershoot: behavior == .volume)
        updateProgress(motion.progress)
        updateStretch()
    }

    private func startMotion() {
        let link = CADisplayLink(target: DisplayLinkTarget(control: self), selector: #selector(DisplayLinkTarget.tick(_:)))
        displayLink = link
        lastFrameTimestamp = 0
        link.add(to: .main, forMode: .common)
    }

    private func advanceMotion(_ link: CADisplayLink) {
        let elapsed = lastFrameTimestamp == 0 ? link.targetTimestamp - link.timestamp : link.timestamp - lastFrameTimestamp
        lastFrameTimestamp = link.timestamp
        let isMoving = motion.advance(by: elapsed)
        updateProgress(motion.progress)
        // A value callback may have interrupted this animation.
        guard displayLink === link else { return }
        updateStretch()
        if !isMoving {
            stopMotion()
            finishValueChanges()
        }
    }

    private func stopMotion() {
        displayLink?.invalidate()
        displayLink = nil
        motion.reset(to: normalizedProgress)
        trackView.transform = .identity
    }

    private func updateStretch() {
        let width = trackView.bounds.width
        guard behavior == .volume, width > 0 else {
            trackView.transform = .identity
            return
        }
        let stretch = motion.stretch(trackWidth: width)
        trackView.transform = CGAffineTransform(
            a: 1 + stretch.amount / width, b: 0, c: 0,
            d: 1 - min(abs(stretch.amount) / 12, 1) * 0.08,
            tx: stretch.edge * layoutDirection * stretch.amount / 2, ty: 0
        )
    }

    private func setValue(_ newValue: Float) {
        guard newValue.isFinite else { return }
        let clampedValue = max(valueRange.lowerBound, min(valueRange.upperBound, newValue))
        normalizedProgress = CGFloat(valueRange.convert(value: clampedValue, to: Self.internalValueRange))
        motion.reset(to: normalizedProgress)
        setNeedsLayout()
    }

    private func updateProgress(_ progress: CGFloat) {
        let newProgress = max(0, min(1, progress))
        guard newProgress != normalizedProgress else { return }
        normalizedProgress = newProgress
        setNeedsLayout()
        layoutIfNeeded()

        switch newProgress {
            case 0: feedbackGenerator?.generateMinimumValueFeedback()
            case 1: feedbackGenerator?.generateMaximumValueFeedback()
            default: break
        }

        hasPendingValueChange = true
        if isContinuous {
            sendActions(for: .valueChanged)
        }
    }

    private func setup() {
        isMultipleTouchEnabled = false
        backgroundColor = .clear

        trackView.isUserInteractionEnabled = false
        trackView.clipsToBounds = true
        trackView.backgroundColor = defaultTrackColor
        trackView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(trackView)

        addLayoutGuide(trackLayoutGuide)

        progressView.isUserInteractionEnabled = false
        progressView.clipsToBounds = true
        progressView.backgroundColor = defaultProgressColor
        progressView.translatesAutoresizingMaskIntoConstraints = false
        trackView.addSubview(progressView)

        heightConstraint = trackView.heightAnchor.constraint(equalToConstant: Self.defaultTrackHeight)
        progressConstraint = progressView.widthAnchor.constraint(equalToConstant: 0)

        NSLayoutConstraint.activate([
            heightConstraint,
            trackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            trackView.trailingAnchor.constraint(equalTo: trailingAnchor),

            trackLayoutGuide.topAnchor.constraint(equalTo: trackView.topAnchor),
            trackLayoutGuide.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            trackView.bottomAnchor.constraint(equalTo: trackLayoutGuide.bottomAnchor),
            trackView.trailingAnchor.constraint(equalTo: trackLayoutGuide.trailingAnchor),

            progressConstraint,
            progressView.topAnchor.constraint(equalTo: trackView.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            progressView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor)
        ])

        addTarget(self, action: #selector(broadcastValueChange), for: .valueChanged)
    }

    private func enlargeTrack() {
        heightConstraint.constant = Self.enlargedTrackHeight
        setNeedsLayout()

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 0,
            options: [.curveEaseIn, .beginFromCurrentState, .allowAnimatedContent, .allowUserInteraction]
        ) { [unowned self] in
            enlargedTrackColor.map { trackView.backgroundColor = $0 }
            enlargedProgressColor.map { progressView.backgroundColor = $0 }

            layoutIfNeeded()
        }
    }

    private func reduceTrack() {
        heightConstraint.constant = Self.defaultTrackHeight
        setNeedsLayout()

        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 1,
            initialSpringVelocity: 1,
            options: [.curveEaseOut, .beginFromCurrentState, .allowAnimatedContent, .allowUserInteraction]
        ) { [unowned self] in
            trackView.backgroundColor = defaultTrackColor
            progressView.backgroundColor = defaultProgressColor

            layoutIfNeeded()
        }
    }

    private func updateColors() {
        if !isEditing {
            trackView.backgroundColor = defaultTrackColor
            progressView.backgroundColor = defaultProgressColor
        } else {
            trackView.backgroundColor = enlargedTrackColor ?? defaultTrackColor
            progressView.backgroundColor = enlargedProgressColor ?? defaultProgressColor
        }
    }

    @objc private func broadcastValueChange() {
        valueSubject.send(value)
    }
}
