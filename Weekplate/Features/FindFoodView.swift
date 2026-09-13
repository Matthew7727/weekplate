import PhotosUI
import SwiftUI
import UIKit

struct FindFoodView: View {
    @ObservedObject var store: AppStore
    @State private var query = ""
    @State private var barcodeText = ""
    @State private var products: [FoodProduct] = []
    @State private var selectedProduct: FoodProduct?
    @State private var scan: NutritionScan?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showScanner = false
    @State private var showCamera = false
    @State private var showManual = false
    @State private var pendingImage: UIImage?
    @State private var isLoading = false
    @State private var isScanningLabel = false
    @State private var message: String?
    @State private var searchMessage: String?
    @State private var hasSearched = false
    @State private var showAllResults = false
    @FocusState private var searchFocused: Bool
    private let service = OpenFoodFactsService()

    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeading(eyebrow: "For the unplanned bits", title: "FIND FOOD.",
                              subtitle: "Search, scan, or add your own.", alignment: .center)
                WCard(color: Brand.blue) {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Search packaged foods", color: .white.opacity(0.75))
                        HStack {
                            TextField("Try oats, yoghurt, pasta…", text: $query)
                                .textInputAutocapitalization(.never)
                                .submitLabel(.search)
                                .focused($searchFocused)
                                .onSubmit { Task { await search(proxy) } }
                            Button { Task { await search(proxy) } } label: {
                                Image(systemName: "arrow.right").font(.headline)
                                    .foregroundStyle(Brand.blue)
                                    .frame(width: 37, height: 37)
                                    .background(.white, in: Circle())
                            }
                        }
                        .padding(10)
                        .background(.white.opacity(0.96), in: Rectangle())
                        .foregroundStyle(.black)
                    }
                }
                if isLoading { ProgressView("Finding the best matches…").frame(maxWidth: .infinity) }
                if hasSearched {
                    VStack(alignment: .leading, spacing: 10) {
                        Eyebrow(text: "Best matches", color: Brand.blue)
                        if products.isEmpty && !isLoading {
                            Text(searchMessage ?? "No nutrition-labelled matches. Try a different name or add it manually.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(Array(products.prefix(showAllResults ? 20 : 6))) { product in
                            Button { selectedProduct = product } label: {
                                WCard {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(product.name).font(.headline)
                                            Text([product.brand, product.quantity].filter { !$0.isEmpty }.joined(separator: " · "))
                                                .font(.caption).foregroundStyle(.secondary)
                                            if let macros = product.macrosPer100 {
                                                Text("C \(macros.carbs.portionText) · P \(macros.protein.portionText) · F \(macros.fat.portionText) g")
                                                    .font(.caption2).foregroundStyle(Brand.blue)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                        Text("\(product.kcalPer100.kcalText) kcal\n/ 100\(product.unit.rawValue)")
                                            .font(.caption.bold()).multilineTextAlignment(.trailing)
                                            .foregroundStyle(Brand.blue)
                                    }
                                }
                            }
                            .buttonStyle(MotionButtonStyle())
                        }
                        if products.count > 6 {
                            Button(showAllResults ? "Show fewer" : "Show \(products.count - 6) more matches") {
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    showAllResults.toggle()
                                }
                            }
                            .font(.subheadline.bold()).foregroundStyle(Brand.blue)
                        }
                        Text("Similar listings are grouped. Scan the barcode for the exact pack.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .id("search-results")
                }
                Eyebrow(text: "Use your camera", color: Brand.blue)
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack(spacing: 10) {
                    actionTile("Scan barcode", "barcode.viewfinder", Brand.coral) { showScanner = true }
                    actionTile("Photograph label", "camera.macro", Brand.lilac) { showCamera = true }
                }
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Or choose a nutrition-label photo", systemImage: "photo")
                        .font(.subheadline.bold()).foregroundStyle(Brand.blue)
                }
                WCard {
                    HStack {
                        TextField("Barcode number", text: $barcodeText)
                            .keyboardType(.numberPad)
                        Button("Look up") { Task { await lookUp(barcodeText) } }
                            .disabled(barcodeText.isEmpty)
                    }
                }
                PillButton(title: "Add manually", symbol: "square.and.pencil") { showManual = true }

                if isScanningLabel { ProgressView("Reading label…").frame(maxWidth: .infinity) }
                if let message {
                    Text(message).font(.subheadline).foregroundStyle(.secondary)
                }
                Text("Packaged-food data: Open Food Facts. Check the label before logging.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
            .padding(20)
        }
        }
        .sheet(isPresented: $showManual) { ManualFoodView(store: store, date: Date()) }
        .sheet(item: $selectedProduct) { ProductLogView(store: store, product: $0) }
        .sheet(item: $scan) { NutritionReviewView(store: store, scan: $0) }
        .sheet(isPresented: $showScanner) {
            ZStack {
                BarcodeScannerView { code in
                    showScanner = false
                    barcodeText = code
                    Task { await lookUp(code) }
                } onFailure: { reason in
                    showScanner = false
                    message = reason
                }
                VStack {
                    Text("Point at a barcode")
                        .font(.title2.bold()).foregroundStyle(.white)
                        .padding().background(.black.opacity(0.6), in: Rectangle())
                    Spacer()
                    Button("Close") { showScanner = false }
                        .buttonStyle(.borderedProminent).padding()
                }
                .padding(.top, 30)
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showCamera, onDismiss: {
            if let image = pendingImage {
                pendingImage = nil
                scanImage(image)
            }
        }) {
            CameraImagePicker { image in pendingImage = image }
        }
        .onChange(of: selectedPhoto) { _, photo in
            guard let photo else { return }
            Task {
                if let data = try? await photo.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) { scanImage(image) }
            }
        }
    }

    private func actionTile(_ title: String, _ symbol: String, _ color: Color,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 20) {
                Image(systemName: symbol).font(.system(size: 28, weight: .bold))
                Text(title).font(.system(size: 17, weight: .black))
            }
            .foregroundStyle(color == Brand.coral ? .white : .black)
            .frame(maxWidth: .infinity, minHeight: 105, alignment: .leading)
            .padding(17)
            .background(color, in: Rectangle())
        }
        .buttonStyle(MotionButtonStyle())
    }

    private func search(_ proxy: ScrollViewProxy) async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        searchFocused = false
        hasSearched = true
        showAllResults = false
        isLoading = true
        searchMessage = nil
        products = []
        do {
            products = try await service.search(term)
            if products.isEmpty { searchMessage = "No calorie-labelled matches. Try a different name or add it manually." }
        } catch { searchMessage = error.localizedDescription }
        isLoading = false
        withAnimation(.easeOut(duration: 0.35)) { proxy.scrollTo("search-results", anchor: .top) }
    }

    private func lookUp(_ code: String) async {
        guard !code.isEmpty else { return }
        isLoading = true
        message = nil
        do { selectedProduct = try await service.barcode(code) }
        catch { message = error.localizedDescription }
        isLoading = false
    }

    private func scanImage(_ image: UIImage) {
        isScanningLabel = true
        message = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try NutritionOCR.scan(image) }
            DispatchQueue.main.async {
                isScanningLabel = false
                switch result {
                case .success(let value): scan = value
                case .failure: message = "Could not read that label. Try a clearer photo or add it manually."
                }
            }
        }
    }
}

