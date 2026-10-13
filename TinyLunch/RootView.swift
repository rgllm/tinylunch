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
    @State private var permissionDenied = false
    @State private var editing: FoodItem?
    @State private var discard = false
    @State private var privacy = false
    @State private var toast = false
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize = 37

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if !model.modelAvailability.allowsPhotoAnalysis {
                        availabilityCard
                    }
                    if let meal = model.draft {
                        review(meal)
                    } else {
                        captureContent
                    }
                    if model.busy || model.importing {
                        HStack(spacing: 16) {
                            ProgressView()
                            Text(model.importing ? "Importing photo…" : "Estimating on your iPhone…")
                                .font(.subheadline)
                            Spacer(minLength: 0)
                            Button("Cancel") { model.cancel() }.font(.subheadline.weight(.semibold))
                        }.tinyLunchCard()
                    }
                }
                .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 28)
            }
            .background(TinyLunchStyle.paper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("TinyLunch").font(.system(.title, design: .rounded, weight: .bold)).tracking(-1.5)
                        .foregroundStyle(TinyLunchStyle.accent).padding(.vertical, 6).fixedSize()
                        .contentShape(Rectangle())
                        .onLongPressGesture(minimumDuration: 1) { toast = true }
                        .accessibilityLabel("TinyLunch")
                        .accessibilityIdentifier("tinyLunchWordmark")
                        .accessibilityAction(named: "A little toast") { toast = true }
                }.sharedBackgroundVisibility(.hidden)
                ToolbarItem(placement: .topBarTrailing) {
                    if model.draft != nil || model.image != nil {
                        Button("Start over", systemImage: "arrow.counterclockwise") { discard = true }
                            .disabled(model.saving)
                    } else {
                        Button("About privacy", systemImage: "lock.iphone") { privacy = true }
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let meal = model.draft { saveBar(meal) }
            }
            .confirmationDialog("Discard this unsaved meal?", isPresented: $discard, titleVisibility: .visible) {
                Button("Discard", role: .destructive) { model.reset() }
            }
            .sheet(item: $editing) { item in
                FoodEditor(
                    item: item,
                    busy: model.busy,
                    allowsIdentityEdit: model.modelAvailability.allowsTextEstimate,
                    cancel: model.cancel
                ) { name, preparation, grams in
                    model.update(item, name: name, preparation: preparation, grams: grams, onSuccess: { editing = nil })
                }.interactiveDismissDisabled(model.busy)
            }
            .sheet(isPresented: $privacy) { PrivacySheet() }
            .sheet(isPresented: $toast) { SurpriseSheet(kind: .toast) }
            .fullScreenCover(isPresented: $camera) { CameraView(receive: model.receiveCapture).ignoresSafeArea() }
            .alert("Camera access is off", isPresented: $permissionDenied) {
                Button("Open Settings") { if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) } }
                Button("Cancel", role: .cancel) {}
            } message: { Text("Allow camera access in Settings, or choose a photo instead.") }
            .onChange(of: selection) { _, value in
                if let value { model.importPhoto(value); selection = nil }
            }
            .sensoryFeedback(.success, trigger: model.savedNotice) { _, saved in saved }
            .sensoryFeedback(.selection, trigger: toast)
        }
    }

    private var captureContent: some View {
        let hasImage = model.image != nil
        return VStack(spacing: 24) {
            if let image = model.image {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Looking good.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Keep the whole meal in view. You can adjust the estimate next.")
                        .foregroundStyle(.secondary)
                    Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 310)
                        .frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 28))
                        .accessibilityLabel("Selected food photo")
                }
            } else if model.savedNotice {
                VStack(spacing: 18) {
                    Text("🥡").font(.system(size: 94)).accessibilityHidden(true).padding(.top, 28)
                    Label("Meal saved", systemImage: "checkmark.circle.fill")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Tucked away in History.\nJust the details, never the photo.")
                        .foregroundStyle(.secondary).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(.bottom, 22)
            } else if typeSize.isAccessibilitySize {
                Text("Your next meal.").font(.system(.title, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(spacing: 4) {
                    Text("A little insight.\nEvery bite.")
                        .font(.system(size: titleSize, weight: .bold, design: .rounded))
                        .tracking(-1.3).multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                    Text("Your plate, with a little perspective.")
                        .font(.subheadline).foregroundStyle(.secondary).padding(.top, 8)
                        .multilineTextAlignment(.center)
                    EmojiPlate().padding(.top, 12)
                }
            }

            VStack(spacing: 12) {
                if model.image != nil {
                    Button { model.analyze() } label: { Label("Analyze meal", systemImage: "sparkles") }
                        .buttonStyle(PrimaryAction())
                        .disabled(!model.modelAvailability.allowsPhotoAnalysis || model.busy || model.importing)
                        .accessibilityHint(model.modelAvailability.allowsPhotoAnalysis ? "Estimates this photo on your iPhone." : model.modelAvailability.explanation)
                } else {
                    Button { Task { await openCamera() } } label: { Label("Take photo", systemImage: "camera.fill") }
                        .buttonStyle(PrimaryAction()).disabled(model.busy || model.importing)
                }
                PhotosPicker(selection: $selection, matching: .images) {
                    Label(hasImage ? "Replace photo" : "Choose photo", systemImage: "photo.on.rectangle")
                        .font(.headline).frame(maxWidth: .infinity, minHeight: 52)
                        .background(TinyLunchStyle.card, in: RoundedRectangle(cornerRadius: 22))
                }.disabled(model.busy || model.importing)
                if model.image != nil {
                    Button("Retake photo") { Task { await openCamera() } }
                        .frame(minHeight: 44).disabled(model.busy || model.importing)
                }
            }

            if typeSize.isAccessibilitySize && model.image == nil && !model.savedNotice { EmojiPlate() }
            Button { privacy = true } label: {
                Label("On your iPhone. Just for you.", systemImage: "lock.shield")
                    .font(.footnote).foregroundStyle(.secondary).frame(minHeight: 44)
            }.buttonStyle(.plain)
        }
    }

    private func review(_ meal: Meal) -> some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Let’s take a look.").font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("A starting point, with room to adjust.").foregroundStyle(.secondary)
            }
            MealSummary(meal: meal)
            HStack {
                Text("On your plate").font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                Text("\(meal.items.count) items").font(.subheadline).foregroundStyle(.secondary)
            }
            VStack(spacing: 0) {
                ForEach(meal.items) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Button { editing = item } label: { FoodRow(item: item) }
                            .buttonStyle(.plain).frame(maxWidth: .infinity, alignment: .leading)
                            .accessibilityHint("Edit this food and its portion.")
                            .accessibilityIdentifier("editFood-\(item.name)")
                        Menu {
                            Button("Correct food", systemImage: "pencil") { editing = item }
                            Button("Remove food", systemImage: "minus.circle", role: .destructive) {
                                model.draft?.items.removeAll { $0.id == item.id }
                            }
                        } label: {
                            Image(systemName: "ellipsis").frame(width: 44, height: 44)
                        }.accessibilityLabel("Options for \(item.name)")
                    }.padding(.vertical, 16).disabled(model.busy || model.saving)
                    if item.id != meal.items.last?.id { Divider() }
                }
                if meal.items.isEmpty {
                    Text("Nothing on the plate yet. Add a food to continue.")
                        .foregroundStyle(.secondary).padding(.vertical, 20)
                }
                Divider()
                Button("Add food", systemImage: "plus.circle") {
                    editing = FoodItem(name: "", grams: nil, kcalPer100g: nil, preparation: "")
                }.font(.headline).frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                    .disabled(model.busy || model.saving || !model.modelAvailability.allowsTextEstimate)
                    .accessibilityHint(model.modelAvailability.allowsTextEstimate ? "Add a food for an on-device estimate." : model.modelAvailability.explanation)
            }.padding(.horizontal, 18).background(TinyLunchStyle.card, in: RoundedRectangle(cornerRadius: 26))
            Label("Tap a food to correct it. Portions are suggestions until you confirm them.", systemImage: "hand.tap")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func saveBar(_ meal: Meal) -> some View {
        VStack(spacing: 8) {
            Button { Task { await model.save() } } label: {
                HStack {
                    if model.saving { ProgressView().tint(.white) }
                    Text(model.saving ? "Saving…" : "Save meal")
                    Spacer()
                    Image(systemName: "arrow.down.to.line")
                }
            }.buttonStyle(PrimaryAction())
                .disabled(model.busy || model.saving || meal.items.isEmpty || !model.historyLoaded)
                .accessibilityIdentifier("saveMeal")
            Text("Only the details. Never the photo.").font(.caption).foregroundStyle(.secondary)
        }.padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 10).background(.regularMaterial)
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
            Label(state.title, systemImage: state.symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("photoAnalysisUnavailable")
            Text(state.explanation)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            Label(action.title, systemImage: action.symbol)
        }
        .buttonStyle(.borderless)
        .font(.subheadline.weight(.semibold))
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier(action.accessibilityIdentifier)
    }
}
