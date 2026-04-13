import SwiftUI

struct ProfileView: View {
    let onClose: () -> Void

    @AppStorage(AppData.StorageKeys.userName) private var storedUserName = ""
    @AppStorage(AppData.StorageKeys.gender) private var storedGender = ""
    @AppStorage(AppData.StorageKeys.age) private var storedAge = 0
    @AppStorage(AppData.StorageKeys.skinTone) private var storedSkinTone = ""
    @AppStorage(AppData.StorageKeys.skinUndertone) private var storedSkinUndertone = ""
    @AppStorage(AppData.StorageKeys.skinType) private var storedSkinType = ""
    @AppStorage(AppData.StorageKeys.latestReportData) private var latestReportData = Data()

    @State private var draftName = ""
    @State private var selectedGender: ProfileGenderOption = .unknown
    @State private var selectedBirthDate = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var selectedSkinTone = ""
    @State private var selectedSkinUndertone = ""
    @State private var selectedSkinType = ""
    @State private var didConfirmAge = false
    @State private var expandedPicker: ProfileExpandedPicker?
    @FocusState private var isNameFocused: Bool

    private let skinToneOptions = ["Very Fair", "Fair", "Light", "Medium", "Tan", "Deep"]
    private let skinUndertoneOptions = ["Cool", "Neutral", "Warm", "Olive"]
    private let skinTypeOptions = ["Normal", "Dry", "Oily", "Combination", "Sensitive"]

    var body: some View {
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, 19)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        nameField
                            .padding(.top, 24)

