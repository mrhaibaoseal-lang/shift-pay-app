import SwiftUI

extension SettingsTabView {

    var aiEngineConfigCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("iOS 27 FoundationModels 與多模態 AI 設定", systemImage: "sparkles")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 4) {
                Text("班表上的我的姓名（AI 將鎖定此姓名列）").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                TextField("王凱弘", text: $vm.state.settings.myName)
                    .submitLabel(.done)
                    .padding(10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: vm.state.settings.myName) { _, _ in vm.save() }
            }

            ForEach(AIProviderTier.allCases) { tier in
                let selected = (vm.state.settings.aiProvider == tier)
                Button {
                    KeyboardDismissManager.dismiss()
                    vm.state.settings.aiProvider = tier
                    HapticsManager.shared.lightTap()
                    vm.save()
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? Color(hex: "#0A84FF") : .white.opacity(0.35))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tier.title).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                            Text(tier.subtitle).font(.system(size: 11)).foregroundStyle(.white.opacity(0.5)).multilineTextAlignment(.leading)
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(selected ? Color.blue.opacity(0.15) : .white.opacity(0.04), in: RoundedRectangle(cornerRadius: 12))
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Gemini API Key（選填，儲存在本機 Keychain）").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                SecureField("貼上 Google AI Studio API Key", text: $vm.state.settings.apiKey)
                    .submitLabel(.done)
                    .padding(10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: vm.state.settings.apiKey) { _, _ in vm.save() }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("AI 模型名稱（預設 gemini-3.8-flash，可隨時自訂）").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                TextField("gemini-3.8-flash", text: $vm.state.settings.aiModel)
                    .submitLabel(.done)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: vm.state.settings.aiModel) { _, _ in vm.save() }

                HStack(spacing: 6) {
                    ForEach(["gemini-3.8-flash", "gemini-2.5-flash", "claude-sonnet-4-6"], id: \.self) { preset in
                        Button {
                            KeyboardDismissManager.dismiss()
                            vm.state.settings.aiModel = preset
                            vm.save()
                        } label: {
                            Text(preset)
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("店家手寫代號對照（ShiftRuleLookupTool 規則）").font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                TextField("例如：A=09:00-17:00、晚=18:00-22:00", text: $vm.state.settings.codeHints)
                    .submitLabel(.done)
                    .padding(10)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                    .onChange(of: vm.state.settings.codeHints) { _, _ in vm.save() }
            }
        }
        .padding(16)
        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
