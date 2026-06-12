import SwiftUI

struct ContentView: View {
    var body: some View {
        content
    }

    @ViewBuilder private var content: some View {
        #if os(macOS)
        tabs
            // swiftlint:disable:next no_magic_numbers
            .frame(minWidth: 900, minHeight: 640)
        #else
        tabs
        #endif
    }

    private var tabs: some View {
        TabView {
            ForEach(DemoCategory.allCases) { category in
                Tab(category.title, systemImage: category.systemImage) {
                    DemoCategoryView(
                        title: category.title,
                        demos: category.demos
                    )
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
