import SwiftUI
import PhotosUI

struct PhotoImportSheet: View {
    @Bindable var vm: ShiftPayViewModel
    @Environment(\.dismiss) var dismiss

    @State var selectedItems: [PhotosPickerItem] = []
    @State var pickedImages: [UIImage] = []
    @State var targetYear: Int = 2026
    @State var targetMonth: Int = 11
    @State var defaultBreakMin: Int = 0
    @State var writeModeAppend: Bool = true
    @State var isRunningAI: Bool = false
    @State var statusText: String = ""
    @State var extractedRows: [ExtractedShiftRow] = []
    @State var manualJSONText: String = ""
    @State var showManualTab: Bool = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    monthAndModeHeader
                    if !showManualTab {
                        multiPhotoPickerCard
                    } else {
                        manualPromptAndJSONCard
                    }
                    if !statusText.isEmpty {
                        Text(statusText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "#64D2FF"))
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                    }
                    if !extractedRows.isEmpty {
                        verificationSection
                    }
                }
                .padding(16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(
                Color(hex: "#1C1C1E")
                    .ignoresSafeArea()
                    .onTapGesture { KeyboardDismissManager.dismiss() }
            )
            .navigationTitle("📸 多圖 AI 智慧辨識班表")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                targetYear = vm.viewYear
                targetMonth = vm.viewMonth
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") {
                        KeyboardDismissManager.dismiss()
                        dismiss()
                    }
                }
            }
            .dismissKeyboardOnTap()
        }
    }

    private var monthAndModeHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("鎖定姓名：\(vm.state.settings.myName)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text(vm.state.settings.aiProvider.shortBadge)
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.purple.opacity(0.25), in: Capsule())
                    .foregroundStyle(Color(hex: "#BF5AF2"))
            }

            HStack(spacing: 10) {
                Stepper("年份：\(String(targetYear))", value: $targetYear, in: 2024...2030)
                    .font(.system(size: 13, weight: .semibold))
                Stepper("月份：\(targetMonth)月", value: $targetMonth, in: 1...12)
                    .font(.system(size: 13, weight: .semibold))
            }

            Picker("匯入方式", selection: $showManualTab) {
                Text("📸 多張照片 AI 辨識").tag(false)
                Text("📋 複製 Prompt / 貼上 JSON").tag(true)
            }
            .pickerStyle(.segmented)
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }
}
