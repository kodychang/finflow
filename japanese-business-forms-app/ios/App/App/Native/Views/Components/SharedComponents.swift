import SwiftUI
import UIKit

struct AppBrandHeader: View {
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            Text("商")
                .font(.headline.weight(.semibold))
                .foregroundColor(.white)
                .frame(width: compact ? 30 : 44, height: compact ? 30 : 44)
                .background(Color.appAccent)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text("Shoko Forms")
                    .font(compact ? .subheadline.weight(.semibold) : .headline.weight(.semibold))
                    .foregroundColor(.appInk)
                Text("日本商業帳票作成")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.appMuted)
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.title3.weight(.black))
                .foregroundColor(.appInk)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FormField<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.black))
                .foregroundColor(.appMuted)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MultilineTextInput: UIViewRepresentable {
    @Binding var text: String
    var minHeight: CGFloat = 82

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = UIColor(Color.appInputBackground)
        textView.textColor = UIColor(Color.appInk)
        textView.tintColor = UIColor(Color.appAccent)
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.textContainer.lineFragmentPadding = 0
        return textView
    }

    func updateUIView(_ textView: UITextView, context: Context) {
        if textView.text != text {
            textView.text = text
        }
        textView.backgroundColor = UIColor(Color.appInputBackground)
        textView.textColor = UIColor(Color.appInk)
        textView.tintColor = UIColor(Color.appAccent)
        textView.font = UIFont.preferredFont(forTextStyle: .body)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func textViewDidChange(_ textView: UITextView) {
            text = textView.text
        }
    }
}

struct AutocompleteTextField<Suggestion: Identifiable>: View {
    let placeholder: String
    @Binding var text: String
    let suggestions: [Suggestion]
    let title: (Suggestion) -> String
    var subtitle: (Suggestion) -> String = { _ in "" }
    var onCommit: () -> Void = {}
    let onSelect: (Suggestion) -> Void

    @State private var isEditing = false

    private var cleanText: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasExactSuggestion: Bool {
        suggestions.contains { title($0).caseInsensitiveCompare(cleanText) == .orderedSame }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text.inputPrompt(placeholder)
                }
                TextField(
                    "",
                    text: $text,
                    onEditingChanged: { editing in
                        isEditing = editing
                        if !editing {
                            onCommit()
                        }
                    },
                    onCommit: onCommit
                )
            }
            .textFieldStyle(PlainTextFieldStyle())
            .flatFormInput()

            if isEditing && (!suggestions.isEmpty || (!cleanText.isEmpty && !hasExactSuggestion)) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            text = title(suggestion)
                            onSelect(suggestion)
                            isEditing = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(title(suggestion))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundColor(.appInk)
                                if !subtitle(suggestion).isEmpty {
                                    Text(subtitle(suggestion))
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(.appMuted)
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(PlainButtonStyle())

                        Divider()
                    }

                    if !cleanText.isEmpty && !hasExactSuggestion {
                        Button {
                            onCommit()
                            isEditing = false
                        } label: {
                            Label("新規作成: \(cleanText)", systemImage: "plus.circle.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.appAccent)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .background(Color.appPanel)
                .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .bottom)
                .padding(.top, 6)
            }
        }
    }
}

private struct FlatInputSurface: ViewModifier {
    var minHeight: CGFloat = 50

    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.appInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(Color.appInputBackground)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
    }
}

private struct MultilineInputSurface: ViewModifier {
    var minHeight: CGFloat = 82

    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.appInk)
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(Color.appInputBackground)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
    }
}

private struct PillInputSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.appInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            .background(Color.appInputBackground)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appDivider))
    }
}

extension Text {
    static func inputPrompt(_ value: String) -> Text {
        Text(value).foregroundColor(.appMuted.opacity(0.72))
    }
}

extension View {
    func flatFormInput(minHeight: CGFloat = 50) -> some View {
        modifier(FlatInputSurface(minHeight: minHeight))
    }

    func multilineFormInput(minHeight: CGFloat = 82) -> some View {
        modifier(MultilineInputSurface(minHeight: minHeight))
    }

    func pillFormInput() -> some View {
        modifier(PillInputSurface())
    }

    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            UIApplication.shared.dismissKeyboard()
        }
    }
}

private extension UIApplication {
    func dismissKeyboard() {
        sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
