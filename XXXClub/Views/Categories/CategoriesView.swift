//
//  CategoriesView.swift
//  XXXClub
//

import SwiftUI

struct CategoriesView: View {
    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Site.categories.filter { $0.id != "all" }) { cat in
                        NavigationLink {
                            BrowseView(categoryID: cat.id)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: cat.icon)
                                    .font(.title3)
                                    .foregroundStyle(XCPalette.pink)
                                    .frame(width: 36)
                                Text(cat.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Spacer()
                            }
                            .padding(14)
                            .liquidGlassRect(cornerRadius: 16)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AdaptiveLayout.horizontalPadding)
            }
            .liquidGlassPage()
            .navigationTitle("类别")
        }
    }
}
