import SwiftUI
import SwiftShaders
import SwiftShadersGalleryCore

struct ContentView: View {
    @State private var selection: Effect.ID = EffectCatalog.all.first!.id
    @State private var sample: SampleElement = .card
    @State private var search = ""

    /// Slider values, kept per effect so switching back restores your tweaks.
    @State private var values: [Effect.ID: ParamValues] = [:]

    @State private var isPlaying = true
    @State private var showsBackdrop = true

    private var effect: Effect {
        EffectCatalog.effect(id: selection) ?? EffectCatalog.all[0]
    }

    private var binding: Binding<ParamValues> {
        Binding(
            get: { values[selection] ?? ParamValues(effect.params) },
            set: { values[selection] = $0 }
        )
    }

    private var groups: [(EffectCategory, [Effect])] {
        let all = EffectCatalog.grouped()
        guard !search.isEmpty else { return all }
        let q = search.lowercased()
        return all.compactMap { cat, items in
            let hits = items.filter {
                $0.name.lowercased().contains(q) || $0.id.lowercased().contains(q)
            }
            return hits.isEmpty ? nil : (cat, hits)
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationTitle("SwiftShaders")
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selection) {
            ForEach(groups, id: \.0.id) { category, items in
                Section {
                    ForEach(items) { item in
                        Label(item.name, systemImage: category.symbol)
                            .tag(item.id)
                    }
                } header: {
                    Text(category.rawValue)
                }
            }
        }
        .searchable(text: $search, placement: .sidebar, prompt: "Search effects")
        .navigationSplitViewColumnWidth(min: 210, ideal: 240)
        .safeAreaInset(edge: .bottom) {
            Text("\(EffectCatalog.all.count) effects")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(.bar)
        }
    }

    // MARK: - Detail

    private var detail: some View {
        HSplitView {
            VStack(spacing: 0) {
                toolbar
                Divider()
                PreviewCanvas(
                    effect: effect,
                    values: binding.wrappedValue,
                    sample: sample,
                    isPlaying: isPlaying,
                    showsBackdrop: showsBackdrop
                )
            }
            .frame(minWidth: 420)

            inspector
                .frame(minWidth: 320, idealWidth: 360, maxWidth: 460)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 14) {
            Picker("", selection: $sample) {
                ForEach(SampleElement.allCases) { s in
                    Label(s.rawValue, systemImage: s.symbol).tag(s)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .fixedSize()

            Spacer()

            Toggle(isOn: $showsBackdrop) {
                Image(systemName: "checkerboard.rectangle")
            }
            .toggleStyle(.button)
            .help("Toggle the checkerboard backdrop")

            if effect.animated {
                Toggle(isOn: $isPlaying) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                .toggleStyle(.button)
                .help(isPlaying ? "Pause animation" : "Play animation")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Inspector

    private var inspector: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(effect.name).font(.title2.bold())
                    Text(effect.blurb).font(.callout).foregroundStyle(.secondary)
                    if effect.animated {
                        Label("Driven by TimelineView", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if effect.params.isEmpty {
                    Text("This effect takes no parameters.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Parameters").font(.headline)
                        ForEach(Array(effect.params.enumerated()), id: \.element.id) { i, param in
                            ParameterSlider(param: param, value: sliderBinding(i))
                        }
                        Button("Reset to defaults") {
                            values[selection] = ParamValues(effect.params)
                        }
                        .buttonStyle(.link)
                        .font(.callout)
                    }
                }

                CodePanel(code: effect.code(binding.wrappedValue))
            }
            .padding(20)
        }
        .background(.background.secondary)
    }

    private func sliderBinding(_ index: Int) -> Binding<Double> {
        Binding(
            get: { binding.wrappedValue[index] },
            set: { newValue in
                var current = binding.wrappedValue
                current[index] = newValue
                binding.wrappedValue = current
            }
        )
    }
}

// MARK: - Preview canvas

struct PreviewCanvas: View {
    let effect: Effect
    let values: ParamValues
    let sample: SampleElement
    let isPlaying: Bool
    let showsBackdrop: Bool

    @State private var start = Date.now
    /// Time held while paused, so pausing freezes rather than resets.
    @State private var frozen: Double = 0

    var body: some View {
        ZStack {
            if showsBackdrop {
                Checkerboard().opacity(0.35)
            } else {
                Color.clear
            }

            Group {
                if effect.animated {
                    TimelineView(.animation(paused: !isPlaying)) { timeline in
                        let t = isPlaying ? start.distance(to: timeline.date) : frozen
                        content(time: t)
                            .onChange(of: isPlaying) { _, playing in
                                if playing {
                                    // Resume from where we froze.
                                    start = Date.now.addingTimeInterval(-frozen)
                                } else {
                                    frozen = start.distance(to: Date.now)
                                }
                            }
                    }
                } else {
                    content(time: 0)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func content(time: Double) -> some View {
        effect.build(AnyView(sample.view), values, time)
            .id(effect.id)
    }
}

private struct Checkerboard: View {
    var body: some View {
        Canvas { context, size in
            let step: CGFloat = 16
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.gray.opacity(0.10)))
            var y: CGFloat = 0
            var row = 0
            while y < size.height {
                var x: CGFloat = (row % 2 == 0) ? 0 : step
                while x < size.width {
                    context.fill(
                        Path(CGRect(x: x, y: y, width: step, height: step)),
                        with: .color(.gray.opacity(0.16))
                    )
                    x += step * 2
                }
                y += step
                row += 1
            }
        }
    }
}

// MARK: - Parameter slider

struct ParameterSlider: View {
    let param: EffectParam
    @Binding var value: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(param.title).font(.callout)
                Spacer()
                Text(param.literal(value))
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            if param.isInteger {
                Slider(value: $value, in: param.range,
                       step: 1)
            } else {
                Slider(value: $value, in: param.range)
            }
        }
    }
}

// MARK: - Code panel

struct CodePanel: View {
    let code: String
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Swift").font(.headline)
                Spacer()
                Button {
                    Pasteboard.copy(code)
                    copied = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        copied = false
                    }
                } label: {
                    Label(copied ? "Copied" : "Copy",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            ScrollView(.horizontal, showsIndicators: true) {
                Text(code)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.separator))
        }
    }
}
