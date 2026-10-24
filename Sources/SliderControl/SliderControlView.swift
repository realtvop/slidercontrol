//
// SliderControlView.swift
// SliderControl
//
// Created by Alexander Chekel on 21.04.2024.
// Copyright © 2024 Alexander Chekel. All rights reserved.
//

import SwiftUI

public struct SliderControlView<T: BinaryFloatingPoint>: UIViewRepresentable {
    public typealias UIViewType = SliderControl

    public class Coordinator<U: BinaryFloatingPoint>: NSObject {
        @Binding private var value: U
        private var lastValue: U

        init(value: Binding<U>) {
            _value = value
            lastValue = value.wrappedValue
        }

        func update(value: Binding<U>) -> Bool {
            let changed = value.wrappedValue != lastValue
            lastValue = value.wrappedValue
            _value = value
            return changed
        }

        func setup(with control: SliderControl) {
            control.addTarget(self, action: #selector(handleValueChange(control:)), for: .valueChanged)
        }

        @objc func handleValueChange(control: SliderControl) {
            lastValue = U(control.value)
            value = lastValue
        }
    }

    @Binding var value: T

    var behavior: SliderControl.Behavior
    var isContinuous: Bool
    var feedbackGenerator: (any SliderFeedbackGenerator)?
    var defaultTrackColor: UIColor
    var defaultProgressColor: UIColor
    var enlargedTrackColor: UIColor?
    var enlargedProgressColor: UIColor?
    var onEditingChanged: ((Bool) -> Void)?
    var valueRange: ClosedRange<T>

    /// Creates an Apple Music style progress or volume slider.
    /// - parameters:
    ///     - value: Selected slider value binding.
    ///     - valueRange: A range of valid slider values.
    ///     - behavior: Progress stops on release; volume coasts and bounces at its limits.
    ///     - onEditingChanged: A callback for when editing begins or ends.
    public init(
        value: Binding<T>,
        in valueRange: ClosedRange<T> = 0...1,
        behavior: SliderControl.Behavior = .progress,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self._value = value
        self.behavior = behavior
        self.isContinuous = true
        self.feedbackGenerator = ImpactSliderFeedbackGenerator()
        self.defaultTrackColor = .secondarySystemFill
        self.defaultProgressColor = .systemFill
        self.enlargedTrackColor = nil
        self.enlargedProgressColor = nil
        self.onEditingChanged = onEditingChanged
        self.valueRange = valueRange
    }

    public func makeUIView(context: Context) -> SliderControl {
        let coordinator = context.coordinator
        let control = SliderControl()
        control.behavior = behavior
        control.isContinuous = isContinuous
        control.feedbackGenerator = feedbackGenerator
        control.defaultTrackColor = defaultTrackColor
        control.defaultProgressColor = defaultProgressColor
        control.enlargedTrackColor = enlargedTrackColor
        control.enlargedProgressColor = enlargedProgressColor
        control.onEditingChanged = onEditingChanged
        control.valueRange = Float(valueRange.lowerBound)...Float(valueRange.upperBound)
        control.value = Float(value)
        control.setContentHuggingPriority(.defaultHigh, for: .vertical)
        coordinator.setup(with: control)
        return control
    }

    public func makeCoordinator() -> Coordinator<T> {
        Coordinator(value: $value)
    }

