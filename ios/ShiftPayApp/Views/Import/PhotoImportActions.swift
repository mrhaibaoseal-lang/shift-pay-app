import SwiftUI
import PhotosUI

extension PhotoImportSheet {

    var verificationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("核對辨識結果（共 \(extractedRows.count) 筆）")
                .font(.system(size: 14, weight: .bold))

            Picker("寫入模式", selection: $writeModeAppend) {
                Text("➕ 合併追加（預設，保留加班）").tag(true)
                Text("🔄 整月覆蓋").tag(false)
            }
            .pickerStyle(.segmented)

            ForEach($extractedRows) { $row in
                HStack(spacing: 8) {
                    Button { row.checked.toggle() } label: {
                        Image(systemName: row.checked ? "checkmark.square.fill" : "square")
                            .foregroundStyle(row.checked ? Color(hex: "#0A84FF") : .white.opacity(0.4))
                    }
                    TextField("日期", text: $row.date)
                        .submitLabel(.done)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .frame(width: 92)
                    TextField("上班", text: $row.startTime)
                        .submitLabel(.done)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 52)
                    Text("-")
                    TextField("下班", text: $row.endTime)
                        .submitLabel(.done)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(width: 52)
                    if row.breakMin > 0 {
                        Text("休\(row.breakMin / 60)h")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.22), in: Capsule())
                            .foregroundStyle(Color(hex: "#FF9F0A"))
                    }
                    Spacer()
                    Text(row.shiftLabel.isEmpty ? row.note : "\(row.shiftLabel)・\(row.note)")
                        .font(.system(size: 10))
                        .foregroundStyle(row.needsReview ? Color(hex: "#FFD60A") : .white.opacity(0.6))
                        .lineLimit(1)
                }
                .padding(8)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
            }

            Button {
                confirmWriteImportedRows()
            } label: {
                Text("✅ 確認寫入勾選的 \(extractedRows.filter(\.checked).count) 天班表")
                    .font(.system(size: 15, weight: .heavy))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "#30D158"), in: RoundedRectangle(cornerRadius: 16))
                    .foregroundStyle(.black)
            }
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }

    func loadPickedImages(from items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let img = UIImage(data: data) {
                loaded.append(img)
            }
        }
        pickedImages = loaded
    }

    func runAIRecognition() async {
        guard !pickedImages.isEmpty else { return }
        isRunningAI = true
        defer { isRunningAI = false }
        do {
            let rows = try await DynamicProfileScheduleAgent.shared.recognizeMultiPageSchedule(
                images: pickedImages,
                year: targetYear,
                month: targetMonth,
                settings: vm.state.settings,
                stamps: vm.state.stamps,
                onStageChanged: { msg in statusText = msg }
            )
            extractedRows = rows
            statusText = "✅ 跨頁辨識完成！從 \(pickedImages.count) 張照片合併出 \(rows.count) 筆排班。"
            HapticsManager.shared.success()
        } catch {
            statusText = "❌ 辨識失敗：\(error.localizedDescription)"
            HapticsManager.shared.warning()
        }
    }

    func confirmWriteImportedRows() {
        let picked = extractedRows.filter { $0.checked && PayrollEngine.isValidDateKey($0.date) && PayrollEngine.isValidHHMM($0.startTime) && PayrollEngine.isValidHHMM($0.endTime) }
        guard !picked.isEmpty else { return }

        if !writeModeAppend {
            let prefix = PayrollEngine.ymPrefix(year: targetYear, month: targetMonth) + "-"
            for k in vm.state.shifts.keys where k.hasPrefix(prefix) {
                vm.state.shifts.removeValue(forKey: k)
            }
        }

        for r in picked {
            let matchedStamp = vm.state.stamps.first { $0.start == r.startTime && $0.end == r.endTime }
            let prev = vm.state.shifts[r.date]
            let isFullDayShift = (r.startTime == "10:30" && r.endTime == "21:00")
            let resolvedBreak = r.breakMin > 0 ? r.breakMin : (matchedStamp?.breakMin ?? (isFullDayShift ? 120 : defaultBreakMin))
            let resolvedName = matchedStamp?.name ?? (!r.shiftLabel.isEmpty ? r.shiftLabel : (isFullDayShift ? "整天班" : "匯入班"))
            vm.state.shifts[r.date] = ShiftRecord(
                name: resolvedName,
                color: matchedStamp?.color ?? (isFullDayShift ? "#FF9F0A" : "#64D2FF"),
                start: r.startTime,
                end: r.endTime,
                breakMin: resolvedBreak,
                stampId: matchedStamp?.id,
                otMin: prev?.otMin ?? 0,
                status: prev?.status ?? .normal,
                leaveType: prev?.leaveType ?? .late,
                note: r.note.isEmpty ? (prev?.note ?? "") : "手寫：\(r.note)"
            )
        }

        vm.viewYear = targetYear
        vm.viewMonth = targetMonth
        vm.save()
        HapticsManager.shared.success()
        vm.showToast("🎉 已透過「\(writeModeAppend ? "合併追加" : "整月覆蓋")」寫入 \(picked.count) 天班表！", style: .success)
        dismiss()
    }
}
