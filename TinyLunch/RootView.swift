import SwiftUI
import PhotosUI
import AVFoundation

struct RootView: View {
    @Bindable var model: AppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    var body: some View {
        TabView(selection: $tab) {
            Tab("New meal", systemImage: "camera", value: 0) {
                CaptureView(model: model, showHistory: { tab = 1 })
            }
            Tab("History", systemImage: "clock", value: 1) { HistoryView(model: model, startMeal: { tab = 0 }) }
        }
        .tint(TinyLunchStyle.accent)
        .task { await model.refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await model.refresh() } }
        }
        .alert("Something needs attention", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK") { model.error = nil }
        } message: { Text(model.error ?? "") }
        #if DEBUG
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--marketing-dark") ? .dark : nil)
        #endif
    }
}

struct CaptureView: View {
    @Bindable var model: AppModel
    var showHistory: () -> Void
    @State private var selection: PhotosPickerItem?
    @State private var camera = false
    @State private var cameraDidCapture = false
    @State private var permissionDenied = false
    @State private var editing: FoodItem?
    @State private var editorReturnID: UUID?
    @State private var editorWasNewFood = false
    @State private var discard = false
    @State private var privacy = false
    @State private var privacySource = PrivacySource.toolbar
    @State private var toast = false
    @State private var suppressEstimateAnnouncement = false
    @State private var imageAtImportStart: UIImage?
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    @AccessibilityFocusState private var focusedFood: UUID?
    @AccessibilityFocusState private var addFoodFocused: Bool
    @AccessibilityFocusState private var savedFocused: Bool
    @AccessibilityFocusState private var reviewHeadingFocused: Bool
    @AccessibilityFocusState private var heroFocused: Bool
    @AccessibilityFocusState private var activityFocused: Bool
    @AccessibilityFocusState private var wordmarkFocused: Bool
    @AccessibilityFocusState private var captureFocus: CaptureFocus?
    @AccessibilityFocusState private var privacyReturnFocus: PrivacySource?

