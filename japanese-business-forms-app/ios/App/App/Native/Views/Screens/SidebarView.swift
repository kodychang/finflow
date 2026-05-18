import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: DocumentStore
    @Binding var selectedSection: AppSection

    private let columns = [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 12) {
                    AppBrandHeader()
                    Text("帳票作成・管理")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.white.opacity(0.72))
                }
                .padding(.bottom, 16)
                .overlay(Rectangle().fill(Color.white.opacity(0.14)).frame(height: 1), alignment: .bottom)

                VStack(alignment: .leading, spacing: 10) {
                    sidebarTitle("帳票種類")
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(DocumentType.allCases) { type in
                            Button {
                                store.newDocument(type: type)
                                selectedSection = .form
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(type.title)
                                        .font(.subheadline.weight(.black))
                                    Text(type.subtitle)
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(store.current.type == type ? .appInk.opacity(0.68) : Color.white.opacity(0.66))
                                }
                                .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
                                .padding(10)
                                .background(store.current.type == type ? Color.appAccent : Color.appSidebarCard)
                                .foregroundColor(store.current.type == type ? .appInk : .white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.14)))
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        sidebarTitle("最近の帳票")
                        Spacer()
                        Button("保存") {
                            store.saveCurrent()
                        }
                        .font(.caption.weight(.black))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.appAccent)
                        .foregroundColor(.appInk)
                        .cornerRadius(8)
                    }

                    if store.documents.isEmpty {
                        Text("保存済みなし")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color.white.opacity(0.62))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(Color.appSidebarCard)
                            .cornerRadius(10)
                    } else {
                        ForEach(store.documents.prefix(12)) { document in
                            Button {
                                store.select(document)
                                selectedSection = .form
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(document.type.title) \(document.number)")
                                        .font(.caption.weight(.black))
                                    Text(document.customerName.isEmpty ? "取引先未入力" : document.customerName)
                                        .font(.caption2.weight(.bold))
                                        .foregroundColor(Color.white.opacity(0.62))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color.appSidebarCard)
                                .cornerRadius(10)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .foregroundColor(.white)
                        }
                    }
                }
            }
            .padding(24)
        }
        .background(Color.appSidebar.edgesIgnoringSafeArea(.all))
    }

    private func sidebarTitle(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.black))
            .foregroundColor(Color.white.opacity(0.68))
    }
}
