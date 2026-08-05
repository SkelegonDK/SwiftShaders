import SwiftUI

// MARK: - Parameter

/// One tweakable argument of an effect.
public struct EffectParam: Identifiable {
    public let id = UUID()

    /// The Swift argument label. Empty means the argument is unlabelled,
    /// as in `threshold(_ value: Float)`.
    public let label: String

    /// Name shown next to the slider. Defaults to a prettified `label`.
    public let title: String

    public let range: ClosedRange<Double>
    public let value: Double

    /// Decimal places used both for the slider readout and generated code.
    public let decimals: Int

    /// Whole-number arguments (`octaves: Int`) render without a decimal point.
    public let isInteger: Bool

    public init(
        _ label: String,
        _ range: ClosedRange<Double>,
        _ value: Double,
        decimals: Int = 2,
        isInteger: Bool = false,
        title: String? = nil
    ) {
        self.label = label
        self.title = title ?? EffectParam.prettify(label)
        self.range = range
        self.value = value
        self.decimals = isInteger ? 0 : decimals
        self.isInteger = isInteger
    }

    private static func prettify(_ label: String) -> String {
        guard !label.isEmpty else { return "Value" }
        var out = ""
        for (i, ch) in label.enumerated() {
            if ch.isUppercase && i > 0 { out.append(" ") }
            out.append(i == 0 ? Character(ch.uppercased()) : ch)
        }
        return out
    }

    /// Renders a value the way it should appear in generated Swift.
    public func literal(_ v: Double) -> String {
        isInteger ? String(Int(v.rounded())) : String(format: "%.\(decimals)f", v)
    }
}

// MARK: - Values

/// Current slider values for an effect, addressed by index with a safe fallback.
public struct ParamValues {
    private var storage: [Double]

    public init(_ params: [EffectParam]) {
        storage = params.map(\.value)
    }

    public subscript(i: Int) -> Double {
        get { i < storage.count ? storage[i] : 0 }
        set { if i < storage.count { storage[i] = newValue } }
    }

    public var all: [Double] { storage }
}

// MARK: - Effect

/// A single shader effect the gallery can preview, tweak and emit code for.
public struct Effect: Identifiable {
    /// The view-extension function name — also the identifier used in code output.
    public let id: String
    public let name: String
    public let category: EffectCategory
    public let blurb: String

    /// Whether the call takes a leading `time:` argument driven by `TimelineView`.
    public let animated: Bool

    public let params: [EffectParam]

    /// Applies the effect to a sample view at the given parameter values and time.
    public let build: (AnyView, ParamValues, Double) -> AnyView

    public init(
        _ id: String,
        _ name: String,
        _ category: EffectCategory,
        _ blurb: String,
        animated: Bool = false,
        params: [EffectParam] = [],
        build: @escaping (AnyView, ParamValues, Double) -> AnyView
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.blurb = blurb
        self.animated = animated
        self.params = params
        self.build = build
    }

    /// The Swift source for this effect at the current values, as shown in the
    /// code panel and placed on the pasteboard.
    public func code(_ values: ParamValues) -> String {
        var args: [String] = []
        if animated { args.append("time: time") }
        for (i, p) in params.enumerated() {
            let literal = p.literal(values[i])
            args.append(p.label.isEmpty ? literal : "\(p.label): \(literal)")
        }

        let call = args.isEmpty ? ".\(id)()" : ".\(id)(\(args.joined(separator: ", ")))"

        guard animated else {
            return """
            import SwiftShaders

            myView
                \(call)
            """
        }

        // Animated effects need a clock. Show the TimelineView that drives them.
        return """
        import SwiftShaders

        struct AnimatedExample: View {
            @State private var start = Date.now

            var body: some View {
                TimelineView(.animation) { timeline in
                    let time = start.distance(to: timeline.date)

                    myView
                        \(call)
                }
            }
        }
        """
    }
}

// MARK: - Category

public enum EffectCategory: String, CaseIterable, Identifiable, Sendable {
    case distortion = "Distortion"
    case color = "Color"
    case stylize = "Stylize"
    case retro = "Retro"
    case light = "Light & Glow"
    case elements = "Fire & Water"
    case generative = "Generative"
    case particles = "Particles"
    case transition = "Transitions"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .distortion: "water.waves"
        case .color: "paintpalette"
        case .stylize: "scribble.variable"
        case .retro: "tv"
        case .light: "sparkles"
        case .elements: "flame"
        case .generative: "cube.transparent"
        case .particles: "snowflake"
        case .transition: "wand.and.stars"
        }
    }
}
