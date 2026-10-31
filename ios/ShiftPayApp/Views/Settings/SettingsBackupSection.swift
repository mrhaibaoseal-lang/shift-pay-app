import SwiftUI

extension SettingsTabView {

    var backupAndMigrationCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("資料備份 & Web V2 無痛搬家中心", systemImage: "externaldrive.fill.badge.icloud")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            Text("100% 相容你原本網頁版 (shiftpay.v1) 的備份 JSON！複製網頁版備份後點下方「匯入 Web/JSON 備份」即可一秒搬家。")
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.5))

            HStack(spacing: 8) {
                Button {
                    let json = SharedStore.shared.exportWebCompatibleJSON(state: vm.state)
                    UIPasteboard.general.string = json
                    HapticsManager.shared.success()
                    vm.showToast("✅ 已複製完整備份 JSON 至剪貼簿！", style: .success)
                } label: {
                    Label("匯出備份至剪貼簿", systemImage: "doc.on.doc.fill")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(hex: "#0A84FF"), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }

                Button {
                    importJSONText = UIPasteboard.general.string ?? ""
                    showImportJSONSheet = true
                } label: {
                    Label("匯入 Web/JSON 備份", systemImage: "square.and.arrow.down")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(16)
        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    var importBackupJSONModal: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Text("請貼上從 Web 版或原生版匯出的 JSON 備份內容：")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.7))
                TextEditor(text: $importJSONText)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(8)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                Button {
                    do {
                        let imported = try SharedStore.shared.importFromJSONString(importJSONText)
                        vm.state = imported
                        vm.save()
                        HapticsManager.shared.success()
                        vm.showToast("🎉 備份匯入成功！共載入 \(imported.shifts.count) 筆班表", style: .success)
                        showImportJSONSheet = false
                    } catch {
                        vm.showToast("匯入失敗：\(error.localizedDescription)", style: .error)
                    }
                } label: {
                    Text("確認還原備份")
                        .font(.system(size: 15, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color(hex: "#30D158"), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.black)
                }
            }
            .padding(16)
            .background(Color(hex: "#1C1C1E").ignoresSafeArea())
            .navigationTitle("匯入 JSON 備份")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
