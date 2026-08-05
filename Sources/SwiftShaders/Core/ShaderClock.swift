import SwiftUI

// MARK: - ShaderClock

/// The library's single time source for animated shader effects.
///
/// ## Why this type exists
///
/// Every animated shader takes its time as a `Shader.Argument.float`, and
/// `Shader.Argument.float` is **32-bit** (Phase 0.2). That makes the *magnitude*
/// of the number load-bearing, not just its meaning:
///
/// - `Date.timeIntervalSinceReferenceDate` is ≈7.8×10⁸ today. The ulp of a
///   `Float` at that magnitude is **64.0 seconds**, so
///   `Float(7.8e8) == Float(7.8e8 + 1.0/60.0)`. A uniform fed from an absolute
///   reference date does not change between frames — it steps once a minute.
///   Animation driven from it is *frozen*, not slow.
/// - Elapsed seconds since the effect appeared are small. At an hour of uptime
///   the ulp is 0.0004 s; at a month it is 0.25 s — and a view that has been on
///   screen for a month is not a case this library needs to animate smoothly.
///   For every realistic view lifetime the 60 Hz frame delta is many ulps wide.
///
/// So: **`TimelineView` stays the driver; `ShaderClock` converts its `date` into
/// elapsed seconds measured from a start instant.** No shader argument is ever
/// derived from an absolute date again.
///
/// ## Use
///
/// Declare it as a stored property of a `View` or `ViewModifier` — it is a
/// `DynamicProperty`, so SwiftUI installs its storage the same way it does for
/// `@State`:
///
/// ```swift
/// struct MyModifier: ViewModifier {
///     private var clock = ShaderClock()
///
///     func body(content: Content) -> some View {
///         TimelineView(.animation) { timeline in
///             let time = clock.elapsed(to: timeline.date)
///             content.shaderEffect(MyBindings.effect, .float(time))
///         }
///     }
/// }
/// ```
///
/// ## Injection
///
/// Both ends of the subtraction are injectable, because neither is knowable from
/// a test otherwise. The start defaults to the moment the view's storage is
/// created — two `ImageRenderer` passes are two *different* view instances, so
/// both would otherwise render at elapsed ≈ 0. And `timeline.date` is whatever
/// wall clock says at render time. Pinning both makes a headless render exactly
/// reproducible:
///
/// ```swift
/// view.environment(\.shaderClockStart, epoch)
///     .environment(\.shaderClockNow, epoch.addingTimeInterval(0.5))   // elapsed == 0.5
/// ```
///
/// An override wins over the value it replaces whenever it is present.
/// Production sets neither.
struct ShaderClock: DynamicProperty {

    /// The instant this clock's view came into being. Per-view, so elapsed time
    /// stays small no matter how long the process has been running.
    @State private var viewStart: Date

    /// A pinned start instant, supplied by tests. `nil` in production.
    @Environment(\.shaderClockStart) private var injectedStart: Date?

    /// A pinned "now", supplied by tests. `nil` in production, where the
    /// driving `TimelineView` supplies it.
    @Environment(\.shaderClockNow) private var injectedNow: Date?

    /// Creates a clock that starts now, or at an explicit instant.
    init(start: Date = .now) {
        _viewStart = State(initialValue: start)
    }

    /// The instant elapsed time is measured from.
    var start: Date {
        injectedStart ?? viewStart
    }

    /// Seconds elapsed from ``start`` to `date`, optionally scaled.
    ///
    /// - Parameters:
    ///   - date: The current instant, normally `timeline.date` from a
    ///     `TimelineView`.
    ///   - speed: Playback multiplier. `1.0` is real time.
    /// - Returns: Elapsed seconds — a small number, safe to narrow to `Float`.
    func elapsed(to date: Date, speed: Double = 1.0) -> Double {
        start.distance(to: injectedNow ?? date) * speed
    }
}

// MARK: - Environment

private struct ShaderClockStartKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

private struct ShaderClockNowKey: EnvironmentKey {
    static let defaultValue: Date? = nil
}

extension EnvironmentValues {
    /// Pins every ``ShaderClock`` below this view to a known start instant.
    ///
    /// Test seam. Production never sets it, so clocks measure from their own
    /// view's appearance.
    var shaderClockStart: Date? {
        get { self[ShaderClockStartKey.self] }
        set { self[ShaderClockStartKey.self] = newValue }
    }

    /// Pins the current instant every ``ShaderClock`` below this view measures
    /// *to*, replacing the date its `TimelineView` supplies.
    ///
    /// Test seam. Production never sets it.
    var shaderClockNow: Date? {
        get { self[ShaderClockNowKey.self] }
        set { self[ShaderClockNowKey.self] = newValue }
    }
}
