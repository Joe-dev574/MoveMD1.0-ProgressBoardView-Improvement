//
//  CategoryPickerView.swift
//  MoveMD1.0
//
//  Created by Joseph DeWeese on 4/29/25.
//
import SwiftUI
import SwiftData
import UserNotifications

struct CategoryPicker: View {
    @Binding var selectedCategory: Category?
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Category.categoryName, order: .forward) private var categories: [Category]
    
    // Define grid columns (adaptive for dynamic width)
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: 12)
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, alignment: .center, spacing: 12) {
                    ForEach(categories) { category in
                        categoryCell(category)
                            .onTapGesture {
                                selectedCategory = category
                                dismiss()
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Select a Category")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func categoryCell(_ category: Category) -> some View {
        VStack(spacing: 8) {
            Image(systemName: category.symbol)
                .font(.title2)
                .foregroundColor(category.categoryColor.color)
                .frame(width: 40, height: 40)
            Text(category.categoryName)
                .font(.subheadline)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(category.categoryColor.color.opacity(0.3), lineWidth: 1)
        )
    }
}
