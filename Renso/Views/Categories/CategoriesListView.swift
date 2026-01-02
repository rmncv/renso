import SwiftUI
import SwiftData

struct CategoriesListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: CategoriesViewModel?
    @State private var showAddCategory = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                List {
                    Section("Expense Categories") {
                        ForEach(viewModel.expenseCategories) { category in
                            NavigationLink {
                                CategoryDetailView(category: category)
                                    .onDisappear {
                                        viewModel.loadCategories()
                                    }
                            } label: {
                                CategoryRow(category: category)
                            }
                        }
                    }

                    Section("Income Categories") {
                        ForEach(viewModel.incomeCategories) { category in
                            NavigationLink {
                                CategoryDetailView(category: category)
                                    .onDisappear {
                                        viewModel.loadCategories()
                                    }
                            } label: {
                                CategoryRow(category: category)
                            }
                        }
                    }
                }
                .navigationTitle("Categories")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddCategory = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddCategory) {
                    AddCategoryView()
                        .onDisappear {
                            viewModel.loadCategories()
                        }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CategoriesViewModel(modelContext: modelContext)
            }
        }
    }
}

struct CategoryRow: View {
    let category: Category

    var body: some View {
        HStack {
            CategoryIconView(
                iconName: category.iconName,
                colorHex: category.colorHex,
                size: 32
            )

            Text(category.name)
                .font(.body)

            Spacer()

            if let subCategories = category.subCategories, !subCategories.isEmpty {
                Text("\(subCategories.count) sub")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct AddCategoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var type: CategoryType = .expense
    @State private var selectedIcon: String = "tag"
    @State private var selectedColor: String = "#007AFF"

    @State private var showError = false
    @State private var errorMessage = ""

    let availableIcons = [
        "cart.fill", "fork.knife", "car.fill", "house.fill",
        "heart.fill", "bolt.fill", "book.fill", "airplane",
        "gift.fill", "briefcase.fill", "tag.fill", "star.fill"
    ]

    let availableColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#5856D6", "#AF52DE", "#FF2D55", "#00C7BE"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Category Name", text: $name)

                    Picker("Type", selection: $type) {
                        Text("Expense").tag(CategoryType.expense)
                        Text("Income").tag(CategoryType.income)
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Basic Info")
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(availableIcons, id: \.self) { icon in
                                Image(systemName: icon)
                                    .font(.title2)
                                    .foregroundStyle(selectedIcon == icon ? .primary : .secondary)
                                    .frame(width: 44, height: 44)
                                    .background(selectedIcon == icon ? Color.gray.opacity(0.2) : Color.clear)
                                    .cornerRadius(8)
                                    .onTapGesture {
                                        selectedIcon = icon
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Icon")
                }

                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(availableColors, id: \.self) { color in
                                Circle()
                                    .fill(Color(hex: color) ?? .blue)
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Circle()
                                            .stroke(Color.primary, lineWidth: selectedColor == color ? 3 : 0)
                                    )
                                    .onTapGesture {
                                        selectedColor = color
                                    }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Color")
                }

                Section {
                    HStack {
                        Text("Preview")
                        Spacer()
                        CategoryIconView(
                            iconName: selectedIcon,
                            colorHex: selectedColor,
                            size: 44
                        )
                        Text(name.isEmpty ? "Category Name" : name)
                    }
                }
            }
            .navigationTitle("New Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func saveCategory() {
        let category = Category(
            name: name,
            iconName: selectedIcon,
            colorHex: selectedColor,
            type: type
        )

        modelContext.insert(category)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        CategoriesListView()
    }
    .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}
