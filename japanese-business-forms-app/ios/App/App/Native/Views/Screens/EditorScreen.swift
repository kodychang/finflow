import SwiftUI
import UIKit

struct EditorScreen: View {
    @ObservedObject var store: DocumentStore
    @Environment(\.appButtonAccent) private var buttonAccent
    @State private var saveStatus = "草稿自動保存中"
    @State private var didSave = false
    @State private var expandedSection: EditorFormSection = .basic

    private let fieldSpacing: CGFloat = 18
    private let columnSpacing: CGFloat = 24

    init(store: DocumentStore) {
        self.store = store
        UITextView.appearance().backgroundColor = .clear
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                EditorCollapsibleSection(section: .basic, title: "基本情報", expandedSection: $expandedSection) {
                    VStack(spacing: fieldSpacing) {
                        twoColumnRow {
                            FormField(title: "帳票番号") {
                                TextField("", text: $store.current.number, prompt: .inputPrompt("帳票番号"))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .flatFormInput()
                            }
                        } right: {
                            FormField(title: "発行日") {
                                DatePicker("", selection: $store.current.issueDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .pillFormInput()
                            }
                        }
                        twoColumnRow {
                            FormField(title: "取引年月日") {
                                DatePicker("", selection: $store.current.transactionDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .pillFormInput()
                            }
                        } right: {
                            FormField(title: "支払期限 / 納期") {
                                DatePicker("", selection: $store.current.dueDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .datePickerStyle(CompactDatePickerStyle())
                                    .pillFormInput()
                            }
                        }
                        twoColumnRow {
                            FormField(title: "関連番号") {
                                TextField("", text: $store.current.relatedNumber, prompt: .inputPrompt("関連番号"))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .flatFormInput()
                            }
                        } right: {
                            FormField(title: "敬称") {
                                Picker("敬称", selection: $store.current.honorific) {
                                    Text("御中").tag("御中")
                                    Text("様").tag("様")
                                    Text("なし").tag("")
                                }
                                .pickerStyle(SegmentedPickerStyle())
                                .pillFormInput()
                            }
                        }
                        FormField(title: "税(%)") {
                            TextField("", value: $store.current.taxRate, formatter: NumberFormatter.decimal, prompt: .inputPrompt("税率"))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    }
                }

                EditorCollapsibleSection(section: .customer, title: "取引先", expandedSection: $expandedSection) {
                    VStack(spacing: fieldSpacing) {
                        FormField(title: "会社名 / 氏名") {
                            AutocompleteTextField(
                                placeholder: "株式会社サンプル",
                                text: $store.current.customerName,
                                suggestions: store.customerSuggestions(for: store.current.customerName),
                                title: { $0.name },
                                subtitle: { [$0.contact, $0.address].filter { !$0.isEmpty }.joined(separator: " / ") },
                                onCommit: { store.rememberCustomerFromCurrent() },
                                onSelect: { store.apply($0) }
                            )
                        }
                        FormField(title: "担当者") {
                            TextField("", text: $store.current.customerContact, prompt: .inputPrompt("経理部 山田"))
                                .onSubmit(store.rememberCustomerFromCurrent)
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    }
                }

                EditorCollapsibleSection(section: .customerAddress, title: "取引先住所", expandedSection: $expandedSection) {
                    FormField(title: "住所") {
                        MultilineTextInput(text: $store.current.customerAddress)
                            .multilineFormInput(minHeight: 96)
                    }
                }

                EditorCollapsibleSection(section: .issuer, title: "発行者", expandedSection: $expandedSection) {
                    VStack(spacing: fieldSpacing) {
                        FormField(title: "自社名") {
                            AutocompleteTextField(
                                placeholder: "自社名",
                                text: $store.current.issuerName,
                                suggestions: store.issuerSuggestions(for: store.current.issuerName),
                                title: { $0.name },
                                subtitle: { [$0.registration, $0.phone, $0.email].filter { !$0.isEmpty }.joined(separator: " / ") },
                                onCommit: { store.rememberIssuerFromCurrent() },
                                onSelect: { store.apply($0) }
                            )
                        }
                        twoColumnRow {
                            FormField(title: "登録番号") {
                                TextField("", text: $store.current.issuerRegistration, prompt: .inputPrompt("T1234567890123"))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .flatFormInput()
                            }
                        } right: {
                            FormField(title: "連絡人") {
                                TextField("", text: $store.current.issuerContact, prompt: .inputPrompt("担当者"))
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .flatFormInput()
                            }
                        }
                        twoColumnRow {
                            FormField(title: "電話") {
                                TextField("", text: $store.current.issuerPhone, prompt: .inputPrompt("電話"))
                                    .keyboardType(.phonePad)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .flatFormInput()
                            }
                        } right: {
                            FormField(title: "メール") {
                                TextField("", text: $store.current.issuerEmail, prompt: .inputPrompt("メール"))
                                    .keyboardType(.emailAddress)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .flatFormInput()
                            }
                        }
                    }
                }

                EditorCollapsibleSection(section: .issuerAddress, title: "発行者住所", expandedSection: $expandedSection) {
                    FormField(title: "自社住所") {
                        MultilineTextInput(text: $store.current.issuerAddress)
                            .multilineFormInput(minHeight: 96)
                    }
                }

                EditorCollapsibleSection(section: .lines, title: "明細", expandedSection: $expandedSection) {
                    lineEditor
                }

                EditorCollapsibleSection(section: .notes, title: "備考", expandedSection: $expandedSection) {
                    VStack(spacing: 12) {
                        FormField(title: "備考") {
                            MultilineTextInput(text: $store.current.notes)
                                .multilineFormInput(minHeight: 82)
                        }
                        FormField(title: "振込先 / 確認状況") {
                            MultilineTextInput(text: $store.current.paymentDetails)
                                .multilineFormInput(minHeight: 82)
                        }
                        FormField(title: "帳票別メモ") {
                            MultilineTextInput(text: $store.current.documentMemo)
                                .multilineFormInput(minHeight: 82)
                        }
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 20)
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
        .dismissKeyboardOnTap()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                AppBrandHeader(compact: true)
                    .foregroundColor(.appInk)
                Text("Commercial document studio")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.appMuted)
                    .textCase(.uppercase)
                Text(store.current.type.pageTitle)
                    .font(.title3.weight(.semibold))
                Text(saveStatus)
                    .font(.caption.weight(.semibold))
                    .foregroundColor(didSave ? buttonAccent : .appMuted)
            }
            Spacer()
            Button {
                saveDocument()
            } label: {
                Label(didSave ? "保存済み" : "保存", systemImage: didSave ? "checkmark.seal.fill" : "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(buttonAccent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
    }

    private func saveDocument() {
        store.saveCurrent()
        didSave = true
        saveStatus = "保存が完了しました。"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            didSave = false
            saveStatus = "草稿自動保存中"
        }
    }

    private func twoColumnRow<Left: View, Right: View>(
        @ViewBuilder left: () -> Left,
        @ViewBuilder right: () -> Right
    ) -> some View {
        HStack(alignment: .top, spacing: columnSpacing) {
            left()
                .frame(maxWidth: .infinity, alignment: .leading)
            right()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var lineEditor: some View {
        VStack(spacing: 18) {
            ForEach($store.current.lines) { $line in
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("明細")
                            .font(.caption.weight(.black))
                            .foregroundColor(.appMuted)
                        Spacer()
                        Button {
                            store.removeLine(id: line.id)
                        } label: {
                            Image(systemName: "trash")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(.red)
                                .frame(width: 34, height: 34)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }

                    FormField(title: "品目") {
                        AutocompleteTextField(
                            placeholder: "品目",
                            text: $line.name,
                            suggestions: store.productSuggestions(for: line.name),
                            title: { $0.name },
                            subtitle: { [$0.model, $0.specification, AppFormatters.yen($0.unitPrice)].filter { !$0.isEmpty }.joined(separator: " / ") },
                            onCommit: { store.rememberProduct(line) },
                            onSelect: { product in
                                line.name = product.name
                                line.model = product.model
                                line.specification = product.specification
                                line.unitPrice = product.unitPrice
                            }
                        )
                    }
                    FormField(title: "仕様") {
                        TextField("", text: $line.specification, prompt: .inputPrompt("仕様"))
                            .textFieldStyle(PlainTextFieldStyle())
                            .flatFormInput()
                    }
                    twoColumnRow {
                        FormField(title: "型番") {
                            TextField("", text: $line.model, prompt: .inputPrompt("型番"))
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    } right: {
                        FormField(title: "数量") {
                            TextField("", value: $line.quantity, formatter: NumberFormatter.decimal, prompt: .inputPrompt("数量"))
                                .keyboardType(.decimalPad)
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    }
                    twoColumnRow {
                        FormField(title: "単価") {
                            TextField("", value: $line.unitPrice, formatter: NumberFormatter.decimal, prompt: .inputPrompt("単価"))
                                .keyboardType(.numberPad)
                                .textFieldStyle(PlainTextFieldStyle())
                                .flatFormInput()
                        }
                    } right: {
                        FormField(title: "金額") {
                            Text(AppFormatters.yen(line.amount))
                                .font(.body.weight(.semibold))
                                .foregroundColor(.appInk)
                                .flatFormInput()
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Button {
                store.addLine()
            } label: {
                Label("行を追加", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(buttonAccent)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
        }
    }
}

enum EditorFormSection: Hashable {
    case basic
    case customer
    case customerAddress
    case issuer
    case issuerAddress
    case lines
    case notes
}

private struct EditorCollapsibleSection<Content: View>: View {
    let section: EditorFormSection
    let title: String
    @Binding var expandedSection: EditorFormSection
    @ViewBuilder var content: Content

    private var isExpanded: Bool {
        expandedSection == section
    }

    var body: some View {
        VStack(alignment: .leading, spacing: isExpanded ? 14 : 0) {
            HStack(spacing: 10) {
                Text(title)
                    .font(.title3.weight(.black))
                    .foregroundColor(.appInk)
                Spacer()
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption.weight(.black))
                    .foregroundColor(buttonAccent)
                    .frame(width: 28, height: 28)
                    .background(buttonAccent.opacity(0.12))
                    .clipShape(Circle())
            }

            if isExpanded {
                content
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.appPanel)
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(isExpanded ? Color.appAccent.opacity(0.45) : Color.appDivider))
        .contentShape(Rectangle())
        .onTapGesture {
            guard !isExpanded else { return }
            withAnimation(.easeInOut(duration: 0.18)) {
                expandedSection = section
            }
        }
    }
}

extension NumberFormatter {
    static let decimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter
    }()
}