    public func updateUIView(_ uiView: SliderControl, context: Context) {
        let hasExternalValueChange = context.coordinator.update(value: $value)
        uiView.behavior = behavior
        uiView.valueRange = Float(valueRange.lowerBound)...Float(valueRange.upperBound)
        uiView.onEditingChanged = onEditingChanged
        let floatValue = Float(value)

        if floatValue != uiView.value && (hasExternalValueChange || !uiView.isAnimatingValue) {
            // When the UIView updates the binding, SwiftUI calls the
            // updateUIView(_:context:) method again, which may cause
            // a CPU usage spike, or, as in case of this view,
            // a drawing issue.
            uiView.value = floatValue
        }

        uiView.isContinuous = isContinuous
        uiView.feedbackGenerator = feedbackGenerator
        uiView.defaultTrackColor = defaultTrackColor
        uiView.defaultProgressColor = defaultProgressColor
        uiView.enlargedTrackColor = enlargedTrackColor
        uiView.enlargedProgressColor = enlargedProgressColor
    }
}

public extension SliderControlView {
    /// Selects the Apple Music interaction to reproduce.
    func behavior(_ behavior: SliderControl.Behavior) -> SliderControlView {
        var view = self
        view.behavior = behavior
        return view
    }

    /// Sets track colors.
    /// - parameters:
    ///     - defaultTrackColorName: A name of asset color for the track.
    ///     - enlargedTrackColorName: A name of asset color for the track in interaction state.
    @available(iOS, deprecated: 14, message: "Use .trackColor(_:enlargedTrackColor:) modifier instead.")
    func trackColor(
        named defaultTrackColorName: String,
        enlargedTrackColorNamed enlargedTrackColorName: String? = nil
    ) -> SliderControlView {
        var view = self
        if let defaultTrackColor = UIColor(named: defaultTrackColorName) {
            view.defaultTrackColor = defaultTrackColor
        }
        view.enlargedTrackColor = enlargedTrackColorName.flatMap(UIColor.init(named:))
        return view
    }

    /// Sets track colors.
    /// - parameters:
    ///     - defaultTrackColor: A color for the track.
    ///     - enlargedTrackColor: A color for the track in interaction state.
    @available(iOS 14, *)
    func trackColor(_ defaultTrackColor: Color, enlarged enlargedTrackColor: Color? = nil) -> SliderControlView {
        var view = self
        view.defaultTrackColor = UIColor(defaultTrackColor)
        view.enlargedTrackColor = enlargedTrackColor.map(UIColor.init)
        return view
    }

    /// Sets progress fill colors.
    /// - parameters:
    ///     - defaultProgressColorName: A name of asset color for the progress fill.
    ///     - enlargedProgressColorName: A name of asset color for the progress fill in interaction state.
    @available(iOS, deprecated: 14, message: "Use .progressColor(_:enlargedProgressColor:) modifier instead.")
    func progressColor(
        named defaultProgressColorName: String,
        enlargedProgressColorNamed enlargedProgressColorName: String? = nil
    ) -> SliderControlView {
        var view = self
        if let defaultProgressColor = UIColor(named: defaultProgressColorName) {
            view.defaultProgressColor = defaultProgressColor
        }
        view.enlargedProgressColor = enlargedProgressColorName.flatMap(UIColor.init(named:))
        return view
    }

    /// Sets progress fill colors.
    /// - parameters:
    ///     - defaultProgressColor: A color for the progress fill.
    ///     - enlargedProgressColor: A color for the progress fill in interaction state.
    @available(iOS 14, *)
    func progressColor(_ defaultProgressColor: Color, enlarged enlargedProgressColor: Color? = nil) -> SliderControlView {
        var view = self
        view.defaultProgressColor = UIColor(defaultProgressColor)
        view.enlargedProgressColor = enlargedProgressColor.map(UIColor.init)
        return view
    }

    /// Specifies whether slider should continuously update the value binding.
    /// If set to `true`, the slider will update the value binding as user drags across.
    /// If set to `false`, the binding updates when the interaction settles,
    /// including any volume inertia after the finger lifts.
    func continuouslyUpdatesValue(_ isContinuous: Bool) -> SliderControlView {
        var view = self
        view.isContinuous = isContinuous
        return view
    }

    /// Sets slider's feedback generator. Pass `nil` to disable haptic feedback.
    func feedbackGenerator(_ generator: (any SliderFeedbackGenerator)?) -> SliderControlView {
        var view = self
        view.feedbackGenerator = generator
        return view
    }
}
