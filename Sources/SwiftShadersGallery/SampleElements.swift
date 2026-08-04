import SwiftUI

/// The UI elements an effect can be previewed on.
enum SampleElement: String, CaseIterable, Identifiable {
    case card = "Card"
    case button = "Button"
    case text = "Text"
    case icon = "Icon"
    case photo = "Photo"
    case list = "List"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .card: "rectangle.on.rectangle"
        case .button: "capsule"
        case .text: "textformat"
        case .icon: "star"
        case .photo: "photo"
        case .list: "list.bullet"
        }
    }

    @ViewBuilder
    var view: some View {
        switch self {
        case .card: SampleCard()
        case .button: SampleButton()
        case .text: SampleText()
        case .icon: SampleIcon()
        case .photo: SamplePhoto()
        case .list: SampleList()
        }
    }
}

// MARK: - Samples

struct SampleCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Circle()
                    .fill(LinearGradient(colors: [.orange, .pink],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 44, height: 44)
                    .overlay(Text("SS").font(.headline).foregroundStyle(.white))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Northern Lights").font(.headline)
                    Text("Tromsø · 4 nights").font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text("Aurora forecast is strong all week, with clear skies expected after Tuesday.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Label("4.9", systemImage: "star.fill").foregroundStyle(.yellow)
                Spacer()
                Text("$1,240").font(.title3.bold())
            }
            .font(.subheadline)
        }
        .padding(20)
        .frame(width: 320)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(.separator))
        .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
    }
}

struct SampleButton: View {
    var body: some View {
        VStack(spacing: 18) {
            Text("Continue")
                .font(.headline)
                .foregroundStyle(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 44)
                .background(
                    LinearGradient(colors: [.blue, .purple],
                                   startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .shadow(color: .blue.opacity(0.45), radius: 14, y: 6)

            Text("Cancel")
                .font(.headline)
                .padding(.vertical, 14)
                .padding(.horizontal, 44)
                .background(.background.secondary, in: Capsule())
                .overlay(Capsule().strokeBorder(.separator))
        }
    }
}

struct SampleText: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shaders")
                .font(.system(size: 56, weight: .heavy, design: .rounded))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .blue, .purple],
                                   startPoint: .leading, endPoint: .trailing)
                )
            Text("Metal effects, one modifier at a time.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
        .frame(width: 340, alignment: .leading)
    }
}

struct SampleIcon: View {
    var body: some View {
        Image(systemName: "bolt.horizontal.fill")
            .font(.system(size: 130))
            .symbolRenderingMode(.palette)
            .foregroundStyle(.yellow, .orange)
            .padding(30)
    }
}

/// Stands in for a photograph — a gradient with enough structure that
/// distortion and blur effects are legible.
struct SamplePhoto: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [.indigo, .purple, .pink, .orange],
                           startPoint: .top, endPoint: .bottom)

            Circle()
                .fill(.yellow.opacity(0.9))
                .frame(width: 70)
                .offset(x: 70, y: -70)
                .blur(radius: 2)

            VStack(spacing: 0) {
                Spacer()
                ForEach(0..<3) { i in
                    Triangle()
                        .fill(.black.opacity(0.55 - Double(i) * 0.12))
                        .frame(height: 90 - CGFloat(i) * 18)
                        .offset(x: CGFloat(i) * 40 - 40)
                }
            }
        }
        .frame(width: 320, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator))
    }
}

struct SampleList: View {
    private let rows = [
        ("wifi", "Network", "Connected"),
        ("bell.badge", "Notifications", "3 new"),
        ("lock.shield", "Privacy", "Protected"),
        ("battery.100", "Battery", "92%"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 14) {
                    Image(systemName: row.0)
                        .frame(width: 26)
                        .foregroundStyle(.tint)
                    Text(row.1)
                    Spacer()
                    Text(row.2).foregroundStyle(.secondary)
                }
                .font(.callout)
                .padding(.horizontal, 18)
                .padding(.vertical, 13)

                if index < rows.count - 1 {
                    Divider().padding(.leading, 58)
                }
            }
        }
        .frame(width: 320)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.separator))
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
