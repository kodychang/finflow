import SwiftUI

struct EditorScreen: View {
    @ObservedObject var store: DocumentStore

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                SectionCard(title: "基本情報") {
                    LazyVGrid(columns: columns, spacing: 14) {
                        FormField(title: "帳票番号") {
                            TextField("帳票番号", text: $store.current.number)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        FormField(title: "発行日") {
                            DatePicker("", selection: $store.current.issueDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        FormField(title: "取引年月日") {
                            DatePicker("", selection: $store.current.transactionDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        FormField(title: "支払期限 / 納期") {
                            DatePicker("", selection: $store.current.dueDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        FormField(title: "関連番号") {
                            TextField("関連番号", text: $store.current.relatedNumber)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        FormField(title: "敬称") {
                            Picker("敬称", selection: $store.current.honorific) {
                                Text("御中").tag("御中")
                                Text("様").tag("様")
                                Text("なし").tag("")
                            }
                            .pickerStyle(SegmentedPickerStyle())
                        }
                        FormField(title: "税(%)") {
                            TextField("税率", value: $store.current.taxRate, formatter: NumberFormatter.decimal)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }

                SectionCard(title: "取引先") {
                    LazyVGrid(columns: columns, spacing: 14) {
                        FormField(title: "会社名 / 氏名") {
                            TextField("株式会社サンプル", text: $store.current.customerName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        FormField(title: "担当者") {
                            TextField("経理部 山田", text: $store.current.customerContact)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        FormField(title: "住所") {
                            TextEditor(text: $store.current.customerAddress)
                                .frame(minHeight: 76)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))
                        }
                    }
                }

                SectionCard(title: "発行者") {
                    LazyVGrid(columns: columns, spacing: 14) {
                        FormField(title: "自社名") {
                            TextField("自社名", text: $store.current.issuerName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        FormField(title: "登録番号") {
                            TextField("T1234567890123", text: $store.current.issuerRegistration)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        FormField(title: "連絡人") {
                            TextField("担当者", text: $store.current.issuerContact)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        FormField(title: "電話") {
                            TextField("電話", text: $store.current.issuerPhone)
                                .keyboardType(.phonePad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        FormField(title: "メール") {
                            TextField("メール", text: $store.current.issuerEmail)
                                .keyboardType(.emailAddress)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        FormField(title: "自社住所") {
                            TextEditor(text: $store.current.issuerAddress)
                                .frame(minHeight: 76)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))
                        }
                    }
                }

                SectionCard(title: "明細") {
                    lineEditor
                }

                SectionCard(title: "備考") {
                    VStack(spacing: 12) {
                        FormField(title: "備考") {
                            TextEditor(text: $store.current.notes)
                                .frame(minHeight: 82)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))
                        }
                        FormField(title: "振込先 / 確認状況") {
                            TextEditor(text: $store.current.paymentDetails)
                                .frame(minHeight: 82)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))
                        }
                        FormField(title: "帳票別メモ") {
                            TextEditor(text: $store.current.documentMemo)
                                .frame(minHeight: 82)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black.opacity(0.12)))
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color.appBackground.edgesIgnoringSafeArea(.all))
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                AppBrandHeader(compact: true)
                    .foregroundColor(.appInk)
                Text("Commercial document studio")
                    .font(.caption.weight(.black))
                    .foregroundColor(.appMuted)
                    .textCase(.uppercase)
                Text(store.current.type.pageTitle)
                    .font(.largeTitle.weight(.black))
            }
            Spacer()
            Button {
                store.saveCurrent()
            } label: {
                Label("保存", systemImage: "checkmark.circle.fill")
                    .font(.headline.weight(.black))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color.appAccent)
                    .foregroundColor(.appInk)
                    .cornerRadius(12)
            }
        }
    }

    private var lineEditor: some View {
        VStack(spacing: 12) {
            ForEach($store.current.lines) { $line in
                VStack(spacing: 10) {
                    LazyVGrid(columns: columns, spacing: 10) {
                        TextField("品目", text: $line.name)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("型番", text: $line.model)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("仕様", text: $line.specification)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("数量", value: $line.quantity, formatter: NumberFormatter.decimal)
                            .keyboardType(.decimalPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        TextField("単価", value: $line.unitPrice, formatter: NumberFormatter.decimal)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Text(AppFormatters.yen(line.amount))
                            .font(.subheadline.weight(.black))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
                .padding(12)
                .background(Color.black.opacity(0.035))
                .cornerRadius(10)
            }

            Button {
                store.addLine()
            } label: {
                Label("行を追加", systemImage: "plus")
                    .font(.subheadline.weight(.black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.black.opacity(0.12)))
                    .cornerRadius(10)
            }
            .foregroundColor(.appInk)
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
