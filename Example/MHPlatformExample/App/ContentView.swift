import SwiftUI

struct ContentView: View {
    private enum Constants {
        static let macMinimumWidth = 900.0
        static let macMinimumHeight = 640.0
    }

    var body: some View {
        content
    }

    @ViewBuilder private var content: some View {
        #if os(macOS)
        tabs
            .frame(
                minWidth: Constants.macMinimumWidth,
                minHeight: Constants.macMinimumHeight
            )
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