struct ProductLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    let product: FoodProduct
    @State private var amount = 100.0
    @State private var kcalText: String
    @State private var carbsText: String
    @State private var proteinText: String
    @State private var fatText: String
    @State private var date = Date()
    @State private var meal: Meal = .snack

    init(store: AppStore, product: FoodProduct) {
        self.store = store
        self.product = product
        _kcalText = State(initialValue: String(product.kcalPer100))
        _carbsText = State(initialValue: product.macrosPer100.map { String($0.carbs) } ?? "")
        _proteinText = State(initialValue: product.macrosPer100.map { String($0.protein) } ?? "")
        _fatText = State(initialValue: product.macrosPer100.map { String($0.fat) } ?? "")
    }

    private var anyMacroEntered: Bool {
        !carbsText.isEmpty || !proteinText.isEmpty || !fatText.isEmpty
    }
    private var macrosPer100: MacroTotals? {
        guard let carbs = Double(carbsText), let protein = Double(proteinText),
              let fat = Double(fatText) else { return nil }
        let value = MacroTotals(carbs: carbs, protein: protein, fat: fat)
        return value.isValid ? value : nil
    }
    private var caloriesToLog: Double {
        ((Double(kcalText) ?? 0) > 0 ? (Double(kcalText) ?? 0) : (macrosPer100?.calories ?? 0))
            * amount / 100
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(product.name) {
                    if !product.brand.isEmpty { Text(product.brand) }
                    if !product.quantity.isEmpty { Text("Pack: \(product.quantity)") }
                    if !product.servingSize.isEmpty { Text("Pack serving: \(product.servingSize)") }
                }
                Section("Nutrition \(product.per100Label)") {
                    Text("Community data can vary. Check your pack and correct these numbers if needed.")
                        .font(.caption).foregroundStyle(.secondary)
                    TextField("Kcal", text: $kcalText).keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbsText).keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $proteinText).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fatText).keyboardType(.decimalPad)
                    if !anyMacroEntered {
                        Text("This listing has no complete macros. Add them from the label to track them.")
                            .font(.caption).foregroundStyle(.secondary)
                    } else if macrosPer100 == nil {
                        Text("Enter all three macros, or clear them all.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                Section("Your amount") {
                    HStack {
                        TextField("Amount consumed", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                        Text(product.unit.rawValue).foregroundStyle(.secondary)
                    }
                    Text("\(caloriesToLog.kcalText) kcal")
                        .font(.title2.bold())
                    if let macros = macrosPer100?.scaled(by: amount / 100) {
                        Text("C \(macros.carbs.portionText) · P \(macros.protein.portionText) · F \(macros.fat.portionText) g")
                    }
                }
                DatePicker("Day", selection: $date, displayedComponents: .date)
                Picker("Meal", selection: $meal) {
                    ForEach(Meal.allCases) { Text($0.rawValue).tag($0) }
                }
            }
            .navigationTitle("Log product")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        store.add(FoodEntry(name: product.name, calories: caloriesToLog,
                                            date: date, meal: meal, source: .packaged,
                                            macros: macrosPer100?.scaled(by: amount / 100),
                                            quantity: amount, quantityUnit: product.unit))
                        dismiss()
                    }
                    .disabled(amount <= 0 || caloriesToLog <= 0 || (anyMacroEntered && macrosPer100 == nil))
                }
            }
        }
    }
}

