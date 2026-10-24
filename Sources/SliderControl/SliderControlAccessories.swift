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
/// Icons move with the corresponding track end during boundary stretch and spring return.
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
        VolumeAccessoryRepresentable(slider: slider.behavior(.volume), minimum: minimum, maximum: maximum)
            .frame(height: 24)
    }
}

/// Keeping all three views in one UIKit hierarchy avoids a frame of SwiftUI state propagation
/// between the track's spring and the icons. Hosted images retain the custom SwiftUI Image API.
private struct VolumeAccessoryRepresentable<Value: BinaryFloatingPoint>: UIViewControllerRepresentable {
    let slider: SliderControlView<Value>
    let minimum: Image
    let maximum: Image

    final class Coordinator {
        let setup: (SliderControl) -> Void
        let update: (Binding<Value>) -> Bool

        init(slider: SliderControlView<Value>) {
            // Retain and reuse the base coordinator's binding and target-action handling.
            let coordinator = slider.makeCoordinator()
            setup = coordinator.setup
            update = coordinator.update
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(slider: slider)
    }

    func makeUIViewController(context: Context) -> VolumeAccessoryController {
        let controller = VolumeAccessoryController(minimum: minimum, maximum: maximum,
            layoutDirection: context.environment.layoutDirection, colorScheme: context.environment.colorScheme)
        controller.loadViewIfNeeded()
        controller.volume.semanticContentAttribute = context.environment.layoutDirection == .rightToLeft
            ? .forceRightToLeft : .forceLeftToRight
        slider.configure(controller.volume.slider)
        context.coordinator.setup(controller.volume.slider)
        controller.volume.slider.isEnabled = context.environment.isEnabled
        return controller
    }

    func updateUIViewController(_ controller: VolumeAccessoryController, context: Context) {
        controller.volume.semanticContentAttribute = context.environment.layoutDirection == .rightToLeft
            ? .forceRightToLeft : .forceLeftToRight
        controller.updateImages(minimum: minimum, maximum: maximum,
            layoutDirection: context.environment.layoutDirection, colorScheme: context.environment.colorScheme)
        let changed = context.coordinator.update(slider.$value)
        slider.update(controller.volume.slider, hasExternalValueChange: changed)
        controller.volume.slider.isEnabled = context.environment.isEnabled
    }
}

private final class VolumeAccessoryController: UIViewController {
    let volume = VolumeSliderControl()
    private var minimum: Image
    private var maximum: Image
    private var layoutDirection: LayoutDirection
    private var colorScheme: ColorScheme
    private let minimumHost: UIHostingController<AnyView>
    private let maximumHost: UIHostingController<AnyView>

    init(minimum: Image, maximum: Image, layoutDirection: LayoutDirection, colorScheme: ColorScheme) {
        self.minimum = minimum
        self.maximum = maximum
        self.layoutDirection = layoutDirection
        self.colorScheme = colorScheme
        self.minimumHost = UIHostingController(rootView: Self.icon(minimum, layoutDirection: layoutDirection, colorScheme: colorScheme))
        self.maximumHost = UIHostingController(rootView: Self.icon(maximum, layoutDirection: layoutDirection, colorScheme: colorScheme))
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("Use the image initializer")
    }

    override func loadView() {
        view = volume
        volume.minimumImage = nil
        volume.maximumImage = nil
        embed(minimumHost, in: volume.minimumImageView)
        embed(maximumHost, in: volume.maximumImageView)
    }

    func updateImages(minimum: Image, maximum: Image, layoutDirection: LayoutDirection, colorScheme: ColorScheme) {
        let appearanceChanged = self.layoutDirection != layoutDirection || self.colorScheme != colorScheme
        self.layoutDirection = layoutDirection
        self.colorScheme = colorScheme
        if self.minimum != minimum || appearanceChanged {
            self.minimum = minimum
            minimumHost.rootView = Self.icon(minimum, layoutDirection: layoutDirection, colorScheme: colorScheme)
        }
        if self.maximum != maximum || appearanceChanged {
            self.maximum = maximum
            maximumHost.rootView = Self.icon(maximum, layoutDirection: layoutDirection, colorScheme: colorScheme)
        }
    }

    private func embed(_ host: UIHostingController<AnyView>, in container: UIView) {
        if #available(iOS 16.4, *) {
            // These embedded icons follow the track's bounds, not the screen's safe area.
            host.safeAreaRegions = []
        }
        addChild(host)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: container.topAnchor),
            host.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            host.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        host.didMove(toParent: self)
    }

    private static func icon(_ image: Image, layoutDirection: LayoutDirection, colorScheme: ColorScheme) -> AnyView {
        AnyView(image.font(.system(size: 14)).foregroundColor(.secondary)
            .frame(width: 20, height: 20).accessibility(hidden: true)
            .environment(\.layoutDirection, layoutDirection).environment(\.colorScheme, colorScheme))
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
