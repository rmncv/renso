import SwiftUI
import SwiftData

struct SubCategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let parentCategory: Category
    let subCategory: SubCategory?

    @State private var name: String = ""
    @State private var selectedIcon: String = "tag"
    @State private var selectedColor: String = "#007AFF"
    @State private var showDeleteConfirmation = false
    @State private var showError = false
    @State private var errorMessage = ""

    private var isEditing: Bool { subCategory != nil }

    let availableIcons = [
        "tag.fill", "cart.fill", "fork.knife", "cup.and.saucer.fill",
        "car.fill", "fuelpump.fill", "bus.fill", "tram.fill",
        "house.fill", "lightbulb.fill", "drop.fill", "bolt.fill",
        "heart.fill", "cross.case.fill", "pills.fill", "bandage.fill",
        "book.fill", "graduationcap.fill", "pencil", "doc.fill",
        "gamecontroller.fill", "tv.fill", "film.fill", "music.note",
        "gift.fill", "bag.fill", "tshirt.fill", "shoe.fill",
        "airplane", "bed.double.fill", "fork.knife.circle.fill", "wineglass.fill",
        "creditcard.fill", "banknote.fill", "building.columns.fill", "phone.fill"
    ]

    let availableColors = [
        "#007AFF", "#34C759", "#FF9500", "#FF3B30",
        "#5856D6", "#AF52DE", "#FF2D55", "#00C7BE",
        "#5AC8FA", "#FFCC00", "#8E8E93", "#30B0C7"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Subcategory Name", text: $name)
                } header: {
                    Text("Name")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
                        ForEach(availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(selectedIcon == icon ? Color(hex: selectedColor) ?? .blue : .secondary)
                                .frame(width: 44, height: 44)
                                .background(selectedIcon == icon ? Color.gray.opacity(0.2) : Color.clear)
                                .cornerRadius(8)
                                .onTapGesture {
                                    selectedIcon = icon
                                }
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Icon")
                }

                Section {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 12) {
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
                    .padding(.vertical, 8)
                } header: {
                    Text("Color")
                }

                Section {
                    HStack {
                        Text("Preview")
                        Spacer()

                        HStack(spacing: 8) {
                            Image(systemName: selectedIcon)
                                .font(.body)
                                .foregroundStyle(Color(hex: selectedColor) ?? .blue)
                                .frame(width: 28, height: 28)
                                .background((Color(hex: selectedColor) ?? .blue).opacity(0.15))
                                .cornerRadius(6)

                            Text(name.isEmpty ? "Subcategory" : name)
                                .font(.body)
                        }
                    }
                }

                if isEditing {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Subcategory")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Subcategory" : "New Subcategory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveSubCategory()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .confirmationDialog("Delete Subcategory", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteSubCategory()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this subcategory?")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                if let subCategory = subCategory {
                    name = subCategory.name
                    selectedIcon = subCategory.iconName
                    selectedColor = subCategory.colorHex
                } else {
                    // Default to parent category's color
                    selectedColor = parentCategory.colorHex
                }
            }
        }
    }

    private func saveSubCategory() {
        if let subCategory = subCategory {
            // Edit mode
            subCategory.name = name
            subCategory.iconName = selectedIcon
            subCategory.colorHex = selectedColor
        } else {
            // Add mode
            let newSubCategory = SubCategory(
                name: name,
                iconName: selectedIcon,
                colorHex: selectedColor,
                parentCategory: parentCategory
            )

            // Set sort order
            let existingCount = parentCategory.subCategories?.count ?? 0
            newSubCategory.sortOrder = existingCount

            modelContext.insert(newSubCategory)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteSubCategory() {
        guard let subCategory = subCategory else { return }

        modelContext.delete(subCategory)

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview("Add") {
    let container = try! ModelContainerSetup.createPreviewContainer()
    let category = Category(name: "Groceries", iconName: "cart.fill", colorHex: "#34C759", type: .expense)
    return SubCategoryFormView(parentCategory: category, subCategory: nil)
        .modelContainer(container)
}

#Preview("Edit") {
    let container = try! ModelContainerSetup.createPreviewContainer()
    let category = Category(name: "Groceries", iconName: "cart.fill", colorHex: "#34C759", type: .expense)
    let subCategory = SubCategory(name: "Supermarket", iconName: "cart.fill", colorHex: "#34C759", parentCategory: category)
    return SubCategoryFormView(parentCategory: category, subCategory: subCategory)
        .modelContainer(container)
}
