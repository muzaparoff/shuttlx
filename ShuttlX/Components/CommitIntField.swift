import SwiftUI
import ShuttlXShared

/// Whole-number text field that commits only when editing ends (return key, Done button, focus lost, leaving
/// the screen), never per keystroke. The text is checked by `HeartLimits.commit`: out-of-range numbers are
/// clamped and say so in `hint`; text that is not a number reverts to the old value and says so.
/// `onCommit` gets nil when the field was cleared; it is called only when the value really changed.
struct CommitIntField: View {
    let placeholder: String
    let value: Int?
    let range: ClosedRange<Int>
    let unit: String
    @Binding var hint: String?
    var onFocus: () -> Void = {}
    var onCommit: (Int?) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField(placeholder, text: $text)
            .keyboardType(.numberPad)
            .focused($focused)
            .submitLabel(.done)
            .onSubmit(commit)
            .onAppear { text = value.map(String.init) ?? "" }
            .onChange(of: value) { _, v in if !focused { text = v.map(String.init) ?? "" } }
            .onChange(of: focused) { _, isFocused in
                if isFocused { hint = nil; onFocus() } else { commit() }
            }
            .onDisappear { commit() }   // focus may already be gone when the screen closes; commit() ignores an unchanged value
    }

    private func commit() {
        switch HeartLimits.commit(text, range: range) {
        case .cleared:
            text = ""
            if value != nil { onCommit(nil) }
        case let .set(v, clamped):
            text = String(v)
            hint = clamped ? "Changed to \(v) \(unit). Allowed: \(range.lowerBound) to \(range.upperBound) \(unit)." : nil
            if v != value { onCommit(v) }
        case .rejected:
            text = value.map(String.init) ?? ""
            hint = "Not changed. Enter a whole number from \(range.lowerBound) to \(range.upperBound) \(unit)."
        }
    }
}

/// The one-line message under a field after a clamp or a rejected entry.
struct FieldHint: View {
    let text: String?
    var body: some View {
        if let text {
            Text(text)
                .font(ShuttlXFont.cardCaption)
                .foregroundStyle(ShuttlXColor.ctaWarning)
                .accessibilityLabel("Notice: \(text)")
        }
    }
}