                        profileRows
                            .padding(.top, 26)
                    }
                    .padding(.horizontal, 19)
                    .padding(.bottom, 24)
                }
            }
        }
        .onAppear(perform: loadStoredValues)
        .onDisappear(perform: persistValues)
        .onChange(of: draftName) { _, _ in persistValues() }
        .onChange(of: selectedGender) { _, _ in persistValues() }
        .onChange(of: selectedBirthDate) { _, _ in
            didConfirmAge = true
            persistValues()
        }
        .onChange(of: selectedSkinTone) { _, _ in persistValues() }
        .onChange(of: selectedSkinUndertone) { _, _ in persistValues() }
        .onChange(of: selectedSkinType) { _, _ in persistValues() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button(action: onClose) {
                Circle()
                    .fill(Color.white.opacity(0.46))
                    .overlay(Circle().stroke(Color.white, lineWidth: 1))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "arrow.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                    )
            }
            .buttonStyle(.plain)

            Text("Profile")
                .font(.system(size: 30 * 0.6, weight: .medium))
                .foregroundStyle(Color(hex: "161616"))

            Spacer()
        }
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var nameField: some View {
        HStack(spacing: 6) {
            Image("app_ic_profile")
                .resizable()
                .scaledToFit()
                .frame(width: 58, height: 58)

            TextField("Enter your name", text: $draftName)
                .textInputAutocapitalization(.words)
                .disableAutocorrection(true)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(Color(hex: "222222"))
                .padding(.horizontal, 16)
                .frame(height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color(hex: "B163DB"), lineWidth: 1)
                )
                .focused($isNameFocused)
        }
    }

    private var profileRows: some View {
        VStack(spacing: 0) {
            row(
                label: "Gender",
                value: selectedGender.title,
                valueColor: expandedPicker == .gender ? Color(hex: "A148D1") : Color(hex: "222222")
            )
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFocused = false
                    togglePicker(.gender)
                }

            if expandedPicker == .gender {
                optionsWheelPicker(
                    options: ProfileGenderOption.allCases.filter { $0 != .unknown }.map(\.title),
                    selection: Binding(
                        get: { selectedGender.title },
                        set: { selectedGender = normalizedStoredGender($0) }
                    )
                )
            }

            rowDivider

            row(
                label: "Age",
                value: didConfirmAge ? "\(ageYears) years" : "Not set yet",
                valueColor: expandedPicker == .age ? Color(hex: "A148D1") : Color(hex: "222222")
            )
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFocused = false
                    togglePicker(.age)
                }

            if expandedPicker == .age {
                DatePicker("", selection: $selectedBirthDate, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .tint(Color(hex: "222222"))
                    .frame(height: 128)
                    .clipped()
                    .environment(\.locale, Locale(identifier: "en_US"))
            }

            rowDivider

            row(
                label: "Skin Tone",
                value: displayValue(selectedSkinTone),
                valueColor: expandedPicker == .skinTone ? Color(hex: "A148D1") : Color(hex: "222222")
            )
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFocused = false
                    togglePicker(.skinTone)
                }

            if expandedPicker == .skinTone {
                optionsWheelPicker(options: skinToneOptions, selection: $selectedSkinTone)
            }

            rowDivider

            row(
                label: "Skin Undertone",
                value: displayValue(selectedSkinUndertone),
                valueColor: expandedPicker == .skinUndertone ? Color(hex: "A148D1") : Color(hex: "222222")
            )
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFocused = false
                    togglePicker(.skinUndertone)
                }

            if expandedPicker == .skinUndertone {
                optionsWheelPicker(options: skinUndertoneOptions, selection: $selectedSkinUndertone)
            }

            rowDivider

            row(
                label: "Skin Type",
                value: displayValue(selectedSkinType),
                valueColor: expandedPicker == .skinType ? Color(hex: "A148D1") : Color(hex: "222222")
            )
                .contentShape(Rectangle())
                .onTapGesture {
                    isNameFocused = false
                    togglePicker(.skinType)
                }

            if expandedPicker == .skinType {
                optionsWheelPicker(options: skinTypeOptions, selection: $selectedSkinType)
            }
        }
    }

    private func row(label: String, value: String, valueColor: Color = Color(hex: "222222")) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 30 * 0.53, weight: .regular))
                .foregroundStyle(Color(hex: "222222"))

            Spacer()

            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
                .frame(width: 140, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.7))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.95), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 2)
                )
        }
        .frame(height: 68, alignment: .center)
    }

    private func optionsWheelPicker(options: [String], selection: Binding<String>) -> some View {
        VStack(spacing: 0) {
            rowDivider
            Picker("", selection: selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .tint(Color(hex: "222222"))
            .frame(height: 128)
            .clipped()
            rowDivider
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(Color(hex: "939393").opacity(0.32))
            .frame(height: 1)
    }

    private var ageYears: Int {
        max(0, Calendar.current.dateComponents([.year], from: selectedBirthDate, to: Date()).year ?? 0)
    }

    private func loadStoredValues() {
        draftName = storedUserName.trimmingCharacters(in: .whitespacesAndNewlines)
        selectedGender = normalizedStoredGender(storedGender)

        if storedAge > 0 {
            didConfirmAge = true
            selectedBirthDate = Calendar.current.date(byAdding: .year, value: -storedAge, to: Date()) ?? selectedBirthDate
        } else {
            didConfirmAge = false
        }

        selectedSkinTone = startingValue(
            stored: storedSkinTone,
            fallback: analysisGeneralValue(preferredIDs: ["skin_tone", "tone"], preferredLabels: ["Skin Tone"]),
            options: skinToneOptions
        )
        selectedSkinUndertone = startingValue(
            stored: storedSkinUndertone,
            fallback: analysisGeneralValue(preferredIDs: ["skin_undertone", "undertone"], preferredLabels: ["Skin Undertone"]),
            options: skinUndertoneOptions
        )
        selectedSkinType = startingValue(
            stored: storedSkinType,
            fallback: analysisGeneralValue(preferredIDs: ["skin_type", "type"], preferredLabels: ["Skin Type"]),
            options: skinTypeOptions
        )
    }

    private func normalizedStoredGender(_ value: String) -> ProfileGenderOption {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .unknown }
        switch trimmed.lowercased() {
        case "female":
            return .female
        case "male":
            return .male
        case "another":
            return .another
        default:
            return .unknown
        }
    }

    private func persistValues() {
        storedUserName = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        storedGender = selectedGender.title
        storedAge = didConfirmAge ? ageYears : 0
        storedSkinTone = selectedSkinTone
        storedSkinUndertone = selectedSkinUndertone
        storedSkinType = selectedSkinType
    }

    private func togglePicker(_ picker: ProfileExpandedPicker) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedPicker == picker {
                expandedPicker = nil
            } else {
                expandedPicker = picker
                if picker == .gender, selectedGender == .unknown {
                    selectedGender = .female
                }
                if picker == .age {
                    didConfirmAge = true
                }
                if picker == .skinTone, selectedSkinTone.isEmpty {
                    selectedSkinTone = skinToneOptions.first ?? ""
                }
                if picker == .skinUndertone, selectedSkinUndertone.isEmpty {
                    selectedSkinUndertone = skinUndertoneOptions.first ?? ""
                }
                if picker == .skinType, selectedSkinType.isEmpty {
                    selectedSkinType = skinTypeOptions.first ?? ""
                }
            }
        }
    }

    private var latestReport: SkinReport? {
        guard !latestReportData.isEmpty else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(SkinReport.self, from: latestReportData)
    }

    private func displayValue(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not set yet" : value
    }

    private func startingValue(stored: String, fallback: String?, options: [String]) -> String {
        let storedTrimmed = stored.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = options.first(where: { $0.lowercased() == storedTrimmed.lowercased() }) {
            return match
        }

        let fallbackTrimmed = (fallback ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = options.first(where: { $0.lowercased() == fallbackTrimmed.lowercased() }) {
            return match
        }

        return ""
    }

    private func analysisGeneralValue(preferredIDs: [String], preferredLabels: [String]) -> String? {
        guard let latestReport else { return nil }

        let normalizedIDs = Set(preferredIDs.map { $0.lowercased() })
        let normalizedLabels = Set(preferredLabels.map { $0.lowercased() })

        if let byID = latestReport.generalFields.first(where: { normalizedIDs.contains($0.id.lowercased()) }),
           let normalized = normalizedFieldValue(byID.value) {
            return normalized
        }

        if let byLabel = latestReport.generalFields.first(where: { normalizedLabels.contains($0.label.lowercased()) }),
           let normalized = normalizedFieldValue(byLabel.value) {
            return normalized
        }

        return nil
    }

    private func normalizedFieldValue(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }

        let lowered = value.lowercased()
        let unavailableValues: Set<String> = [
            "unknown",
            "not set",
            "not set yet",
            "n/a",
            "-"
        ]

        if unavailableValues.contains(lowered) {
            return nil
        }

        return value
    }
}

private enum ProfileExpandedPicker {
    case gender
    case age
    case skinTone
    case skinUndertone
    case skinType
}

private enum ProfileGenderOption: String, CaseIterable {
    case male
    case female
    case another
    case unknown

    var title: String {
        switch self {
        case .male:
            return "Male"
        case .female:
            return "Female"
        case .another:
            return "Another"
        case .unknown:
            return "Unknown"
        }
    }
}

#Preview("Profile") {
    ProfileView(onClose: {})
}
