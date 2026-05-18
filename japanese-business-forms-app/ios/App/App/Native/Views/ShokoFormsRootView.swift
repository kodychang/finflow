import SwiftUI

struct ShokoFormsRootView: View {
    @StateObject private var store = DocumentStore()
    @State private var selectedSection: AppSection = .menu

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width >= 900 {
                HStack(spacing: 0) {
                    SidebarView(store: store, selectedSection: $selectedSection)
                        .frame(width: 304)
                    EditorScreen(store: store)
                        .frame(minWidth: 430, maxWidth: .infinity)
                    PreviewScreen(document: store.current)
                        .frame(minWidth: 430, maxWidth: .infinity)
                }
                .background(Color.appBackground.edgesIgnoringSafeArea(.all))
            } else {
                TabView(selection: $selectedSection) {
                    SidebarView(store: store, selectedSection: $selectedSection)
                        .tabItem { Label("菜單", systemImage: "square.grid.2x2") }
                        .tag(AppSection.menu)
                    EditorScreen(store: store)
                        .tabItem { Label("表單", systemImage: "doc.text") }
                        .tag(AppSection.form)
                    PreviewScreen(document: store.current)
                        .tabItem { Label("確認", systemImage: "doc.richtext") }
                        .tag(AppSection.preview)
                }
                .accentColor(.appInk)
            }
        }
    }
}

enum AppSection {
    case menu
    case form
    case preview
}
