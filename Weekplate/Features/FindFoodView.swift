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
    private let service = OpenFoodFactsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeading(eyebrow: "For the unplanned bits", title: "FIND FOOD.",
                              subtitle: "Search, scan, or add your own.")
                WCard(color: Brand.blue) {
                    VStack(alignment: .leading, spacing: 12) {
                        Eyebrow(text: "Search packaged foods", color: .white.opacity(0.75))
                        HStack {
                            TextField("Try oats, yoghurt, pasta…", text: $query)
                                .textInputAutocapitalization(.never)
                                .submitLabel(.search)
                                .onSubmit { Task { await search() } }
                            Button { Task { await search() } } label: {
                                Image(systemName: "arrow.right").font(.headline)
                                    .foregroundStyle(Brand.blue)
                                    .frame(width: 37, height: 37)
                                    .background(.white, in: Circle())
                            }
                        }
                        .padding(10)
                        .background(.white.opacity(0.96), in: RoundedRectangle(cornerRadius: 15))
                        .foregroundStyle(.black)
                    }
                }
                Eyebrow(text: "Use your camera", color: Brand.blue)
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

                if isLoading { ProgressView("Looking up food…").frame(maxWidth: .infinity) }
                if isScanningLabel { ProgressView("Reading label…").frame(maxWidth: .infinity) }
                if let message {
                    Text(message).font(.subheadline).foregroundStyle(.secondary)
                }
                if !products.isEmpty {
                    Eyebrow(text: "Results", color: Brand.blue)
                    ForEach(products) { product in
                        Button { selectedProduct = product } label: {
                            WCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(product.name).font(.headline)
                                        Text(product.brand.isEmpty ? "Open Food Facts" : product.brand)
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Text("\(product.kcalPer100g.kcalText)\n/ 100g")
                                        .font(.subheadline.bold()).multilineTextAlignment(.trailing)
                                        .foregroundStyle(Brand.blue)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                Text("Packaged-food data: Open Food Facts. Check the label before logging.")
                    .font(.caption).foregroundStyle(.secondary)
                    .padding(.bottom, 20)
            }
            .padding(20)
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
                        .padding().background(.black.opacity(0.6), in: Capsule())
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
                Text(title).font(.system(size: 17, weight: .black, design: .rounded))
            }
            .foregroundStyle(color == Brand.coral ? .white : .black)
            .frame(maxWidth: .infinity, minHeight: 105, alignment: .leading)
            .padding(17)
            .background(color, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(MotionButtonStyle())
    }

    private func search() async {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return }
        isLoading = true
        message = nil
        do {
            products = try await service.search(term)
            if products.isEmpty { message = "No calorie-labelled matches. Try a different name or add it manually." }
        } catch { message = error.localizedDescription }
        isLoading = false
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
    @State private var grams = 100.0
    @State private var date = Date()
    @State private var meal: Meal = .snack

    var body: some View {
        NavigationStack {
            Form {
                Section(product.name) {
                    Text(product.brand)
                    Text("\(product.kcalPer100g.kcalText) kcal per 100g")
                    if let macros = product.macrosPer100g {
                        Text("C \(macros.carbs.portionText) · P \(macros.protein.portionText) · F \(macros.fat.portionText) g per 100g")
                    }
                    if !product.servingSize.isEmpty { Text("Pack serving: \(product.servingSize)") }
                }
                Section("Your amount") {
                    TextField("Grams eaten", value: $grams, format: .number)
                        .keyboardType(.decimalPad)
                    Text("\((grams * product.kcalPer100g / 100).kcalText) kcal")
                        .font(.title2.bold())
                    if let macros = product.macrosPer100g?.scaled(by: grams / 100) {
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
                        store.add(FoodEntry(name: product.name, calories: grams * product.kcalPer100g / 100,
                                            date: date, meal: meal, source: .packaged,
                                            macros: product.macrosPer100g?.scaled(by: grams / 100)))
                        dismiss()
                    }
                    .disabled(grams <= 0)
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
                        .clipShape(RoundedRectangle(cornerRadius: 14))
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
