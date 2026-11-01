import SwiftUI
import PhotosUI

extension PhotoImportSheet {

    var multiPhotoPickerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            PhotosPicker(
                selection: $selectedItems,
                maxSelectionCount: 8,
                matching: .images
            ) {
                HStack {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 18))
                    Text(pickedImages.isEmpty ? "選取手寫班表照片（支援多張跨頁合併）" : "已選取 \(pickedImages.count) 張照片（點此重選）")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
            }
            .onChange(of: selectedItems) { _, newItems in
                Task { await loadPickedImages(from: newItems) }
            }

            if !pickedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(pickedImages.enumerated()), id: \.offset) { idx, img in
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 76, height: 76)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(alignment: .topLeading) {
                                    Text("P\(idx + 1)")
                                        .font(.system(size: 10, weight: .heavy))
                                        .padding(4)
                                        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 6))
                                }
                        }
                    }
                }

                Button {
                    Task { await runAIRecognition() }
                } label: {
                    HStack {
                        if isRunningAI { ProgressView().tint(.white) }
                        Text(isRunningAI ? "AI 正在合併辨識 \(pickedImages.count) 張照片…" : "✨ 開始跨頁智慧辨識 (\(pickedImages.count) 張)")
                            .font(.system(size: 15, weight: .heavy))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(colors: [Color(hex: "#0A84FF"), Color(hex: "#BF5AF2")], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                    .foregroundStyle(.white)
                }
                .disabled(isRunningAI)
            }
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }

    var manualPromptAndJSONCard: some View {
        let context = ScheduleExtractionContext(
            year: targetYear,
            month: targetMonth,
            employeeName: vm.state.settings.myName,
            codeHints: vm.state.settings.codeHints,
            stamps: vm.state.stamps
        )
        let prompt = SchedulePromptBuilder.buildSystemAndUserPrompt(context: context, imageCount: max(1, pickedImages.count))

        return VStack(alignment: .leading, spacing: 10) {
            Button {
                UIPasteboard.general.string = prompt
                HapticsManager.shared.success()
                vm.showToast("✅ 已複製跨頁合併 Prompt，可貼到聊天 AI 並附上照片", style: .success)
            } label: {
                Label("一鍵複製跨頁合併辨識 Prompt", systemImage: "doc.on.doc.fill")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#0A84FF"), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }

            Text("💡 支援貼上 AI 回傳 JSON，或直接輸入簡寫（如：4弘鈞整 8李弘整 11弘鈞整 15呈弘整）")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))

            HStack(spacing: 8) {
                Button {
                    targetYear = 2026
                    targetMonth = 11
                    manualJSONText = "4弘鈞整 8李弘整 11弘鈞整 15呈弘整"
                    extractedRows = (try? ScheduleJSONParser.parseRows(from: manualJSONText, year: 2026, month: 11)) ?? []
                    statusText = "✅ 已載入 2026 年 11 月班表練習範本（共 \(extractedRows.count) 筆整天班，自動扣休 2 小時）"
                } label: {
                    Text("⚡ 載入11月班表(4天)")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.purple.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(Color(hex: "#BF5AF2"))
                }

                Button {
                    targetYear = 2026
                    targetMonth = 10
                    manualJSONText = "7弘整 11李弘整 14弘鈞整 17UD弘整 21弘整 24弘晚 26弘李整 28鈞弘整"
                    extractedRows = (try? ScheduleJSONParser.parseRows(from: manualJSONText, year: 2026, month: 10)) ?? []
                    statusText = "✅ 已載入 2026 年 10 月班表練習範本（共 \(extractedRows.count) 筆，自動區分假日晚班 17:00-21:00 與整班休2h）"
                } label: {
                    Text("⚡ 載入10月班表(8天)")
                        .font(.system(size: 11, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.25), in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(Color(hex: "#FF9F0A"))
                }
            }

            TextEditor(text: $manualJSONText)
                .font(.system(size: 12, design: .monospaced))
                .frame(height: 110)
                .padding(6)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))

            Button {
                KeyboardDismissManager.dismiss()
                do {
                    extractedRows = try ScheduleJSONParser.parseRows(from: manualJSONText, year: targetYear, month: targetMonth)
                    statusText = "✅ 解析成功，共 \(extractedRows.count) 筆排班（已自動套用早/晚/整平假日時間與休息規則），請於下方核對。"
                } catch {
                    vm.showToast("解析失敗：\(error.localizedDescription)", style: .error)
                }
            } label: {
                Text("解析 JSON / 簡寫代號並預覽")
                    .font(.system(size: 13, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
    }
}
