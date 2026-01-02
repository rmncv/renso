import SwiftUI
import SwiftData

struct RulesListView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: RulesViewModel?
    @State private var showAddRule = false

    var body: some View {
        Group {
            if let viewModel = viewModel {
                List {
                    if viewModel.rules.isEmpty {
                        EmptyStateView(
                            icon: "wand.and.stars",
                            title: "No Rules",
                            message: "Create auto-categorization rules to automatically organize your transactions"
                        )
                        .frame(height: 300)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(viewModel.rules) { rule in
                            RuleRow(rule: rule, viewModel: viewModel)
                        }
                    }
                }
                .navigationTitle("Rules")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showAddRule = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showAddRule) {
                    AddRuleView()
                        .onDisappear {
                            viewModel.loadRules()
                        }
                }
            } else {
                ProgressView()
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = RulesViewModel(modelContext: modelContext)
            }
        }
    }
}

struct RuleRow: View {
    let rule: Rule
    let viewModel: RulesViewModel

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(rule.name)
                    .font(.body)
                    .fontWeight(.medium)

                HStack(spacing: 4) {
                    Text(rule.ruleType.rawValue.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)

                    Text("→")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let category = rule.category {
                        HStack(spacing: 4) {
                            Image(systemName: category.iconName)
                            Text(category.name)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                Text(rule.matchValue)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { rule.isActive },
                set: { _ in viewModel.toggleRuleActive(rule) }
            ))
            .labelsHidden()
        }
    }
}

struct AddRuleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var ruleType: RuleType = .mcc
    @State private var matchValue: String = ""
    @State private var selectedCategory: Category?
    @State private var priority: Double = 30

    @State private var categories: [Category] = []
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Rule Name", text: $name)

                    Picker("Rule Type", selection: $ruleType) {
                        Text("MCC Code").tag(RuleType.mcc)
                        Text("Description Contains").tag(RuleType.description)
                        Text("Description Exact").tag(RuleType.descriptionExact)
                        Text("Amount Range").tag(RuleType.amount)
                    }
                } header: {
                    Text("Basic Info")
                }

                Section {
                    TextField(matchValuePlaceholder, text: $matchValue)
                } header: {
                    Text("Match Value")
                } footer: {
                    Text(matchValueFooter)
                }

                Section {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select category").tag(nil as Category?)
                        ForEach(categories) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.name)
                            }
                            .tag(category as Category?)
                        }
                    }
                } header: {
                    Text("Auto-assign Category")
                }

                Section {
                    HStack {
                        Text("Priority")
                        Spacer()
                        Text("\(Int(priority))")
                            .foregroundStyle(.secondary)
                    }

                    Slider(value: $priority, in: 1...100, step: 1)
                } header: {
                    Text("Rule Priority")
                } footer: {
                    Text("Lower numbers = higher priority. Built-in rules use 10-20.")
                }
            }
            .navigationTitle("New Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveRule()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                loadCategories()
            }
        }
    }

    private var matchValuePlaceholder: String {
        switch ruleType {
        case .mcc:
            return "e.g., 5411"
        case .description, .descriptionExact:
            return "e.g., Spotify"
        case .amount:
            return "e.g., 100-500"
        }
    }

    private var matchValueFooter: String {
        switch ruleType {
        case .mcc:
            return "Enter a 4-digit MCC code"
        case .description:
            return "Transactions containing this text will match"
        case .descriptionExact:
            return "Only exact matches (case-insensitive)"
        case .amount:
            return "Range format: min-max (e.g., 100-500) or exact amount"
        }
    }

    private var isValid: Bool {
        !name.isEmpty && !matchValue.isEmpty && selectedCategory != nil
    }

    private func loadCategories() {
        let descriptor = FetchDescriptor<Category>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Category.name)]
        )
        categories = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func saveRule() {
        guard let category = selectedCategory else { return }

        let viewModel = RulesViewModel(modelContext: modelContext)
        let success = viewModel.createRule(
            name: name,
            ruleType: ruleType,
            matchValue: matchValue,
            category: category,
            subCategory: nil,
            priority: Int(priority),
            isActive: true
        )

        if success {
            dismiss()
        } else if let error = viewModel.errorMessage {
            errorMessage = error
            showError = true
        }
    }
}

#Preview {
    NavigationStack {
        RulesListView()
    }
    .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}
