import SwiftUI
import SwiftShaders

/// Every effect the gallery exposes.
///
/// Each entry pairs the real `View` extension call with the metadata needed to
/// drive sliders and regenerate the equivalent Swift source. Adding an effect
/// is one entry: the sidebar, preview and code panel all read from this list.
// swiftlint:disable:next type_body_length — a declarative table of 91 entries; splitting it hides the inventory
public enum EffectCatalog {

    public static let all: [Effect] = distortion + color + stylize + retro + light + elements + generative + particles + transitions

    /// The effect with this id, or `nil`. Ids are the `View` extension names, so
    /// this is also how a caller goes from generated code back to the entry.
    public static func effect(id: Effect.ID) -> Effect? {
        all.first { $0.id == id }
    }

    public static func grouped() -> [(EffectCategory, [Effect])] {
        EffectCategory.allCases.compactMap { cat in
            let items = all.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }

    // MARK: - Distortion

    static let distortion: [Effect] = [
        Effect("rippleEffect", "Ripple", .distortion, "Concentric water ripples from a point.",
               animated: true,
               params: [
                .init("amplitude", 0...0.1, 0.02, decimals: 3),
                .init("frequency", 1...40, 15),
                .init("decay", 0...20, 8),
               ]) { v, p, t in
            AnyView(v.rippleEffect(time: t, amplitude: p[0], frequency: p[1], decay: p[2]))
        },

        Effect("waveEffect", "Wave", .distortion, "Sine wave distortion across the view.",
               animated: true,
               params: [
                .init("amplitude", 0...0.1, 0.02, decimals: 3),
                .init("frequency", 1...30, 10),
                .init("direction", 0...6.28, 0),
               ]) { v, p, t in
            AnyView(v.waveEffect(time: t, amplitude: p[0], frequency: p[1], direction: p[2]))
        },

        Effect("twirl", "Twirl", .distortion, "Rotates pixels around the centre.",
               params: [.init("angle", -360...360, 180, decimals: 0)]) { v, p, _ in
            AnyView(v.twirl(angle: Float(p[0])))
        },

        Effect("bulge", "Bulge", .distortion, "Pushes pixels outward from the centre.",
               params: [
                .init("strength", 0...5, 2),
                .init("radius", 0.05...1, 0.5),
               ]) { v, p, _ in
            AnyView(v.bulge(strength: Float(p[0]), radius: Float(p[1])))
        },

        Effect("pinch", "Pinch", .distortion, "Pulls pixels toward the centre.",
               params: [
                .init("strength", 0...5, 2),
                .init("radius", 0.05...1, 0.5),
               ]) { v, p, _ in
            AnyView(v.pinch(strength: Float(p[0]), radius: Float(p[1])))
        },

        Effect("vortex", "Vortex", .distortion, "Spiral pull toward the centre.",
               params: [
                .init("angle", 0...720, 360, decimals: 0),
                .init("pullStrength", 0...5, 2),
               ]) { v, p, _ in
            AnyView(v.vortex(angle: Float(p[0]), pullStrength: Float(p[1])))
        },

        Effect("barrelDistortion", "Barrel", .distortion, "Lens barrel / pincushion warp.",
               params: [
                .init("strength", -1...1, 0.3),
                .init("zoom", 0.5...2, 1),
               ]) { v, p, _ in
            AnyView(v.barrelDistortion(strength: p[0], zoom: p[1]))
        },

        Effect("kaleidoscope", "Kaleidoscope", .distortion, "Mirrored radial segments.",
               params: [
                .init("segments", 2...24, 6, decimals: 0),
                .init("rotation", 0...6.28, 0),
               ]) { v, p, _ in
            AnyView(v.kaleidoscope(segments: Float(p[0]), rotation: Float(p[1])))
        },

        Effect("zigzag", "Zigzag", .distortion, "Sawtooth displacement bands.",
               animated: true,
               params: [
                .init("amplitude", 0...1, 0.3),
                .init("frequency", 1...40, 10),
                .init("angle", 0...6.28, 0),
               ]) { v, p, t in
            AnyView(v.zigzag(time: t, amplitude: p[0], frequency: p[1], angle: p[2]))
        },

        Effect("flagWave", "Flag Wave", .distortion, "Cloth ripple travelling across the view.",
               animated: true,
               params: [
                .init("amplitude", 0...2, 0.5),
                .init("frequency", 0.5...10, 3),
                .init("propagation", 0...15, 5),
               ]) { v, p, t in
            AnyView(v.flagWave(time: t, amplitude: p[0], frequency: p[1], propagation: p[2]))
        },

        Effect("heatDistortion", "Heat Haze", .distortion, "Rising hot-air shimmer.",
               animated: true,
               params: [
                .init("intensity", 0...3, 1),
                .init("riseFactor", 0...2, 0.5),
                .init("turbulence", 0...8, 3),
               ]) { v, p, t in
            AnyView(v.heatDistortion(time: t, intensity: p[0], riseFactor: p[1], turbulence: p[2]))
        },

        Effect("earthquakeDisplacement", "Earthquake", .distortion, "Decaying directional shake.",
               animated: true,
               params: [
                .init("magnitude", 0...3, 1),
                .init("frequency", 0...5, 1),
                .init("decay", 0...5, 0.5),
               ]) { v, p, t in
            AnyView(v.earthquakeDisplacement(time: t, magnitude: p[0], frequency: p[1], decay: p[2]))
        },
    ]

    // MARK: - Colour

    static let color: [Effect] = [
        Effect("sepia", "Sepia", .color, "Classic warm monochrome.",
               params: [.init("intensity", 0...1, 1)]) { v, p, _ in
            AnyView(v.sepia(intensity: Float(p[0])))
        },

        Effect("colorGrading", "Colour Grading", .color, "Full grading controls.",
               params: [
                .init("brightness", -1...1, 0),
                .init("contrast", 0...3, 1),
                .init("saturation", 0...3, 1),
                .init("hueShift", 0...6.28, 0),
                .init("temperature", -1...1, 0),
                .init("tint", -1...1, 0),
               ]) { v, p, _ in
            AnyView(v.colorGrading(brightness: p[0], contrast: p[1], saturation: p[2],
                                   hueShift: p[3], temperature: p[4], tint: p[5]))
        },

        Effect("vibrance", "Vibrance", .color, "Saturates muted tones only.",
               params: [.init("", -1...1, 0.3, title: "Amount")]) { v, p, _ in
            AnyView(v.vibrance(p[0]))
        },

        Effect("invert", "Invert", .color, "Inverts colour channels.",
               params: [.init("amount", 0...1, 1)]) { v, p, _ in
            AnyView(v.invert(amount: Float(p[0])))
        },

        Effect("solarize", "Solarize", .color, "Inverts only above a threshold.",
               params: [.init("threshold", 0...1, 0.5)]) { v, p, _ in
            AnyView(v.solarize(threshold: Float(p[0])))
        },

        Effect("posterize", "Posterize", .color, "Quantises to N colour levels.",
               params: [.init("levels", 2...16, 4, isInteger: true)]) { v, p, _ in
            AnyView(v.posterize(levels: Float(p[0])))
        },

        Effect("threshold", "Threshold", .color, "Hard black/white cutoff.",
               params: [.init("", 0...1, 0.5, title: "Threshold")]) { v, p, _ in
            AnyView(v.threshold(Float(p[0])))
        },

        Effect("thresholdSmooth", "Soft Threshold", .color, "Threshold with a soft edge.",
               params: [
                .init("", 0...1, 0.5, title: "Threshold"),
                .init("softness", 0...0.5, 0.1),
               ]) { v, p, _ in
            AnyView(v.thresholdSmooth(Float(p[0]), softness: Float(p[1])))
        },

        Effect("levels", "Levels", .color, "Input/output level remapping.",
               params: [
                .init("inputBlack", 0...1, 0),
                .init("inputWhite", 0...1, 1),
                .init("gamma", 0.1...3, 1),
               ]) { v, p, _ in
            AnyView(v.levels(inputBlack: p[0], inputWhite: p[1], gamma: p[2]))
        },

        Effect("splitToning", "Split Toning", .color, "Separate shadow and highlight tints.",
               params: [
                .init("shadowHue", 0...1, 0.1),
                .init("shadowSaturation", 0...1, 0.2),
                .init("highlightHue", 0...1, 0.6),
                .init("highlightSaturation", 0...1, 0.2),
                .init("balance", -1...1, 0),
               ]) { v, p, _ in
            AnyView(v.splitToning(shadowHue: p[0], shadowSaturation: p[1],
                                  highlightHue: p[2], highlightSaturation: p[3], balance: p[4]))
        },

        Effect("chromaticAberration", "Chromatic Aberration", .color, "Splits the RGB channels.",
               params: [
                .init("intensity", 0...0.1, 0.01, decimals: 3),
                .init("angle", 0...6.28, 0),
               ]) { v, p, _ in
            AnyView(v.chromaticAberration(intensity: p[0], angle: p[1]))
        },

        Effect("rgbSplit", "RGB Split", .color, "Offsets each channel independently.",
               params: [
                .init("splitX", -0.5...0.5, 0.1),
                .init("splitY", -0.5...0.5, 0.1),
               ]) { v, p, _ in
            AnyView(v.rgbSplit(splitX: p[0], splitY: p[1]))
        },

        Effect("xray", "X-Ray", .color, "Inverted luminance with a cool cast.",
               params: [.init("intensity", 0...1, 1)]) { v, p, _ in
            AnyView(v.xray(intensity: Float(p[0])))
        },
    ]

    // MARK: - Stylize

    static let stylize: [Effect] = [
        Effect("pixelateEffect", "Pixelate", .stylize, "Square pixel blocks.",
               params: [.init("pixelSize", 1...60, 10, decimals: 1)]) { v, p, _ in
            AnyView(v.pixelateEffect(pixelSize: p[0]))
        },

        Effect("hexPixelate", "Hex Pixelate", .stylize, "Hexagonal pixel grid.",
               params: [.init("hexSize", 0.01...0.2, 0.05, decimals: 3)]) { v, p, _ in
            AnyView(v.hexPixelate(hexSize: p[0]))
        },

        Effect("dotMatrix", "Dot Matrix", .stylize, "Dot-screen print look.",
               params: [
                .init("dotSize", 0.2...3, 1),
                .init("spacing", 0.005...0.1, 0.02, decimals: 3),
               ]) { v, p, _ in
            AnyView(v.dotMatrix(dotSize: p[0], spacing: p[1]))
        },

        Effect("halftone", "Halftone", .stylize, "Comic-book dot pattern.",
               params: [
                .init("dotSize", 2...30, 8, decimals: 1),
                .init("angle", 0...90, 45, decimals: 0),
               ]) { v, p, _ in
            AnyView(v.halftone(dotSize: Float(p[0]), angle: Float(p[1])))
        },

        Effect("mosaicSquare", "Mosaic", .stylize, "Grouted square tiles.",
               params: [
                .init("tileSize", 5...80, 20, decimals: 1),
                .init("groutWidth", 0...10, 2, decimals: 1),
               ]) { v, p, _ in
            AnyView(v.mosaicSquare(tileSize: Float(p[0]), groutWidth: Float(p[1])))
        },

        Effect("mosaicHexagon", "Hex Mosaic", .stylize, "Hexagonal tiling.",
               params: [
                .init("tileSize", 5...80, 20, decimals: 1),
                .init("groutWidth", 0...10, 2, decimals: 1),
               ]) { v, p, _ in
            AnyView(v.mosaicHexagon(tileSize: Float(p[0]), groutWidth: Float(p[1])))
        },

        Effect("stainedGlass", "Stained Glass", .stylize, "Leaded glass cells.",
               params: [.init("cellSize", 5...80, 30, decimals: 1)]) { v, p, _ in
            AnyView(v.stainedGlass(cellSize: Float(p[0])))
        },

        Effect("emboss", "Emboss", .stylize, "Directional relief lighting.",
               params: [
                .init("strength", 0...4, 1),
                .init("lightAngle", 0...360, 45, decimals: 0),
               ]) { v, p, _ in
            AnyView(v.emboss(strength: Float(p[0]), lightAngle: Float(p[1])))
        },

        Effect("sketchPencil", "Pencil Sketch", .stylize, "Graphite line drawing.",
               params: [.init("intensity", 0...3, 1)]) { v, p, _ in
            AnyView(v.sketchPencil(intensity: Float(p[0])))
        },

        Effect("sketchCrossHatch", "Cross Hatch", .stylize, "Hatched shading lines.",
               params: [
                .init("spacing", 1...20, 5, decimals: 1),
                .init("lineWidth", 0.2...5, 1),
               ]) { v, p, _ in
            AnyView(v.sketchCrossHatch(spacing: Float(p[0]), lineWidth: Float(p[1])))
        },

        Effect("sketchInk", "Ink", .stylize, "High-contrast ink outlines.",
               params: [.init("threshold", 0...1, 0.1)]) { v, p, _ in
            AnyView(v.sketchInk(threshold: Float(p[0])))
        },

        Effect("sharpen", "Sharpen", .stylize, "Edge enhancement.",
               params: [.init("amount", 0...4, 1)]) { v, p, _ in
            AnyView(v.sharpen(amount: Float(p[0])))
        },

        Effect("unsharpMask", "Unsharp Mask", .stylize, "Photographic sharpening.",
               params: [
                .init("radius", 0.5...8, 2),
                .init("amount", 0...3, 1),
                .init("threshold", 0...1, 0),
               ]) { v, p, _ in
            AnyView(v.unsharpMask(radius: Float(p[0]), amount: Float(p[1]), threshold: Float(p[2])))
        },
    ]

    // MARK: - Retro

    static let retro: [Effect] = [
        Effect("scanlines", "Scanlines", .retro, "CRT scanline overlay.",
               params: [
                .init("count", 20...600, 240, decimals: 0),
                .init("intensity", 0...1, 0.3),
               ]) { v, p, _ in
            AnyView(v.scanlines(count: Float(p[0]), intensity: Float(p[1])))
        },

        Effect("scanlinesLCD", "LCD Grid", .retro, "RGB sub-pixel grid.",
               params: [.init("pixelSize", 1...12, 3, decimals: 1)]) { v, p, _ in
            AnyView(v.scanlinesLCD(pixelSize: Float(p[0])))
        },

        Effect("glitchEffect", "Glitch", .retro, "Blocky digital tearing.",
               animated: true,
               params: [
                .init("intensity", 0...1, 0.5),
                .init("blockSize", 0.01...0.4, 0.1),
               ]) { v, p, t in
            AnyView(v.glitchEffect(time: t, intensity: p[0], blockSize: p[1]))
        },

        Effect("vhsGlitch", "VHS", .retro, "Tape wobble and noise.",
               animated: true,
               params: [
                .init("intensity", 0...1, 0.5),
                .init("noiseAmount", 0...1, 0.1),
               ]) { v, p, t in
            AnyView(v.vhsGlitch(time: t, intensity: p[0], noiseAmount: p[1]))
        },

        Effect("digitalCorruption", "Data Corruption", .retro, "Shifted corrupt blocks.",
               animated: true,
               params: [
                .init("intensity", 0...1, 0.3),
                .init("blockWidth", 0.01...0.3, 0.05, decimals: 3),
                .init("blockHeight", 0.01...0.3, 0.05, decimals: 3),
               ]) { v, p, t in
            AnyView(v.digitalCorruption(time: t, intensity: p[0], blockWidth: p[1], blockHeight: p[2]))
        },

        Effect("filmGrain", "Film Grain", .retro, "Animated photographic grain.",
               animated: true,
               params: [
                .init("intensity", 0...0.6, 0.15),
                .init("size", 50...1500, 500, decimals: 0),
               ]) { v, p, t in
            AnyView(v.filmGrain(time: t, intensity: p[0], size: p[1]))
        },

        Effect("vintagePhoto", "Vintage Photo", .retro, "Faded warm print.",
               params: [
                .init("fadeAmount", 0...1, 0.2),
                .init("warmth", 0...1, 0.5),
                .init("contrast", 0.5...2, 1.1),
               ]) { v, p, _ in
            AnyView(v.vintagePhoto(fadeAmount: Float(p[0]), warmth: Float(p[1]), contrast: Float(p[2])))
        },

        Effect("polaroid", "Polaroid", .retro, "Instant-film colour response.",
               params: [
                .init("exposure", 0.5...2, 1),
                .init("saturation", 0...2, 0.8),
               ]) { v, p, _ in
            AnyView(v.polaroid(exposure: Float(p[0]), saturation: Float(p[1])))
        },

        Effect("crossProcess", "Cross Process", .retro, "Shifted film development.",
               params: [.init("intensity", 0...1, 1)]) { v, p, _ in
            AnyView(v.crossProcess(intensity: Float(p[0])))
        },

        Effect("negativeFilm", "Negative", .retro, "Film negative with orange mask.",
               params: [.init("orangeMask", 0...1, 0.3)]) { v, p, _ in
            AnyView(v.negativeFilm(orangeMask: Float(p[0])))
        },
    ]

    // MARK: - Light & Glow

    static let light: [Effect] = [
        Effect("hologramEffect", "Hologram", .light, "Scanning holographic sheen.",
               animated: true,
               params: [
                .init("scanlineIntensity", 0...1, 0.3),
                .init("flickerSpeed", 0...8, 2),
                .init("colorShift", 0...1, 0.1),
               ]) { v, p, t in
            AnyView(v.hologramEffect(time: t, scanlineIntensity: p[0], flickerSpeed: p[1], colorShift: p[2]))
        },

        Effect("wireframeHologram", "Wireframe", .light, "Projected wireframe grid.",
               animated: true,
               params: [
                .init("gridSize", 4...60, 20, decimals: 0),
                .init("lineWidth", 0.005...0.1, 0.02, decimals: 3),
               ]) { v, p, t in
            AnyView(v.wireframeHologram(time: t, gridSize: p[0], lineWidth: p[1]))
        },

        Effect("neonOutline", "Neon Outline", .light, "Glowing edge outline.",
               params: [
                .init("width", 1...20, 5, decimals: 1),
                .init("intensity", 0...4, 1.5),
               ]) { v, p, _ in
            AnyView(v.neonOutline(color: .cyan, width: Float(p[0]), intensity: Float(p[1])))
        },

        Effect("neonTint", "Neon Tint", .light, "Coloured neon wash.",
               params: [.init("intensity", 0...2, 0.7)]) { v, p, _ in
            AnyView(v.neonTint(color: .cyan, intensity: Float(p[0])))
        },

        Effect("softGlow", "Soft Glow", .light, "Bloom on bright areas.",
               params: [
                .init("intensity", 0...3, 1),
                .init("threshold", 0...1, 0.5),
               ]) { v, p, _ in
            AnyView(v.softGlow(intensity: p[0], threshold: p[1]))
        },

        Effect("vignette", "Vignette", .light, "Darkened edges.",
               params: [
                .init("radius", 0...1, 0.5),
                .init("softness", 0...1, 0.5),
                .init("intensity", 0...1, 0.5),
               ]) { v, p, _ in
            AnyView(v.vignette(radius: Float(p[0]), softness: Float(p[1]), intensity: Float(p[2])))
        },

        Effect("motionBlur", "Motion Blur", .light, "Directional smear.",
               params: [
                .init("angle", 0...6.28, 0),
                .init("strength", 0...2, 0.5),
               ]) { v, p, _ in
            AnyView(v.motionBlur(angle: p[0], strength: p[1]))
        },

        Effect("tiltShift", "Tilt Shift", .light, "Miniature-model focus band.",
               params: [
                .init("focusY", 0...1, 0.5),
                .init("focusWidth", 0.05...1, 0.2),
                .init("blurStrength", 0...3, 1),
               ]) { v, p, _ in
            AnyView(v.tiltShift(focusY: p[0], focusWidth: p[1], blurStrength: p[2]))
        },

        Effect("lightning", "Lightning", .light, "Branching electric arcs.",
               animated: true,
               params: [
                .init("intensity", 0...3, 1),
                .init("branchiness", 0...3, 1),
                .init("glowRadius", 0...3, 1),
               ]) { v, p, t in
            AnyView(v.lightning(time: t, intensity: p[0], branchiness: p[1], glowRadius: p[2]))
        },

        Effect("electricField", "Electric Field", .light, "Flowing field lines.",
               animated: true,
               params: [
                .init("lineCount", 2...30, 8, decimals: 0),
                .init("flowSpeed", 0...6, 2),
               ]) { v, p, t in
            AnyView(v.electricField(time: t, lineCount: p[0], flowSpeed: p[1]))
        },
    ]

    // MARK: - Fire & Water

    static let elements: [Effect] = [
        Effect("fireEffect", "Fire", .elements, "Procedural flames.",
               animated: true,
               params: [
                .init("intensity", 0...3, 1),
                .init("scale", 1...15, 5),
                .init("speed", 0...4, 1),
               ]) { v, p, t in
            AnyView(v.fireEffect(time: t, intensity: p[0], scale: p[1], speed: p[2]))
        },

        Effect("torchFlame", "Torch", .elements, "Single flickering flame.",
               animated: true,
               params: [
                .init("height", 0...1.5, 0.5),
                .init("width", 0...1, 0.3),
                .init("flickerSpeed", 0...8, 3),
               ]) { v, p, t in
            AnyView(v.torchFlame(time: t, height: p[0], width: p[1], flickerSpeed: p[2]))
        },

        Effect("lavaEffect", "Lava", .elements, "Molten flow with cooling crust.",
               animated: true,
               params: [
                .init("scale", 1...10, 3),
                .init("flowSpeed", 0...2, 0.2),
                .init("coolAmount", 0...1, 0.5),
               ]) { v, p, t in
            AnyView(v.lavaEffect(time: t, scale: p[0], flowSpeed: p[1], coolAmount: p[2]))
        },

        Effect("waterSurface", "Water Surface", .elements, "Rolling water surface.",
               animated: true,
               params: [
                .init("amplitude", 0...2, 0.5),
                .init("frequency", 0...5, 1),
                .init("speed", 0...4, 1),
               ]) { v, p, t in
            AnyView(v.waterSurface(time: t, amplitude: p[0], frequency: p[1], speed: p[2]))
        },

        Effect("caustics", "Caustics", .elements, "Underwater light patterns.",
               animated: true,
               params: [
                .init("scale", 1...15, 5),
                .init("intensity", 0...2, 0.5),
               ]) { v, p, t in
            AnyView(v.caustics(time: t, scale: p[0], intensity: p[1]))
        },

        Effect("underwater", "Underwater", .elements, "Depth tint and murk.",
               animated: true,
               params: [
                .init("depth", 0...1, 0.5),
                .init("murkiness", 0...1, 0.3),
               ]) { v, p, t in
            AnyView(v.underwater(time: t, depth: p[0], murkiness: p[1]))
        },

        Effect("rainDrops", "Rain Drops", .elements, "Droplet impacts and ripples.",
               animated: true,
               params: [
                .init("density", 1...40, 10, decimals: 0),
                .init("size", 0.01...0.5, 0.1),
                .init("rippleSpeed", 0...2, 0.5),
               ]) { v, p, t in
            AnyView(v.rainDrops(time: t, density: p[0], size: p[1], rippleSpeed: p[2]))
        },

        Effect("frostedGlass", "Frosted Glass", .elements, "Scattered frosted surface.",
               params: [
                .init("amount", 0...1, 0.5),
                .init("blurAmount", 0...20, 5, decimals: 1),
               ]) { v, p, _ in
            AnyView(v.frostedGlass(amount: Float(p[0]), blurAmount: Float(p[1])))
        },
    ]

    // MARK: - Generative

    static let generative: [Effect] = [
        Effect("voronoiCells", "Voronoi Cells", .generative, "Coloured Voronoi regions.",
               animated: true,
               params: [
                .init("scale", 1...30, 8),
                .init("jitter", 0...1, 1),
                .init("colorVariation", 0...1, 0.5),
               ]) { v, p, t in
            AnyView(v.voronoiCells(time: t, scale: p[0], jitter: p[1], colorVariation: p[2]))
        },

        Effect("voronoiCrystal", "Crystal", .generative, "Faceted crystal refraction.",
               animated: true,
               params: [
                .init("scale", 1...20, 6),
                .init("facetSharpness", 0...1, 0.5),
                .init("refractAmount", 0...1, 0.2),
               ]) { v, p, t in
            AnyView(v.voronoiCrystal(time: t, scale: p[0], facetSharpness: p[1], refractAmount: p[2]))
        },

        Effect("voronoiShattered", "Shattered", .generative, "Cracked-glass fragments.",
               animated: true,
               params: [
                .init("scale", 1...30, 10),
                .init("crackWidth", 0...0.1, 0.02, decimals: 3),
               ]) { v, p, t in
            AnyView(v.voronoiShattered(time: t, scale: p[0], crackWidth: p[1]))
        },

        Effect("voronoiStainedGlass", "Voronoi Glass", .generative, "Leaded stained-glass cells.",
               animated: true,
               params: [
                .init("scale", 1...25, 8),
                .init("leadWidth", 0...0.2, 0.06, decimals: 3),
                .init("saturation", 0...2, 1),
               ]) { v, p, t in
            AnyView(v.voronoiStainedGlass(time: t, scale: p[0], leadWidth: p[1], saturation: p[2]))
        },

        Effect("voronoiLava", "Voronoi Lava", .generative, "Glowing molten cells.",
               animated: true,
               params: [
                .init("scale", 1...20, 6),
                .init("heatIntensity", 0...3, 1),
               ]) { v, p, t in
            AnyView(v.voronoiLava(time: t, scale: p[0], heatIntensity: p[1]))
        },

        Effect("plasma", "Plasma", .generative, "Classic plasma field.",
               animated: true,
               params: [
                .init("scale", 0.2...5, 1),
                .init("colorSpeed", 0...4, 1),
               ]) { v, p, t in
            AnyView(v.plasma(time: t, scale: p[0], colorSpeed: p[1]))
        },

        Effect("noiseEffect", "Noise", .generative, "Animated value noise.",
               animated: true,
               params: [
                .init("intensity", 0...1, 0.1),
                .init("scale", 1...30, 5),
               ]) { v, p, t in
            AnyView(v.noiseEffect(time: t, intensity: p[0], scale: p[1]))
        },

        Effect("turbulence", "Turbulence", .generative, "Layered turbulent noise.",
               animated: true,
               params: [
                .init("intensity", 0...3, 1),
                .init("scale", 0.5...10, 3),
                .init("octaves", 1...8, 4, isInteger: true),
               ]) { v, p, t in
            AnyView(v.turbulence(time: t, intensity: p[0], scale: p[1], octaves: p[2]))
        },

        Effect("metaballs", "Metaballs", .generative, "Merging organic blobs.",
               animated: true,
               params: [
                .init("blobCount", 2...10, 5, isInteger: true),
                .init("smoothness", 0...2, 0.5),
               ]) { v, p, t in
            AnyView(v.metaballs(time: t, blobCount: Int(p[0].rounded()), smoothness: p[1]))
        },

        Effect("infiniteGrid", "Infinite Grid", .generative, "Perspective grid runner.",
               animated: true,
               params: [
                .init("gridSize", 0.2...4, 1),
                .init("moveSpeed", 0...6, 2),
               ]) { v, p, t in
            AnyView(v.infiniteGrid(time: t, gridSize: p[0], moveSpeed: p[1]))
        },

        Effect("volumetricClouds", "Clouds", .generative, "Raymarched cloud layer.",
               animated: true,
               params: [
                .init("density", 0...1, 0.5),
                .init("coverage", 0...1, 0.5),
               ]) { v, p, t in
            AnyView(v.volumetricClouds(time: t, density: p[0], coverage: p[1]))
        },

        Effect("blackHole", "Black Hole", .generative, "Gravitational lensing disc.",
               animated: true,
               params: [
                .init("mass", 0...3, 1),
                .init("diskBrightness", 0...3, 1),
               ]) { v, p, t in
            AnyView(v.blackHole(time: t, mass: p[0], diskBrightness: p[1]))
        },
    ]

    // MARK: - Particles

    static let particles: [Effect] = [
        Effect("sparkle", "Sparkle", .particles, "Twinkling highlights.",
               params: [
                .init("density", 5...100, 40, decimals: 0),
                .init("intensity", 0...3, 1.5),
               ]) { v, p, _ in
            AnyView(v.sparkle(density: Float(p[0]), intensity: Float(p[1])))
        },

        Effect("snow", "Snow", .particles, "Drifting snowfall.",
               params: [
                .init("density", 5...100, 30, decimals: 0),
                .init("speed", 0...2, 0.3),
               ]) { v, p, _ in
            AnyView(v.snow(density: Float(p[0]), speed: Float(p[1])))
        },

        Effect("rain", "Rain", .particles, "Falling rain streaks.",
               params: [
                .init("density", 5...150, 50, decimals: 0),
                .init("speed", 0...3, 1),
               ]) { v, p, _ in
            AnyView(v.rain(density: Float(p[0]), speed: Float(p[1])))
        },

        Effect("embers", "Embers", .particles, "Rising glowing embers.",
               params: [
                .init("density", 5...100, 25, decimals: 0),
                .init("speed", 0...2, 0.2),
               ]) { v, p, _ in
            AnyView(v.embers(density: Float(p[0]), speed: Float(p[1])))
        },

        Effect("fireflies", "Fireflies", .particles, "Wandering soft lights.",
               params: [.init("count", 2...60, 15, decimals: 0)]) { v, p, _ in
            AnyView(v.fireflies(count: Float(p[0])))
        },

        Effect("confetti", "Confetti", .particles, "Falling colour flakes.",
               params: [.init("density", 5...100, 20, decimals: 0)]) { v, p, _ in
            AnyView(v.confetti(density: Float(p[0])))
        },

        Effect("bubbles", "Bubbles", .particles, "Rising bubbles.",
               params: [.init("density", 5...80, 20, decimals: 0)]) { v, p, _ in
            AnyView(v.bubbles(density: Float(p[0])))
        },

        Effect("starField", "Star Field", .particles, "Travelling starfield.",
               params: [
                .init("density", 10...150, 50, decimals: 0),
                .init("travelSpeed", 0...1, 0.1),
               ]) { v, p, _ in
            AnyView(v.starField(density: Float(p[0]), travelSpeed: Float(p[1])))
        },
    ]

    // MARK: - Transitions

    static let transitions: [Effect] = [
        Effect("dissolveEffect", "Dissolve", .transition, "Noise-driven dissolve.",
               params: [
                .init("progress", 0...1, 0.5),
                .init("scale", 1...40, 10),
                .init("edgeWidth", 0...0.3, 0.05, decimals: 3),
               ]) { v, p, _ in
            AnyView(v.dissolveEffect(progress: p[0], scale: p[1], edgeWidth: p[2]))
        },

        Effect("burnDissolve", "Burn", .transition, "Burning-edge dissolve.",
               params: [
                .init("progress", 0...1, 0.5),
                .init("scale", 1...30, 8),
                .init("burnWidth", 0...0.5, 0.15),
               ]) { v, p, _ in
            AnyView(v.burnDissolve(progress: p[0], scale: p[1], burnWidth: p[2]))
        },

        Effect("pixelDissolve", "Pixel Dissolve", .transition, "Blocks disappear in order.",
               params: [
                .init("progress", 0...1, 0.5),
                .init("pixelSize", 0.005...0.15, 0.02, decimals: 3),
               ]) { v, p, _ in
            AnyView(v.pixelDissolve(progress: p[0], pixelSize: p[1]))
        },

        Effect("directionalDissolve", "Wipe", .transition, "Directional edge wipe.",
               params: [
                .init("progress", 0...1, 0.5),
                .init("angle", 0...6.28, 0),
                .init("edgeWidth", 0...0.3, 0.05, decimals: 3),
               ]) { v, p, _ in
            AnyView(v.directionalDissolve(progress: p[0], angle: p[1], edgeWidth: p[2]))
        },

        Effect("pixelateTransition", "Pixelate Out", .transition, "Resolution collapse.",
               params: [
                .init("progress", 0...1, 0.5),
                .init("maxPixelSize", 5...120, 50, decimals: 0),
               ]) { v, p, _ in
            AnyView(v.pixelateTransition(progress: p[0], maxPixelSize: p[1]))
        },
    ]
}
