import AppKit
import SwiftUI

/// The volume slider: 0...1 of the Mac's output volume, with tick marks at each quarter.
/// The knob moves freely between the marks. `onCommit` runs when a drag or key press ends.
struct VolumeSlider: NSViewRepresentable {
    @Binding var value: Double
    var onCommit: () -> Void

    static let tickMarks = 5

    func makeNSView(context: Context) -> NSSlider {
        let slider = NSSlider(value: value, minValue: 0, maxValue: 1,
                              target: context.coordinator, action: #selector(Coordinator.changed(_:)))
        slider.numberOfTickMarks = Self.tickMarks
        slider.tickMarkPosition = .below
        slider.allowsTickMarkValuesOnly = false
        slider.isContinuous = true
        slider.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return slider
    }

    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.parent = self
        if slider.doubleValue != value { slider.doubleValue = value }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    @MainActor
    final class Coordinator: NSObject {
        var parent: VolumeSlider
        init(_ parent: VolumeSlider) { self.parent = parent }

        @objc func changed(_ slider: NSSlider) {
            parent.value = slider.doubleValue
            // A continuous slider reports every step of a drag; play the preview once, on release.
            switch NSApp.currentEvent?.type {
            case .leftMouseDown?, .leftMouseDragged?: break
            default: parent.onCommit()
            }
        }
    }
}