    private enum CaptureFocus: Hashable { case takePhoto, retake, analyze }
    private enum PrivacySource: Hashable { case toolbar, footer }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 24) {
                        if typeSize.isAccessibilitySize {
                            wordmark(resistsCompression: false)
                        }
                        if !model.modelAvailability.allowsPhotoAnalysis {
                            availabilityCard
                        }
                        if let meal = model.draft {
                            review(meal)
                        } else {
                            captureContent
                        }
                        if model.busy || model.importing {
                            activityRow
                        }
                    }
                    .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                if let meal = model.draft { saveBar(meal) }
            }
            .background(TinyLunchStyle.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !typeSize.isAccessibilitySize {
                    ToolbarItem(placement: .topBarLeading) {
                        wordmark(resistsCompression: true)
                    }.sharedBackgroundVisibility(.hidden)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if model.draft != nil || model.image != nil {
                        Button { discard = true } label: {
                            if typeSize.isAccessibilitySize {
                                Image(systemName: "arrow.counterclockwise")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            } else {
                                Label("Start over", systemImage: "arrow.counterclockwise")
                            }
                        }
                        .accessibilityLabel("Start over")
                        .accessibilityHint("Discards this unsaved meal.")
                        .disabled(model.saving)
                    } else {
                        Button {
                            privacySource = .toolbar
                            privacy = true
                        } label: {
                            if typeSize.isAccessibilitySize {
                                Image(systemName: "lock.iphone")
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            } else {
                                Label("About privacy", systemImage: "lock.iphone")
                            }
                        }
                        .accessibilityLabel("About privacy")
                        .accessibilityHint("Shows how TinyLunch stays on your iPhone and that it is not a medical device.")
                        .accessibilityIdentifier("aboutPrivacy")
                        .accessibilityFocused($privacyReturnFocus, equals: .toolbar)
                    }
                }
            }
            .confirmationDialog("Discard this unsaved meal?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { model.reset() }
            }
            .sheet(item: $editing, onDismiss: restoreFoodFocus) { item in
                FoodEditor(
                    item: item,
                    busy: model.busy,
                    allowsIdentityEdit: model.modelAvailability.allowsTextEstimate,
                    cancel: model.cancel
                ) { name, preparation, grams in
                    model.update(item, name: name, preparation: preparation, grams: grams, onSuccess: { editing = nil })
                }.interactiveDismissDisabled(model.busy)
            }
            .sheet(isPresented: $privacy, onDismiss: {
                let source = privacySource
                Task { @MainActor in privacyReturnFocus = source }
            }) { PrivacySheet() }
            .sheet(isPresented: $toast, onDismiss: {
                Task { @MainActor in wordmarkFocused = true }
            }) { SurpriseSheet(kind: .toast) }
            .fullScreenCover(isPresented: $camera, onDismiss: restoreCaptureFocus) {
                CameraView { image in
                    cameraDidCapture = true
                    model.receiveCapture(image)
                }.ignoresSafeArea()
            }
            .alert("Camera access is off", isPresented: $permissionDenied) {
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Allow camera access in Settings, or choose a photo instead.") }
            .onChange(of: selection) { _, value in
                if let value { model.importPhoto(value); selection = nil }
            }
            .sensoryFeedback(.success, trigger: model.savedNotice) { _, saved in saved }
            .sensoryFeedback(.selection, trigger: toast)
            .onChange(of: model.savedNotice) { _, saved in
                guard saved else { return }
                Task { @MainActor in savedFocused = true }
            }
            .onChange(of: model.busy) { _, busy in
                guard busy else { return }
                guard editing == nil else { return }
                Task { @MainActor in activityFocused = true }
            }
            .onChange(of: model.importing) { _, importing in
                if importing {
                    imageAtImportStart = model.image
                    VoiceOverAnnouncement.post(String(localized: "Importing photo."))
                    Task { @MainActor in activityFocused = true }
                } else if let image = model.image, image !== imageAtImportStart, model.draft == nil, model.error == nil {
                    VoiceOverAnnouncement.post(String(localized: "Photo ready to analyze."))
                    Task { @MainActor in captureFocus = .analyze }
                }
            }
            .onChange(of: estimateKey) { previous, key in
                if suppressEstimateAnnouncement {
                    suppressEstimateAnnouncement = false
                    return
                }
                guard let key, key != previous, let meal = model.draft else { return }
                let isFirst = previous == nil
                VoiceOverAnnouncement.post(estimateMessage(for: meal, isFirst: isFirst))
                guard isFirst else { return }
                Task { @MainActor in reviewHeadingFocused = true }
            }
            .onChange(of: discard) { _, showing in
                guard !showing, model.draft == nil, model.image == nil else { return }
                Task { @MainActor in heroFocused = true }
            }
        }
    }

    private var estimateKey: String? {
        model.draft.map { meal in
            meal.items.map { item in
                [
                    item.id.uuidString,
                    item.name,
                    item.preparation,
                    item.grams.map { String($0) } ?? "",
                    item.calories.map { String($0) } ?? "",
                    item.portionConfirmed ? "1" : "0"
                ].joined(separator: ":")
            }.joined(separator: "|")
        }
    }

    private func estimateMessage(for meal: Meal, isFirst: Bool) -> String {
        let lead = isFirst ? String(localized: "Estimate ready.") : String(localized: "Estimate updated.")
        if meal.calories == nil {
            return "\(lead) \(String(localized: "No foods could be estimated.")) \(String(localized: "Incomplete estimate"))."
        }
        let kind = meal.isIncomplete ? String(localized: "Known foods subtotal") : String(localized: "Estimated meal total")
        var message = "\(lead) \(kind) \(meal.spokenEnergy)."
        if meal.isIncomplete {
            message += " \(String(localized: "Incomplete estimate"))."
        }
        return message
    }

    private func edit(_ item: FoodItem) {
        editorReturnID = item.id
        editorWasNewFood = item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        editing = item
    }

    private func remove(_ item: FoodItem) {
        suppressEstimateAnnouncement = true
        model.draft?.items.removeAll { $0.id == item.id }
        VoiceOverAnnouncement.post(String(localized: "Removed \(item.name)."))
        Task { @MainActor in addFoodFocused = true }
    }

    private func restoreFoodFocus() {
        let id = editorReturnID
        let wasNew = editorWasNewFood
        Task { @MainActor in
            if let id, model.draft?.items.contains(where: { $0.id == id }) == true {
                focusedFood = id
            } else if wasNew {
                addFoodFocused = true
            }
        }
    }

    private func restoreCaptureFocus() {
        let captured = cameraDidCapture
        cameraDidCapture = false
        Task { @MainActor in
            if captured {
                VoiceOverAnnouncement.post(String(localized: "Photo ready to analyze."))
                captureFocus = .analyze
            } else if model.image == nil {
                captureFocus = .takePhoto
            } else {
                captureFocus = .retake
            }
        }
    }

    private var captureContent: some View {
        let hasImage = model.image != nil
        return VStack(spacing: 24) {
            if let image = model.image {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Looking good.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($heroFocused)
                    Text("Keep the whole meal in view. You can adjust the estimate next.")
                        .foregroundStyle(TinyLunchStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 310)
                        .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 28))
                        .accessibilityLabel("Selected food photo")
                        .accessibilityHint("Preview of the meal you can analyze.")
                        .accessibilityAddTraits(.isImage)
                }
            } else if model.savedNotice {
                VStack(spacing: 18) {
                    Text("🥡").font(.largeTitle).accessibilityHidden(true).accessibilityIdentifier("decorativeGlyph").padding(.top, 28)
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill").font(.largeTitle).accessibilityHidden(true)
                        Text("Meal saved")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    VStack(spacing: 4) {
                        Text("Tucked away in History.")
                        Text("Just the details, never the photo.")
                    }
                    .font(.body)
                    .foregroundStyle(TinyLunchStyle.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity).padding(.bottom, 22)
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                .accessibilityLabel("Meal saved. Tucked away in History. Just the details, never the photo.")
                .accessibilityFocused($savedFocused)
            } else if typeSize.isAccessibilitySize {
                Text("Your next meal.")
                    .font(.system(.title, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($heroFocused)
            } else {
                VStack(spacing: 4) {
                    Text("A little insight.\nEvery bite.")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($heroFocused)
                    Text("Your plate, with a little perspective.")
                        .font(.subheadline).foregroundStyle(TinyLunchStyle.ink).padding(.top, 8)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    EmojiPlate().padding(.top, 12)
                }
            }

            if !typeSize.isAccessibilitySize { MedicalDisclaimer() }

            VStack(spacing: 12) {
                if model.image != nil {
                    Button { model.analyze() } label: {
                        AccessibleActionLabel(title: "Analyze meal", systemImage: "sparkles")
                    }
                    .buttonStyle(PrimaryAction())
                    .disabled(!model.modelAvailability.allowsPhotoAnalysis || model.busy || model.importing)
                    .accessibilityLabel("Analyze meal")
                    .accessibilityHint(model.modelAvailability.allowsPhotoAnalysis ? "Estimates this meal on your iPhone." : model.modelAvailability.explanation)
                    .accessibilityFocused($captureFocus, equals: .analyze)
                } else {
                    Button { Task { await openCamera() } } label: {
                        AccessibleActionLabel(title: "Take photo", systemImage: "camera.fill")
                    }
                    .buttonStyle(PrimaryAction())
                    .disabled(model.busy || model.importing)
                    .accessibilityLabel("Take photo")
                    .accessibilityHint("Opens the camera to photograph a meal.")
                    .accessibilityFocused($captureFocus, equals: .takePhoto)
                }
                PhotosPicker(selection: $selection, matching: .images) {
                    AccessibleActionLabel(title: hasImage ? "Replace photo" : "Choose photo", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(TinyLunchStyle.card, in: RoundedRectangle(cornerRadius: 22))
                }
                .disabled(model.busy || model.importing)
                .accessibilityLabel(hasImage ? "Replace photo" : "Choose photo")
                .accessibilityHint(hasImage ? "Selects a different photo." : "Selects one photo from your library.")
                if model.image != nil {
                    Button { Task { await openCamera() } } label: {
                        Text("Retake photo")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .disabled(model.busy || model.importing)
                    .accessibilityHint("Opens the camera to replace this photo.")
                    .accessibilityFocused($captureFocus, equals: .retake)
                }
            }

            if typeSize.isAccessibilitySize { MedicalDisclaimer() }

            if typeSize.isAccessibilitySize && model.image == nil && !model.savedNotice { EmojiPlate() }
            Button {
                privacySource = .footer
                privacy = true
            } label: {
                Text("On your iPhone. Just for you.")
                    .font(.subheadline)
                    .foregroundStyle(TinyLunchStyle.ink)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .accessibilityLabel("On your iPhone. Just for you.")
            .accessibilityHint("Shows how TinyLunch stays on your iPhone and that it is not a medical device.")
            .accessibilityFocused($privacyReturnFocus, equals: .footer)
        }
    }

    private func review(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Let’s take a look.")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($reviewHeadingFocused)
                Text("A starting point, with room to adjust.")
                    .foregroundStyle(TinyLunchStyle.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            MealSummary(meal: meal)
            MedicalDisclaimer()
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text("On your plate")
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityAddTraits(.isHeader)
                    Text("\(meal.items.count) items")
                        .font(.subheadline).foregroundStyle(TinyLunchStyle.ink)
                        .accessibilityLabel("\(meal.items.count) items")
                }
            } else {
                HStack {
                    Text("On your plate").font(.system(.title3, design: .rounded, weight: .bold))
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Text("\(meal.items.count) items").font(.subheadline).foregroundStyle(TinyLunchStyle.ink)
                }
            }
            VStack(spacing: 0) {
                ForEach(meal.items) { item in
                    let row = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                        : AnyLayout(HStackLayout(alignment: .top, spacing: 8))
                    row {
                        Button { edit(item) } label: { FoodRow(item: item) }
                            .buttonStyle(.plain)
                            .tint(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .layoutPriority(1)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel(item.accessibilityDescription)
                            .accessibilityHint("Corrects this food and its portion. Use the actions to correct or remove it.")
                            .accessibilityIdentifier("editFood-\(item.name)")
                            .accessibilityFocused($focusedFood, equals: item.id)
                            .accessibilityAction(named: "Correct food") { edit(item) }
                            .accessibilityAction(named: "Remove food") { remove(item) }
                        Menu {
                            Button("Correct food", systemImage: "pencil") { edit(item) }
                            Button("Remove food", systemImage: "minus.circle", role: .destructive) { remove(item) }
                        } label: {
                            if typeSize.isAccessibilitySize {
                                AccessibleActionLabel(title: "Options", systemImage: "ellipsis")
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            } else {
                                Image(systemName: "ellipsis")
                                    .font(.body)
                                    .frame(minWidth: 44, minHeight: 44)
                                    .contentShape(Rectangle())
                            }
                        }
                        .accessibilityLabel("Options for \(item.name)")
                        .accessibilityHint("Correct or remove this food.")
                        .accessibilityIdentifier("foodOptions-\(item.name)")
                    }.padding(.vertical, 16).disabled(model.busy || model.saving)
                    if item.id != meal.items.last?.id { Divider() }
                }
                if meal.items.isEmpty {
                    Text("Nothing on the plate yet. Add a food to continue.")
                        .foregroundStyle(TinyLunchStyle.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 20)
                }
                Divider()
                Button {
                    edit(FoodItem(name: "", grams: nil, kcalPer100g: nil, preparation: ""))
                } label: {
                    AccessibleActionLabel(title: "Add food", systemImage: "plus.circle")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                }
                .disabled(model.busy || model.saving || !model.modelAvailability.allowsTextEstimate)
                .accessibilityLabel("Add food")
                .accessibilityHint(model.modelAvailability.allowsTextEstimate ? "Adds a food by name for an on-device estimate." : model.modelAvailability.explanation)
                .accessibilityFocused($addFoodFocused)
            }.padding(.horizontal, 18).background(TinyLunchStyle.card, in: RoundedRectangle(cornerRadius: 26))
            Text("Tap a food to correct it. Portions are suggestions until you confirm them.")
                .font(.headline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func saveBar(_ meal: Meal) -> some View {
        VStack(spacing: 8) {
            Button { Task { await model.save() } } label: {
                HStack(alignment: .center, spacing: 8) {
                    if model.saving {
                        ProgressView().tint(.white).accessibilityHidden(true)
                    }
                    Text(model.saving ? "Saving…" : "Save meal")
                        .multilineTextAlignment(typeSize.isAccessibilitySize ? .center : .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: typeSize.isAccessibilitySize ? .center : .leading)
                    if !model.saving && !typeSize.isAccessibilitySize {
                        Image(systemName: "arrow.down.to.line").accessibilityHidden(true)
                    }
                }
            }.buttonStyle(PrimaryAction())
                .disabled(model.busy || model.saving || meal.items.isEmpty || !model.historyLoaded)
                .accessibilityIdentifier("saveMeal")
                .accessibilityLabel(model.saving ? "Saving meal" : "Save meal")
                .accessibilityHint("Saves meal details on this iPhone. The photo is not saved.")
            Text("Only the details. Never the photo.")
                .font(.caption).foregroundStyle(TinyLunchStyle.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 10)
            .background(TinyLunchStyle.paper)
            .overlay(alignment: .top) { Divider() }
    }

    private func wordmark(resistsCompression: Bool) -> some View {
        Text("TinyLunch")
            .font(.system(.title, design: .rounded, weight: .bold))
            .tracking(typeSize >= .xxxLarge ? 0 : -1.5)
            .foregroundStyle(TinyLunchStyle.accent)
            .lineLimit(1)
            .minimumScaleFactor(typeSize.isAccessibilitySize ? 0.5 : 1)
            .fixedSize(horizontal: resistsCompression, vertical: false)
            .frame(maxWidth: resistsCompression ? nil : .infinity, minHeight: 44, alignment: .leading)
            .contentShape(Rectangle())
            .onLongPressGesture(minimumDuration: 1) { toast = true }
            .accessibilityLabel("TinyLunch")
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("tinyLunchWordmark")
            .accessibilityFocused($wordmarkFocused)
            .accessibilityAction(named: "A little toast") { toast = true }
    }

    private var activityRow: some View {
        let status = model.importing ? "Importing photo…" : "Estimating on your iPhone…"
        return HStack(alignment: .center, spacing: 16) {
            ProgressView().accessibilityHidden(true)
            Text(status)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.updatesFrequently)
                .accessibilityFocused($activityFocused)
                .accessibilityIdentifier("analysisActivity")
            Button("Cancel") { model.cancel() }
                .font(.subheadline.weight(.semibold))
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHint(model.importing ? "Stops importing this photo." : "Stops this estimate and keeps your photo.")
        }
        .tinyLunchCard()
    }

    private var availabilityCard: some View {
        AnalysisAvailabilityCard(
            state: model.modelAvailability,
            retry: { Task { await model.refresh() } },
            openSettings: openSystemSettings,
            openHistory: showHistory
        )
    }

    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }

    private func openCamera() async {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.error = "A camera is not available on this device. Choose a photo instead."
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: camera = true
        case .notDetermined:
            if await AVCaptureDevice.requestAccess(for: .video) { camera = true }
            else { permissionDenied = true }
        default: permissionDenied = true
        }
    }
}

struct AnalysisAvailabilityCard: View {
    let state: AnalysisAvailabilityState
    var showsHistoryAction = true
    var retry: () -> Void
    var openSettings: () -> Void
    var openHistory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: state.symbol)
                    .font(.subheadline.weight(.semibold))
                    .accessibilityHidden(true)
                Text(state.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(.primary)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("photoAnalysisUnavailable")
            Text(state.explanation)
                .font(.subheadline)
                .foregroundStyle(TinyLunchStyle.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("analysisAvailabilityExplanation")
            actions
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TinyLunchStyle.soft.opacity(0.65), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("analysisUnavailableCard")
    }

    private var actions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { actionButtons }
            VStack(alignment: .leading, spacing: 0) { actionButtons }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        if let action = state.primaryAction, includes(action) {
            button(action)
        }
        if let action = state.secondaryAction, includes(action) {
            button(action)
        }
    }

    private func includes(_ action: AnalysisAvailabilityState.Action) -> Bool {
        showsHistoryAction || action != .openHistory
    }

    private func button(_ action: AnalysisAvailabilityState.Action) -> some View {
        Button {
            switch action {
            case .openSettings: openSettings()
            case .retry: retry()
            case .openHistory: openHistory()
            }
        } label: {
            Text(action.title)
                .foregroundStyle(TinyLunchStyle.accent)
        }
        .buttonStyle(ScaledTextButton())
        .accessibilityIdentifier(action.accessibilityIdentifier)
        .accessibilityHint(action.accessibilityHint)
    }
}
