import Foundation

/// Every public `View` effect method in SwiftShaders, and what the Gallery does
/// about it.
///
/// **Why this exists.** The library's public surface is a set of `View`
/// extension methods. Nothing enumerates them: there is no registry (the one
/// that used to claim to be one named 19 effects that did not exist and one
/// Metal function that did not either), and nothing at runtime can list static
/// extension members. So "does the Gallery represent the library?" was a
/// question no one could answer, and the answer drifted for 226 methods and 91
/// gallery entries without a single test noticing.
///
/// **Why it lives in the test target.** The ledger has no runtime purpose. It is
/// a claim *about* the library, checked against the library, and shipping it
/// would add public API to a package that has just finished removing some. Its
/// only consumer is `EffectCoverageTests`, and it sits next to the scanner that
/// audits it.
///
/// **What the tests do with it** (`EffectCoverageTests`):
/// 1. no phantom gallery entries — every `.inGallery(id)` names a real catalogue
///    entry, and every catalogue entry names a real public method;
/// 2. completeness — a scanner over `Sources/**/*.swift` finds every public
///    `View` effect method, and fails naming any this file omits or invents;
/// 3. the ratchet — `deliberatelyAbsent` may only ever get smaller.
///
/// **Adding an effect** means adding a line here as well as the method. The
/// completeness test will tell you so.
enum EffectCoverage {

    /// What the Gallery does about one public effect method.
    enum Disposition: Equatable {
        /// Previewable in the Gallery under this `Effect.id`.
        case inGallery(String)

        /// A zero-argument convenience over another method, covered by that
        /// method's gallery entry rather than needing one of its own. The
        /// argument is the base method's selector, which must itself be in this
        /// ledger — the tests check that.
        case presetOf(String)

        /// Not in the Gallery, with a reason. **This is a backlog, and the
        /// ratchet test only lets it shrink.**
        case deliberatelyAbsent(String)
    }

    /// The reasons an effect is absent. A small vocabulary rather than free text,
    /// so the backlog can be counted by kind and so a future editor has
    /// something specific to disagree with.
    enum Absence {
        /// No gallery entry has been authored yet. Nothing is wrong with the
        /// effect — writing an entry means choosing a display name, a category,
        /// a blurb and a slider range per parameter, and that work has not been
        /// done. This is the bulk of the backlog and the number the ratchet is
        /// really about.
        static let backlog = "no gallery entry authored yet"

        /// Every parameter is a `Color`, `CGPoint`, enum or configuration value.
        /// The Gallery's parameter model is a list of `Double` sliders, so such
        /// an effect can only be shown at its defaults until the model grows a
        /// colour well or a point picker. Entering one is a real design decision,
        /// not a transcription job.
        static let unsliderableInput = "every parameter is a colour, point or configuration value the slider model cannot drive"

        /// A zero-argument method that is the only way to reach its shader, so
        /// unlike the other presets it is not covered by a parameterised sibling.
        static let soleEntryPoint = "zero-argument method with no parameterised sibling to be a preset of"

        /// Kept only so 2.0.0 callers keep compiling. Cataloguing it would
        /// advertise the spelling being retired.
        static let deprecated = "deprecated shim, scheduled for removal"
    }

    struct Entry {
        /// Method name plus argument labels, e.g. `vignette(radius:softness:intensity:)`.
        /// Four names in this library are declared twice in different files, so
        /// the name alone is not an identity.
        let selector: String
        let disposition: Disposition

        init(_ selector: String, _ disposition: Disposition) {
            self.selector = selector
            self.disposition = disposition
        }
    }

