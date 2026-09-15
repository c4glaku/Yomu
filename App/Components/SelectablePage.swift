import SwiftUI
import NaturalLanguage

struct SelectablePage: UIViewRepresentable {
    var text: String
    var pageID: Int
    var fontSize: CGFloat
    var highlights: [String]
    var fraction: Double
    var isPlaying: Bool
    var onSelection: (String) -> Void
    var onLookup: (String) -> Void
    var onHighlight: (String) -> Void
    var onManualScroll: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.isEditable = false
        view.isSelectable = true
        view.textContainerInset = UIEdgeInsets(top: 15, left: 0, bottom: 60, right: 0)
        view.textContainer.lineFragmentPadding = 0
        view.showsVerticalScrollIndicator = false
        view.adjustsFontForContentSizeCategory = true
        view.delegate = context.coordinator
        view.accessibilityLabel = "Book page. Select text to look up a word or highlight a passage."
        return view
    }
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        let signature = "\(pageID)-\(fontSize)-\(highlights.joined(separator: "|"))-\(view.traitCollection.userInterfaceStyle.rawValue)"
        if context.coordinator.signature != signature {
            let changedPage = context.coordinator.pageID != pageID
            context.coordinator.updating = true
            let selection = view.selectedRange
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = fontSize * 0.65
            paragraph.paragraphSpacing = fontSize * 0.4
            let font = UIFont(name: "HiraginoMinchoProN-W3", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize)
            let attributed = NSMutableAttributedString(string: text, attributes: [
                .font: UIFontMetrics(forTextStyle: .body).scaledFont(for: font),
                .foregroundColor: UIColor.label, .paragraphStyle: paragraph
            ])
            let nsText = text as NSString
            for word in highlights where !word.isEmpty {
                var range = NSRange(location: 0, length: nsText.length)
                while range.length > 0 {
                    let match = nsText.range(of: word, range: range)
                    if match.location == NSNotFound { break }
                    attributed.addAttribute(.backgroundColor, value: UIColor(Theme.orange).withAlphaComponent(0.22), range: match)
                    let next = match.location + match.length
                    range = NSRange(location: next, length: nsText.length - next)
                }
            }
            view.attributedText = attributed
            if changedPage { view.selectedRange = NSRange(location: 0, length: 0); view.setContentOffset(.zero, animated: false) }
            else if NSMaxRange(selection) <= attributed.length { view.selectedRange = selection }
            context.coordinator.signature = signature
            context.coordinator.pageID = pageID
            context.coordinator.updating = false
        }
        if isPlaying && !view.isDragging && !view.isDecelerating {
            let maxOffset = max(0, view.contentSize.height - view.bounds.height)
            view.setContentOffset(CGPoint(x: 0, y: maxOffset * fraction), animated: false)
        }
    }

    @MainActor final class Coordinator: NSObject, UITextViewDelegate {
        var parent: SelectablePage
        var signature = ""
        var pageID = -1
        var updating = false
        init(_ parent: SelectablePage) { self.parent = parent }
        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !updating else { return }
            let range = textView.selectedRange
            let text = textView.text as NSString
            guard range.length > 0, NSMaxRange(range) <= text.length else { parent.onSelection(""); return }
            parent.onSelection(text.substring(with: range))
        }
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) { parent.onManualScroll() }
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            guard NSMaxRange(range) <= (textView.text as NSString).length else { return nil }
            let selected = (textView.text as NSString).substring(with: range)
            let lookup = UIAction(title: "Look up in Yomu", image: UIImage(systemName: "character.book.closed")) { [weak self] _ in self?.parent.onLookup(selected) }
            let highlight = UIAction(title: "Highlight", image: UIImage(systemName: "highlighter")) { [weak self] _ in self?.parent.onHighlight(selected) }
            return UIMenu(children: [lookup, highlight] + suggestedActions)
        }
    }
}
