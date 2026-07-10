import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct AppBrandHeader: View {
    var compact = false

    var body: some View {
        HStack(spacing: 12) {
            Image("AppLogo")
                .resizable()
                .scaledToFill()
                .frame(width: compact ? 30 : 44, height: compact ? 30 : 44)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 6 : 8, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Shoko Forms")
                    .font(compact ? AppFont.cardTitle(.semibold) : AppFont.pageTitle(.semibold))
                    .foregroundColor(.appInk)
                Text("日本商業帳票作成")
                    .font(AppFont.secondary(.semibold))
                    .foregroundColor(.appMuted)
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    var titleWeight: Font.Weight = .black
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppBackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.headline.weight(.semibold))
                .foregroundColor(.appInk)
                .frame(width: 42, height: 42)
                .background(Color.appInputBackground)
                .clipShape(Circle())
                .overlay(Circle().stroke(Color.appDivider, lineWidth: 1))
                .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel(Text(title))
    }
}

struct FolderPicker: UIViewControllerRepresentable {
    let onPick: (URL) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        controller.allowsMultipleSelection = false
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

struct FormField<Content: View>: View {
    let title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppFont.secondary(.semibold))
                .foregroundColor(.appMuted)
                .lineLimit(1)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct MultilineTextInput: UIViewRepresentable {
    @Binding var text: String
    var minHeight: CGFloat = 104

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.backgroundColor = UIColor(Color.appInputBackground)
        textView.textColor = UIColor(Color.appInk)
        textView.tintColor = UIColor(Color.appAccent)
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10)
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
    var showsClearButton: Bool = false
    var onClear: () -> Void = {}
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
            HStack(spacing: 8) {
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

                if showsClearButton && !text.isEmpty {
                    Button {
                        text = ""
                        onClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.body.weight(.semibold))
                            .foregroundColor(.appMuted)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .accessibilityLabel(Text("Clear"))
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .flatFormInput()

            if isEditing && (!suggestions.isEmpty || (!cleanText.isEmpty && !hasExactSuggestion)) {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(suggestions) { suggestion in
                            Button {
                                text = title(suggestion)
                                onSelect(suggestion)
                                isEditing = false
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(title(suggestion))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.appInk)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)
                                    if !subtitle(suggestion).isEmpty {
                                        Text(subtitle(suggestion))
                                            .font(.caption.weight(.semibold))
                                            .foregroundColor(.appMuted)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
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
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .frame(maxHeight: 320)
                .background(Color.appPanel)
                .overlay(Rectangle().fill(Color.appDivider).frame(height: 1), alignment: .bottom)
                .padding(.top, 6)
            }
        }
    }
}

private struct FlatInputSurface: ViewModifier {
    var minHeight: CGFloat = 48

    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.appInk)
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: minHeight, alignment: .leading)
            .background(Color.appInputBackground)
            .cornerRadius(8)
            .inputInnerShadow(cornerRadius: 8)
    }
}

private struct MultilineInputSurface: ViewModifier {
    var minHeight: CGFloat = 104

    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.appInk)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
            .background(Color.appInputBackground)
            .cornerRadius(8)
            .inputInnerShadow(cornerRadius: 8)
    }
}

private struct PillInputSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .foregroundColor(.appInk)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .background(Color.appInputBackground)
            .cornerRadius(8)
            .inputInnerShadow(cornerRadius: 8)
    }
}

private struct InputInnerShadow: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content.overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.gray.opacity(0.42), lineWidth: 3)
                .blur(radius: 3)
                .mask(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color.black)
                )
        )
    }
}

extension Text {
    static func inputPrompt(_ value: String) -> Text {
        Text(value).foregroundColor(.appMuted.opacity(0.72))
    }
}

extension View {
    func flatFormInput(minHeight: CGFloat = 48) -> some View {
        modifier(FlatInputSurface(minHeight: minHeight))
    }

    func multilineFormInput(minHeight: CGFloat = 104) -> some View {
        modifier(MultilineInputSurface(minHeight: minHeight))
    }

    func pillFormInput() -> some View {
        modifier(PillInputSurface())
    }

    fileprivate func inputInnerShadow(cornerRadius: CGFloat) -> some View {
        modifier(InputInnerShadow(cornerRadius: cornerRadius))
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
