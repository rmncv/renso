import SwiftUI
import SwiftData

struct TransactionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let transaction: Transaction?

    @State private var selectedWallet: Wallet?
    @State private var amount: String = ""
    @State private var description: String = ""
    @State private var date: Date = Date()
    @State private var selectedCategory: Category?
    @State private var selectedSubCategory: SubCategory?
    @State private var selectedRefundCategory: Category?
    @State private var note: String = ""
    @State private var isIncome: Bool = false

    @State private var wallets: [Wallet] = []
    @State private var categories: [Category] = []
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showDeleteConfirmation = false
    @State private var didPopulate = false

    private var isEditing: Bool { transaction != nil }
    
    /// Check if this is a bank transaction (read-only)
    private var isBankTransaction: Bool {
        transaction?.isFromBank ?? false
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        Text("Select category").tag(nil as Category?)
                        ForEach(filteredCategories) { category in
                            HStack {
                                Image(systemName: category.iconName)
                                Text(category.name)
                            }
                            .tag(category as Category?)
                        }
                    }

                    if let category = selectedCategory,
                       let subCategories = category.subCategories,
                       !subCategories.isEmpty {
                        Picker("Sub-category", selection: $selectedSubCategory) {
                            Text("None").tag(nil as SubCategory?)
                            ForEach(subCategories) { subCategory in
                                Text(subCategory.name).tag(subCategory as SubCategory?)
                            }
                        }
                    }

                    if isRefundCategorySelected {
                        Picker("Refund for", selection: $selectedRefundCategory) {
                            Text("Select expense category").tag(nil as Category?)
                            ForEach(expenseCategories) { category in
                                HStack {
                                    Image(systemName: category.iconName)
                                    Text(category.name)
                                }
                                .tag(category as Category?)
                            }
                        }
                    }
                } header: {
                    Text("Category")
                }

                Section {
                    TextField("Note (optional)", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Note")
                }

                Section {
                    Picker("Wallet", selection: $selectedWallet) {
                        Text("Select wallet").tag(nil as Wallet?)
                        ForEach(wallets) { wallet in
                            Text(wallet.displayName).tag(wallet as Wallet?)
                        }
                    }
                    .disabled(isBankTransaction)

                    Toggle("Income", isOn: $isIncome)
                        .disabled(isBankTransaction)
                } header: {
                    Text("Wallet")
                }

                Section {
                    TextField("Amount", text: $amount)
                        .keyboardType(.decimalPad)
                        .disabled(isBankTransaction)

                    TextField("Description (optional)", text: $description)
                        .disabled(isBankTransaction)

                    DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .disabled(isBankTransaction)
                } header: {
                    Text("Details")
                }

                // Only show delete option for non-bank transactions
                if isEditing && !isBankTransaction {
                    Section {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            HStack {
                                Spacer()
                                Text("Delete Transaction")
                                Spacer()
                            }
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Transaction" : "Add Transaction")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveTransaction()
                    }
                    .disabled(!isValid)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .confirmationDialog("Delete Transaction", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    deleteTransaction()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Are you sure you want to delete this transaction? This action cannot be undone.")
            }
            .onAppear {
                loadData()
                if !didPopulate {
                    populateFromTransaction()
                    didPopulate = true
                }
            }
            .onChange(of: isIncome) { oldValue, newValue in
                guard didPopulate else { return }
                if oldValue != newValue {
                    selectedCategory = nil
                    selectedSubCategory = nil
                    selectedRefundCategory = nil
                }
            }
            .onChange(of: selectedCategory) { _, _ in
                guard didPopulate else { return }
                selectedSubCategory = nil
                selectedRefundCategory = nil
            }
        }
    }

    private var filteredCategories: [Category] {
        categories.filter { category in
            if isIncome {
                return category.type == .income
            } else {
                return category.type == .expense
            }
        }
    }

    private var expenseCategories: [Category] {
        categories.filter { $0.type == .expense }
    }

    private var isRefundCategorySelected: Bool {
        selectedCategory?.name.lowercased() == "refunds"
    }

    private var isValid: Bool {
        // Bank transactions are always valid (we only edit category/note)
        if isBankTransaction {
            return true
        }
        guard selectedWallet != nil else { return false }
        guard let amountValue = Decimal(string: amount), amountValue > 0 else { return false }
        return true
    }

    private func loadData() {
        let walletDescriptor = FetchDescriptor<Wallet>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Wallet.name)]
        )
        wallets = (try? modelContext.fetch(walletDescriptor)) ?? []

        let categoryDescriptor = FetchDescriptor<Category>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\Category.name)]
        )
        categories = (try? modelContext.fetch(categoryDescriptor)) ?? []
    }

    private func populateFromTransaction() {
        if let transaction = transaction {
            selectedWallet = transaction.wallet
            amount = "\(transaction.absoluteAmount)"
            description = transaction.transactionDescription
            date = transaction.date
            isIncome = transaction.isIncome
            selectedCategory = transaction.category
            selectedSubCategory = transaction.subCategory
            selectedRefundCategory = transaction.refundForCategory
            note = transaction.note ?? ""
        } else {
            selectedWallet = wallets.first
        }
    }

    private func saveTransaction() {
        // Bank transaction - only update category and note
        if isBankTransaction, let transaction = transaction {
            transaction.category = selectedCategory
            transaction.subCategory = selectedSubCategory
            transaction.refundForCategory = selectedRefundCategory
            transaction.note = note.isEmpty ? nil : note
            transaction.updatedAt = Date()

            do {
                try modelContext.save()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            return
        }

        // Regular transaction handling
        guard let wallet = selectedWallet,
              let amountValue = Decimal(string: amount) else {
            return
        }

        let finalAmount = isIncome ? amountValue : -amountValue
        let finalDescription = description.isEmpty ? "Transaction" : description

        if let transaction = transaction {
            // Edit mode - update existing
            let oldAmount = transaction.amount
            let oldWallet = transaction.wallet

            if let oldWallet = oldWallet {
                oldWallet.currentBalance -= oldAmount
            }

            transaction.amount = finalAmount
            transaction.transactionDescription = finalDescription
            transaction.date = date
            transaction.wallet = wallet
            transaction.category = selectedCategory
            transaction.subCategory = selectedSubCategory
            transaction.refundForCategory = selectedRefundCategory
            transaction.note = note.isEmpty ? nil : note
            transaction.updatedAt = Date()

            wallet.currentBalance += finalAmount
        } else {
            // Add mode - create new
            let newTransaction = Transaction(
                amount: finalAmount,
                description: finalDescription,
                date: date
            )

            newTransaction.wallet = wallet
            newTransaction.category = selectedCategory
            newTransaction.subCategory = selectedSubCategory
            newTransaction.refundForCategory = selectedRefundCategory
            if !note.isEmpty {
                newTransaction.note = note
            }

            wallet.currentBalance += finalAmount
            modelContext.insert(newTransaction)
        }

        do {
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteTransaction() {
        guard let transaction = transaction else { return }

        if let wallet = transaction.wallet {
            wallet.currentBalance -= transaction.amount
        }

        modelContext.delete(transaction)

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
    TransactionFormView(transaction: nil)
        .modelContainer(try! ModelContainerSetup.createPreviewContainer())
}

#Preview("Edit") {
    let container = try! ModelContainerSetup.createPreviewContainer()
    let transaction = Transaction(amount: -100, description: "Test Transaction")
    return TransactionFormView(transaction: transaction)
        .modelContainer(container)
}
