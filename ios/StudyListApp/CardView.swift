import SwiftUI

struct CardView: View {
    let card: Card
    @State private var showFurigana = false
    @State private var showFull = false

    var body: some View {
        VStack(spacing: 0) {
            // Button bar
            HStack(spacing: 12) {
                Button {
                    withAnimation { showFurigana.toggle() }
                } label: {
                    Text(showFurigana ? "Furigana On" : "Furigana")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(showFurigana ? .primary : .secondary)
                }

                Button {
                    withAnimation { showFull.toggle() }
                } label: {
                    Text(showFull ? "Full On" : "Full")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(showFull ? .primary : .secondary)
                }

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if showFull {
                        // Full view: Japanese + reading + HTML definition
                        VStack(alignment: .leading, spacing: 12) {
                            if showFurigana {
                                FuriganaText(text: card.japanese)
                                    .font(.title)
                                    .fontWeight(.bold)
                            } else {
                                Text(stripBrackets(card.japanese))
                                    .font(.title)
                                    .fontWeight(.bold)
                            }

                            if let reading = card.reading, !reading.isEmpty {
                                Text(reading)
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }

                            HTMLText(html: card.english)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()

                    } else {
                        // Front view: just Japanese (with or without furigana)
                        if showFurigana {
                            FuriganaText(text: card.japanese)
                                .font(.title)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 30)
                        } else {
                            Text(stripBrackets(card.japanese))
                                .font(.title)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 30)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 160)
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 3)
        .onTapGesture {
            if !showFull {
                withAnimation { showFull = true }
            }
        }
    }

    private func stripBrackets(_ text: String) -> String {
        // Remove [furigana] brackets and contents, e.g., 暑[あつ]い -> 暑いい
        text.replacingOccurrences(of: "\\[[^\\]]+\\]", with: "", options: .regularExpression)
    }
}

struct FuriganaText: View {
    let text: String
    // Regex to match kanji with furigana in brackets, e.g., 暑[あつ]い
    private let pattern = "([^\\[]+)\\[([^\\]]+)\\]|([^\\[]+)"

    var body: some View {
        FlowLayout(spacing: 2) {
            ForEach(parseSegments(), id: \.self) { segment in
                if let ruby = parseRuby(segment) {
                    VStack(spacing: 0) {
                        Text(ruby.reading)
                            .font(.caption)
                        Text(ruby.kanji)
                    }
                } else {
                    Text(segment)
                }
            }
        }
    }

    private func parseSegments() -> [String] {
        var segments: [String] = []
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsString = text as NSString
        let matches = regex?.matches(in: text, range: NSRange(location: 0, length: nsString.length)) ?? []

        var lastEnd = 0
        for match in matches {
            if match.range.location > lastEnd {
                let prefix = nsString.substring(with: NSRange(location: lastEnd, length: match.range.location - lastEnd))
                if !prefix.isEmpty { segments.append(prefix) }
            }
            let fullMatch = nsString.substring(with: match.range)
            segments.append(fullMatch)
            lastEnd = match.range.location + match.range.length
        }

        if lastEnd < nsString.length {
            let suffix = nsString.substring(from: lastEnd)
            if !suffix.isEmpty { segments.append(suffix) }
        }

        return segments
    }

    private func parseRuby(_ segment: String) -> (kanji: String, reading: String)? {
        guard segment.contains("["), segment.contains("]") else { return nil }
        let parts = segment.split(separator: "[")
        guard parts.count == 2,
              let readingEnd = parts[1].range(of: "]") else { return nil }
        let kanji = String(parts[0])
        let reading = String(parts[1][..<readingEnd.lowerBound])
        return (kanji, reading)
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
                self.size.width = max(self.size.width, x)
            }

            self.size.height = y + lineHeight
        }
    }
}

struct HTMLText: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isEditable = false
        textView.isScrollEnabled = false
        textView.backgroundColor = .clear
        textView.dataDetectorTypes = []
        textView.textColor = .label
        return textView
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        if let data = html.data(using: .utf8) {
            do {
                let attributedString = try NSAttributedString(
                    data: data,
                    options: [
                        .documentType: NSAttributedString.DocumentType.html,
                        .characterEncoding: String.Encoding.utf8.rawValue
                    ],
                    documentAttributes: nil
                )
                let mutable = NSMutableAttributedString(attributedString: attributedString)
                mutable.addAttribute(.foregroundColor, value: UIColor.label, range: NSRange(location: 0, length: mutable.length))
                uiView.attributedText = mutable
            } catch {
                uiView.text = html
                uiView.textColor = .label
            }
        }
    }
}