import SwiftUI

/// A progress slider with text below each end and optional, independently sized center content.
public struct ProgressSliderControlView<Value: BinaryFloatingPoint, Center: View>: View {
    private let slider: SliderControlView<Value>
    private let leadingText: String
    private let trailingText: String
    private let center: Center
    @State private var isActive = false
    @Environment(\.layoutDirection) private var layoutDirection

    init(slider: SliderControlView<Value>, leading: String, trailing: String, center: Center) {
        self.slider = slider
        self.leadingText = leading
        self.trailingText = trailing
        self.center = center
    }

    public var body: some View {
        VStack(spacing: 0) {
            configuredSlider.frame(height: 24)
            HStack(spacing: 8) {
                Text(leadingText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(isActive ? 1.1 : 1, anchor: layoutDirection == .leftToRight ? .leading : .trailing)

                // Scale only the labels. Center content keeps its own layout and interaction.
                HStack(spacing: 0) { center }.layoutPriority(1)

                Text(trailingText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .scaleEffect(isActive ? 1.1 : 1, anchor: layoutDirection == .leftToRight ? .trailing : .leading)
            }
            .frame(minHeight: 20)
        }
    }

    private var configuredSlider: SliderControlView<Value> {
        var control = slider
        let onEditingChanged = control.onEditingChanged
        control.behavior = .progress
        control.onEditingChanged = { active in
            withAnimation(.easeOut(duration: active ? 0.2 : 0.3)) {
                isActive = active
            }
            onEditingChanged?(active)
        }
        return control
    }
}

/// A volume slider flanked by minimum and maximum icons.
public struct VolumeSliderControlView<Value: BinaryFloatingPoint>: View {
    private let slider: SliderControlView<Value>
    private let minimum: Image
    private let maximum: Image

    init(slider: SliderControlView<Value>, minimum: Image, maximum: Image) {
        self.slider = slider
        self.minimum = minimum
        self.maximum = maximum
    }

    public var body: some View {
        HStack(spacing: 12) {
            minimum
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .accessibility(hidden: true)
            slider.behavior(.volume).frame(height: 24)
            maximum
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20, height: 20)
                .accessibility(hidden: true)
        }
    }
}

public extension SliderControlView {
    /// Adds text below a progress slider. Supply already formatted text, such as elapsed and remaining time.
    /// Apply slider color and feedback modifiers before this modifier.
    func progressLabels(leading: String, trailing: String) -> ProgressSliderControlView<T, EmptyView> {
        ProgressSliderControlView(slider: self, leading: leading, trailing: trailing, center: EmptyView())
    }

    /// Adds text and arbitrary center content below a progress slider.
    /// Activation scales the text labels only; the center view is not scaled.
    func progressLabels<Center: View>(
        leading: String,
        trailing: String,
        @ViewBuilder center: () -> Center
    ) -> ProgressSliderControlView<T, Center> {
        ProgressSliderControlView(slider: self, leading: leading, trailing: trailing, center: center())
    }

    /// Adds volume icons and selects volume inertia and boundary feedback.
    /// Apply slider color and feedback modifiers before this modifier.
    func volumeIcons(
        minimum: Image = Image(systemName: "speaker.fill"),
        maximum: Image = Image(systemName: "speaker.wave.3.fill")
    ) -> VolumeSliderControlView<T> {
        VolumeSliderControlView(slider: self, minimum: minimum, maximum: maximum)
    }
}
