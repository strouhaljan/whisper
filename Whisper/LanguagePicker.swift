import SwiftUI

/// The languages Whisper v3 supports, with ISO 639-1 codes.
/// Sorted by rough global usage / likelihood of being selected.
enum SupportedLanguage {
    static let all: [(code: String, name: String)] = [
        ("en", "English"),
        ("zh", "Chinese"),
        ("es", "Spanish"),
        ("hi", "Hindi"),
        ("ar", "Arabic"),
        ("pt", "Portuguese"),
        ("fr", "French"),
        ("de", "German"),
        ("ja", "Japanese"),
        ("ko", "Korean"),
        ("ru", "Russian"),
        ("it", "Italian"),
        ("nl", "Dutch"),
        ("pl", "Polish"),
        ("cs", "Czech"),
        ("sk", "Slovak"),
        ("uk", "Ukrainian"),
        ("tr", "Turkish"),
        ("sv", "Swedish"),
        ("da", "Danish"),
        ("no", "Norwegian"),
        ("fi", "Finnish"),
        ("hu", "Hungarian"),
        ("ro", "Romanian"),
        ("bg", "Bulgarian"),
        ("hr", "Croatian"),
        ("sr", "Serbian"),
        ("sl", "Slovenian"),
        ("el", "Greek"),
        ("he", "Hebrew"),
        ("th", "Thai"),
        ("vi", "Vietnamese"),
        ("id", "Indonesian"),
        ("ms", "Malay"),
        ("tl", "Filipino"),
        ("ca", "Catalan"),
        ("eu", "Basque"),
        ("gl", "Galician"),
        ("cy", "Welsh"),
        ("af", "Afrikaans"),
        ("sw", "Swahili"),
        ("ta", "Tamil"),
        ("te", "Telugu"),
        ("ur", "Urdu"),
        ("bn", "Bengali"),
        ("ne", "Nepali"),
        ("si", "Sinhala"),
        ("la", "Latin"),
    ]

    static func name(for code: String) -> String {
        all.first { $0.code == code }?.name ?? code
    }
}

/// A compact multi-select language picker shown as toggle chips in a flow layout,
/// with a search field for the full list.
struct LanguagePicker: View {
    @Binding var selected: [String]
    @State private var showPicker = false
    @State private var search = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Selected chips
            FlowLayout(spacing: 4) {
                ForEach(selected, id: \.self) { code in
                    chip(code: code)
                }
                Button {
                    showPicker.toggle()
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            if selected.isEmpty {
                Text("Auto-detect")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if showPicker {
                VStack(spacing: 4) {
                    TextField("Search languages…", text: $search)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(filtered, id: \.code) { lang in
                                Button {
                                    toggle(lang.code)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: selected.contains(lang.code) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selected.contains(lang.code) ? Color.accentColor : Color.secondary)
                                            .font(.caption)
                                        Text(lang.name)
                                            .font(.caption)
                                        Spacer()
                                        Text(lang.code)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                    .contentShape(Rectangle())
                                    .padding(.vertical, 2)
                                    .padding(.horizontal, 4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 140)
                }
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(.background)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                )
            }
        }
    }

    private var filtered: [(code: String, name: String)] {
        if search.isEmpty { return SupportedLanguage.all }
        let q = search.lowercased()
        return SupportedLanguage.all.filter {
            $0.name.lowercased().contains(q) || $0.code.lowercased().contains(q)
        }
    }

    private func toggle(_ code: String) {
        if let idx = selected.firstIndex(of: code) {
            selected.remove(at: idx)
        } else {
            selected.append(code)
        }
    }

    private func chip(code: String) -> some View {
        HStack(spacing: 3) {
            Text(SupportedLanguage.name(for: code))
                .font(.caption)
            Button {
                selected.removeAll { $0 == code }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(.quaternary)
        )
    }
}

/// Simple flow layout that wraps children to the next line.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var height: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            height += rowHeight
            if i > 0 { height += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { subviews[$0].sizeThatFits(.unspecified).height }.max() ?? 0
            if i > 0 { y += spacing }
            var x = bounds.minX
            for idx in row {
                let size = subviews[idx].sizeThatFits(.unspecified)
                subviews[idx].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[Int]] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[Int]] = [[]]
        var x: CGFloat = 0
        for (i, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(i)
            x += size.width + spacing
        }
        return rows
    }
}
