import SwiftUI
import SwiftData

struct CategoryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Bindable var category: Category

    @State private var showAddSubCategory = false
    @State private var selectedSubCategory: SubCategory?
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        List {
            Section {
                HStack {
                    CategoryIconView(
                        iconName: category.iconName,
                        colorHex: category.colorHex,
                        size: 56
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name)
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(category.type == .expense ? "Expense" : "Income")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .padding(.vertical, 8)
            }

            Section {
                if let subCategories = category.subCategories, !subCategories.isEmpty {
                    ForEach(subCategories.sorted { $0.sortOrder < $1.sortOrder }) { subCategory in
                        SubCategoryRow(subCategory: subCategory)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedSubCategory = subCategory
                            }
                    }
                    .onDelete(perform: deleteSubCategories)
                } else {
                    Text("No subcategories")
                        .foregroundStyle(.secondary)
                }

                Button {
                    showAddSubCategory = true
                } label: {
                    Label("Add Subcategory", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Subcategories")
            } footer: {
                Text("Subcategories help you track spending in more detail within this category.")
            }

            if !category.isDefault {
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Category")
                            Spacer()
                        }
                    }
                }
            }
        }
        .navigationTitle("Category")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showAddSubCategory) {
            SubCategoryFormView(parentCategory: category, subCategory: nil)
        }
        .sheet(item: $selectedSubCategory) { subCategory in
            SubCategoryFormView(parentCategory: category, subCategory: subCategory)
        }
        .confirmationDialog("Delete Category", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                deleteCategory()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete this category? All subcategories will also be deleted. Transactions will keep their data but won't be linked to this category.")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }

    private func deleteSubCategories(at offsets: IndexSet) {
        guard let subCategories = category.subCategories?.sorted(by: { $0.sortOrder < $1.sortOrder }) else { return }

        for index in offsets {
            let subCategory = subCategories[index]
            modelContext.delete(subCategory)
        }

        do {
            try modelContext.save()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteCategory() {
        category.isArchived = true

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

struct SubCategoryRow: View {
    let subCategory: SubCategory

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: subCategory.iconName)
                .font(.body)
                .foregroundStyle(Color(hex: subCategory.colorHex) ?? .blue)
                .frame(width: 28, height: 28)
                .background(Color(hex: subCategory.colorHex)?.opacity(0.15) ?? Color.blue.opacity(0.15))
                .cornerRadius(6)

            Text(subCategory.name)
                .font(.body)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }
}

#Preview {
    let container = try! ModelContainerSetup.createPreviewContainer()
    let category = Category(name: "Groceries", iconName: "cart.fill", colorHex: "#34C759", type: .expense)
    return NavigationStack {
        CategoryDetailView(category: category)
    }
    .modelContainer(container)
}