    /// Ordered by source file, then by declaration order within the file, so a
    /// diff here reads like a diff of the sources.
    static let entries: [Entry] = [

        // MARK: Blur

        Entry("radialBlur(center:strength:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("motionBlur(angle:strength:)", .inGallery("motionBlur")),
        Entry("tiltShift(focusY:focusWidth:blurStrength:)", .inGallery("tiltShift")),
        Entry("depthOfField(focalDistance:aperture:maxBlur:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("frostEffect(time:amount:grainSize:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("softGlow(intensity:threshold:)", .inGallery("softGlow")),

        // MARK: CRT

        Entry("crtEffect(configuration:style:)", .deliberatelyAbsent(Absence.unsliderableInput)),
        Entry("crtScanlines(count:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("arcadeCRT()", .presetOf("crtEffect(configuration:style:)")),
        Entry("televisionCRT()", .presetOf("crtEffect(configuration:style:)")),

        // MARK: ChromaticAberration

        Entry("chromaticAberration(intensity:angle:)", .inGallery("chromaticAberration")),
        Entry("directionalChromatic(intensity:angle:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("pulsingChromatic(time:baseIntensity:pulseSpeed:pulseAmount:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("rgbSplit(splitX:splitY:)", .inGallery("rgbSplit")),

        // MARK: ColorGrading

        Entry("colorGrading(brightness:contrast:saturation:hueShift:temperature:tint:)", .inGallery("colorGrading")),
        Entry("levels(inputBlack:inputWhite:gamma:outputBlack:outputWhite:)", .inGallery("levels")),
        Entry("curves(shadowLift:midtoneContrast:highlightCompress:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("splitToning(shadowHue:shadowSaturation:highlightHue:highlightSaturation:balance:)", .inGallery("splitToning")),
        Entry("vibrance(_:)", .inGallery("vibrance")),
        Entry("filmEmulation(_:intensity:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Displacement

        Entry("sineDisplacement(time:amplitudeX:amplitudeY:frequencyX:frequencyY:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("noiseDisplacement(time:scale:amount:speed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("fbmDisplacement(time:scale:amount:octaves:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("radialDisplacement(time:amount:frequency:center:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("spiralDisplacement(time:amount:tightness:center:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("heatDistortion(time:intensity:riseFactor:turbulence:)", .inGallery("heatDistortion")),
        Entry("underwaterDisplacement(time:waveScale:waveAmount:depthFactor:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("shockwaveDisplacement(time:center:waveWidth:amplitude:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("lensDistortion(time:k1:k2:center:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("flagWave(time:amplitude:frequency:propagation:)", .inGallery("flagWave")),
        Entry("spherize(time:amount:radius:center:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("twirl(time:angle:radius:center:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("pinch(time:amount:radius:center:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("zigzag(time:amplitude:frequency:angle:)", .inGallery("zigzag")),
        Entry("blobDisplacement(time:scale:amount:smoothness:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("breathingDisplacement(time:amount:speed:center:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("blockDisplacement(time:blockSize:amount:probability:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("scanlineJitter(time:lineHeight:jitterAmount:probability:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("windDisplacement(time:strength:gustiness:direction:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("earthquakeDisplacement(time:magnitude:frequency:decay:)", .inGallery("earthquakeDisplacement")),
        Entry("magneticDisplacement(time:strength:pole:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Dissolve

        Entry("dissolveEffect(progress:scale:edgeWidth:)", .inGallery("dissolveEffect")),
        Entry("directionalDissolve(progress:angle:edgeWidth:)", .inGallery("directionalDissolve")),
        Entry("radialDissolve(progress:center:edgeWidth:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("burnDissolve(progress:scale:burnWidth:)", .inGallery("burnDissolve")),
        Entry("pixelDissolve(progress:pixelSize:)", .inGallery("pixelDissolve")),

        // MARK: Distortion

        Entry("barrelDistortion(strength:zoom:)", .inGallery("barrelDistortion")),
        Entry("sphereBulge(center:radius:strength:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("pinchDistortion(center:radius:strength:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("swirlDistortion(center:radius:angle:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("kaleidoscopeDistort(segments:rotation:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("magnify(center:radius:magnification:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("lensWarp(k1:k2:center:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Electric

        Entry("lightning(time:intensity:branchiness:glowRadius:)", .inGallery("lightning")),
        Entry("plasma(time:scale:colorSpeed:)", .inGallery("plasma")),
        Entry("electricArc(time:start:end:thickness:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("staticElectricity(time:density:sparkSize:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("electricField(time:lineCount:flowSpeed:)", .inGallery("electricField")),
        Entry("neonElectric(time:glowIntensity:flickerSpeed:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Emboss

        Entry("emboss(strength:lightAngle:)", .inGallery("emboss")),
        Entry("embossColor(strength:lightAngle:colorMix:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("deboss(strength:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("metallicEmboss(_:)", .deliberatelyAbsent(Absence.unsliderableInput)),
        Entry("goldEmboss()", .presetOf("metallicEmboss(_:)")),
        Entry("silverEmboss()", .presetOf("metallicEmboss(_:)")),
        Entry("bumpMap(depth:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Fire

        Entry("fireEffect(time:intensity:scale:speed:)", .inGallery("fireEffect")),
        Entry("torchFlame(time:height:width:flickerSpeed:)", .inGallery("torchFlame")),
        Entry("fireball(time:center:radius:turbulence:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("embers(time:density:speed:size:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("lavaEffect(time:scale:flowSpeed:coolAmount:)", .inGallery("lavaEffect")),

        // MARK: Frost

        Entry("frostedGlass(amount:blurAmount:)", .inGallery("frostedGlass")),
        Entry("frostLight()", .presetOf("frostedGlass(amount:blurAmount:)")),
        Entry("frostHeavy()", .presetOf("frostedGlass(amount:blurAmount:)")),
        Entry("iceCrystals(density:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("windowFrost(coverage:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("breathFrost(at:)", .deliberatelyAbsent(Absence.unsliderableInput)),
        Entry("frozen(thickness:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Glitch

        Entry("glitchEffect(time:intensity:blockSize:)", .inGallery("glitchEffect")),
        Entry("glitchColor(time:intensity:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("vhsGlitch(time:intensity:noiseAmount:)", .inGallery("vhsGlitch")),
        Entry("digitalCorruption(time:intensity:blockWidth:blockHeight:)", .inGallery("digitalCorruption")),
        Entry("signalInterference(time:intensity:frequency:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Hologram

        Entry("hologramEffect(time:scanlineIntensity:flickerSpeed:colorShift:)", .inGallery("hologramEffect")),
        Entry("glitchyHologram(time:glitchIntensity:noiseAmount:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("wireframeHologram(time:gridSize:lineWidth:)", .inGallery("wireframeHologram")),
        Entry("projectionHologram(time:lineSpacing:perspectiveAmount:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("dataStreamHologram(time:streamSpeed:density:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("retroHologram(time:bandCount:speed:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Invert

        Entry("invert(amount:)", .inGallery("invert")),
        Entry("invertSmart(threshold:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("invertChannels(red:green:blue:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("negativeFilm(orangeMask:)", .inGallery("negativeFilm")),
        Entry("xray(intensity:)", .inGallery("xray")),
        Entry("solarize(threshold:)", .inGallery("solarize")),
        Entry("invertAnimated(speed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("invertRegion(at:radius:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Kaleidoscope

        Entry("kaleidoscope(segments:rotation:)", .inGallery("kaleidoscope")),
        Entry("kaleidoscopeAnimated(segments:speed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("kaleidoscopeTriangle(scale:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("kaleidoscopeSquare(scale:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("kaleidoscopeHex(scale:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("kaleidoscopeSnowflake()", .presetOf("kaleidoscope(segments:rotation:)")),

        // MARK: Mosaic

        Entry("mosaicSquare(tileSize:groutWidth:groutColor:)", .inGallery("mosaicSquare")),
        Entry("mosaicHexagon(tileSize:groutWidth:)", .inGallery("mosaicHexagon")),
        Entry("stainedGlass(cellSize:)", .inGallery("stainedGlass")),
        Entry("mosaicBrick(brickWidth:brickHeight:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("mosaicDiamond(tileSize:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("pixelArt(pixelSize:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Neon

        Entry("neonGlow(_:)", .deliberatelyAbsent(Absence.unsliderableInput)),
        Entry("neonGlow(color:intensity:threshold:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("neonOutline(color:width:intensity:)", .inGallery("neonOutline")),
        Entry("neonRainbow(speed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("neonElectric(color:intensity:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("neonTint(color:intensity:)", .inGallery("neonTint")),

        // MARK: Noise

        Entry("noiseEffect(time:intensity:scale:)", .inGallery("noiseEffect")),
        Entry("filmGrain(time:intensity:size:)", .inGallery("filmGrain")),
        Entry("perlinDistort(time:intensity:scale:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("fbmNoise(time:scale:octaves:lacunarity:gain:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("cellularNoise(time:scale:intensity:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("voronoiNoise(time:scale:intensity:)", .deliberatelyAbsent(Absence.deprecated)),
        Entry("turbulence(time:intensity:scale:octaves:)", .inGallery("turbulence")),

        // MARK: Particles

        Entry("sparkle(density:intensity:)", .inGallery("sparkle")),
        Entry("snow(density:speed:)", .inGallery("snow")),
        Entry("rain(density:speed:)", .inGallery("rain")),
        Entry("embers(density:speed:)", .inGallery("embers")),
        Entry("bubbles(density:)", .inGallery("bubbles")),
        Entry("starField(density:travelSpeed:)", .inGallery("starField")),
        Entry("confetti(density:)", .inGallery("confetti")),
        Entry("fireflies(count:)", .inGallery("fireflies")),

        // MARK: Pixelate

        Entry("pixelateEffect(pixelSize:)", .inGallery("pixelateEffect")),
        Entry("pixelateTransition(progress:maxPixelSize:)", .inGallery("pixelateTransition")),
        Entry("hexPixelate(hexSize:)", .inGallery("hexPixelate")),
        Entry("diamondPixelate(diamondSize:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("dotMatrix(dotSize:spacing:)", .inGallery("dotMatrix")),
        Entry("ledMatrix(ledSize:gap:brightness:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Posterize

        Entry("posterize(levels:)", .inGallery("posterize")),
        Entry("posterizePopArt(levels:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("posterizeDuotone(dark:light:levels:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("posterizeTritone(shadow:mid:highlight:levels:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("posterizeAnimated(speed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("comicBook()", .presetOf("posterizePopArt(levels:)")),

        // MARK: Raymarching

        Entry("raymarching(time:cameraDistance:rotationSpeed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("metaballs(time:blobCount:smoothness:)", .inGallery("metaballs")),
        Entry("sdfShapes(time:operation:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("infiniteGrid(time:gridSize:moveSpeed:)", .inGallery("infiniteGrid")),
        Entry("tunnel(time:shape:speed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("volumetricClouds(time:density:coverage:)", .inGallery("volumetricClouds")),
        Entry("fractalTerrain(time:height:octaves:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("blackHole(time:mass:diskBrightness:)", .inGallery("blackHole")),

        // MARK: Ripple

        Entry("rippleEffect(time:origin:amplitude:frequency:decay:)", .inGallery("rippleEffect")),
        Entry("multiRippleEffect(time:count:amplitude:frequency:decay:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("animatedRipple(origin:amplitude:frequency:decay:speed:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Scanlines

        Entry("scanlines(count:intensity:)", .inGallery("scanlines")),
        Entry("scanlinesSubtle()", .presetOf("scanlines(count:intensity:)")),
        Entry("scanlinesCRT()", .presetOf("scanlines(count:intensity:)")),
        Entry("scanlinesInterlaced(intensity:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("scanlinesVHS(noiseAmount:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("scanlinesLCD(pixelSize:)", .inGallery("scanlinesLCD")),
        Entry("scanlinesRolling(speed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("scanlinesDiagonal(angle:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Sepia

        Entry("sepia(intensity:)", .inGallery("sepia")),
        Entry("vintagePhoto(fadeAmount:warmth:contrast:)", .inGallery("vintagePhoto")),
        Entry("agedFilm(grainIntensity:scratchIntensity:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("polaroid(exposure:saturation:)", .inGallery("polaroid")),
        Entry("crossProcess(intensity:)", .inGallery("crossProcess")),
        Entry("fadedMemory(fadeAmount:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Sharpen

        Entry("sharpen(amount:)", .inGallery("sharpen")),
        Entry("unsharpMask(radius:amount:threshold:)", .inGallery("unsharpMask")),
        Entry("highPassSharpen(radius:strength:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("enhanceEdges(amount:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("clarity(amount:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("sharpenPortrait()", .presetOf("unsharpMask(radius:amount:threshold:)")),
        Entry("sharpenLandscape()", .presetOf("unsharpMask(radius:amount:threshold:)")),

        // MARK: Sketch

        Entry("sketchPencil(intensity:)", .inGallery("sketchPencil")),
        Entry("sketchCrossHatch(spacing:lineWidth:)", .inGallery("sketchCrossHatch")),
        Entry("sketchInk(threshold:)", .inGallery("sketchInk")),
        Entry("sketchCharcoal(smudge:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("sketchWatercolor(bleed:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Swirl

        Entry("swirl(angle:radius:center:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("swirlAnimated(speed:radius:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("vortex(angle:pullStrength:)", .inGallery("vortex")),
        Entry("pinch(strength:radius:)", .inGallery("pinch")),
        Entry("bulge(strength:radius:)", .inGallery("bulge")),
        Entry("twirl(angle:)", .inGallery("twirl")),

        // MARK: Threshold

        Entry("threshold(_:)", .inGallery("threshold")),
        Entry("threshold(_:low:high:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("thresholdDithered(_:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("thresholdSmooth(_:softness:)", .inGallery("thresholdSmooth")),
        Entry("halftone(dotSize:angle:)", .inGallery("halftone")),
        Entry("thresholdLevels(_:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("thresholdAnimated(speed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("thresholdTriple(dark:mid:light:)", .deliberatelyAbsent(Absence.unsliderableInput)),

        // MARK: Vignette

        Entry("vignette(radius:softness:intensity:)", .inGallery("vignette")),
        Entry("vignetteSubtle()", .presetOf("vignette(radius:softness:intensity:)")),
        Entry("vignetteStrong()", .presetOf("vignette(radius:softness:intensity:)")),
        Entry("vignetteCinematic()", .deliberatelyAbsent(Absence.soleEntryPoint)),
        Entry("vignetteColored(color:radius:intensity:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("vignetteSpotlight(at:radius:dimAmount:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("vignetteAnimated(speed:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Voronoi

        Entry("voronoiNoise(time:scale:jitter:edgeWidth:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("voronoiCells(time:scale:jitter:colorVariation:)", .inGallery("voronoiCells")),
        Entry("voronoiEdgeGlow(time:scale:glowWidth:glowColor:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("voronoiCrystal(time:scale:facetSharpness:refractAmount:)", .inGallery("voronoiCrystal")),
        Entry("voronoiShattered(time:scale:crackWidth:crackColor:)", .inGallery("voronoiShattered")),
        Entry("voronoiCellular(time:scale:membraneWidth:membraneColor:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("voronoiHoneycomb(time:scale:wallWidth:wallColor:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("voronoiDistort(time:scale:distortAmount:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("voronoiLiquid(time:scale:flowSpeed:flowAmount:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("voronoiLava(time:scale:heatIntensity:)", .inGallery("voronoiLava")),
        Entry("voronoiPlasma(time:scale:pulseSpeed:plasmaColor:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("voronoiCaustics(time:scale:brightness:sharpness:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("voronoiStainedGlass(time:scale:leadWidth:saturation:)", .inGallery("voronoiStainedGlass")),
        Entry("voronoiFrost(time:scale:crackDepth:frostiness:)", .deliberatelyAbsent(Absence.backlog)),

        // MARK: Water

        Entry("waterSurface(time:amplitude:frequency:speed:)", .inGallery("waterSurface")),
        Entry("waterReflection(time:reflectivity:distortion:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("caustics(time:scale:intensity:)", .inGallery("caustics")),
        Entry("oceanWaves(time:waveHeight:waveLength:foamThreshold:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("rainDrops(time:density:size:rippleSpeed:)", .inGallery("rainDrops")),
        Entry("underwater(time:depth:murkiness:)", .inGallery("underwater")),

        // MARK: Wave

        Entry("waveEffect(time:amplitude:frequency:direction:)", .inGallery("waveEffect")),
        Entry("multiWave(time:amplitudeX:amplitudeY:frequencyX:frequencyY:speed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("radialWave(time:amplitude:frequency:center:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("waveFlag(time:amplitude:frequency:windSpeed:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("liquidWave(time:amplitude:turbulence:viscosity:)", .deliberatelyAbsent(Absence.backlog)),
        Entry("jellyWave(time:amplitude:stiffness:damping:)", .deliberatelyAbsent(Absence.backlog)),    ]

    // MARK: - Derived views

    static var selectors: Set<String> { Set(entries.map(\.selector)) }

    static var galleryIds: [String] {
        entries.compactMap { if case .inGallery(let id) = $0.disposition { return id } else { return nil } }
    }

    static var presetBases: [(selector: String, base: String)] {
        entries.compactMap {
            if case .presetOf(let base) = $0.disposition { return ($0.selector, base) } else { return nil }
        }
    }

    static var absent: [(selector: String, reason: String)] {
        entries.compactMap {
            if case .deliberatelyAbsent(let reason) = $0.disposition { return ($0.selector, reason) } else { return nil }
        }
    }
}