struct NutritionReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var store: AppStore
    let scan: NutritionScan
    @State private var name = ""
    @State private var kcal = 0.0
    @State private var carbsText = ""
    @State private var proteinText = ""
    @State private var fatText = ""
    @State private var grams = 100.0
    @State private var per100g = true
    @State private var date = Date()
    @State private var meal: Meal = .snack

    init(store: AppStore, scan: NutritionScan) {
        self.store = store
        self.scan = scan
        _kcal = State(initialValue: scan.suggestedKcal ?? 0)
        _carbsText = State(initialValue: scan.suggestedMacros?.carbs.portionText ?? "")
        _proteinText = State(initialValue: scan.suggestedMacros?.protein.portionText ?? "")
        _fatText = State(initialValue: scan.suggestedMacros?.fat.portionText ?? "")
    }

    private var macrosOnLabel: MacroTotals? {
        guard let carbs = Double(carbsText), let protein = Double(proteinText),
              let fat = Double(fatText) else { return nil }
        let value = MacroTotals(carbs: carbs, protein: protein, fat: fat)
        return value.isValid ? value : nil
    }
    private var anyMacroEntered: Bool { !carbsText.isEmpty || !proteinText.isEmpty || !fatText.isEmpty }
    private var factor: Double { per100g ? grams / 100 : 1 }
    private var caloriesToLog: Double { (kcal > 0 ? kcal : (macrosOnLabel?.calories ?? 0)) * factor }

    var body: some View {
        NavigationStack {
            Form {
                Section("Review the label") {
                    Image(uiImage: scan.image)
                        .resizable().scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 210)
                        .clipShape(Rectangle())
                    Text("Check every number against the photo. Labels may have per 100g and per serving columns; OCR may read either one.")
                        .font(.subheadline)
                    TextField("Food name", text: $name)
                    Picker("Numbers on label", selection: $per100g) {
                        Text("Per 100g").tag(true)
                        Text("Amount eaten").tag(false)
                    }
                    .pickerStyle(.segmented)
                    if per100g {
                        TextField("Grams eaten", value: $grams, format: .number)
                            .keyboardType(.decimalPad)
                    }
                    TextField("Kcal on label", value: $kcal, format: .number)
                        .keyboardType(.decimalPad)
                    TextField("Carbs (g)", text: $carbsText).keyboardType(.decimalPad)
                    TextField("Protein (g)", text: $proteinText).keyboardType(.decimalPad)
                    TextField("Fat (g)", text: $fatText).keyboardType(.decimalPad)
                    Text("You’ll log \(caloriesToLog.kcalText) kcal")
                        .font(.headline)
                    if let macros = macrosOnLabel?.scaled(by: factor) {
                        Text("C \(macros.carbs.portionText) · P \(macros.protein.portionText) · F \(macros.fat.portionText) g")
                    } else if anyMacroEntered {
                        Text("Enter all three macros to track them.")
                            .font(.caption).foregroundStyle(.orange)
                    }
                }
                DatePicker("Day", selection: $date, displayedComponents: .date)
                Picker("Meal", selection: $meal) {
                    ForEach(Meal.allCases) { Text($0.rawValue).tag($0) }
                }
                Section("Scanned text") {
                    Text(scan.text.isEmpty ? "No text recognised. You can still enter values above." : scan.text)
                        .font(.caption).textSelection(.enabled)
                }
            }
            .navigationTitle("Nutrition scan")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Log") {
                        store.add(FoodEntry(name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                            calories: caloriesToLog, date: date,
                                            meal: meal, source: .manual,
                                            macros: macrosOnLabel?.scaled(by: factor)))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              caloriesToLog <= 0 || grams <= 0 || (anyMacroEntered && macrosOnLabel == nil))
                }
            }
        }
    }
}
