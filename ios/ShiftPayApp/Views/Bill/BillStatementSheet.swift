import SwiftUI

struct BillStatementSheet: View {
    @Bindable var vm: ShiftPayViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let comp = vm.currentMonthComputation
        let s = vm.state.settings

        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statementRenderableView(comp: comp, settings: s)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    Button {
                        saveStatementImageToPhotos(comp: comp, settings: s)
                    } label: {
                        Label("儲存高清對帳單長圖至相簿", systemImage: "square.and.arrow.down.fill")
                            .font(.system(size: 15, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "#0A84FF"), in: RoundedRectangle(cornerRadius: 16))
                            .foregroundStyle(.white)
                    }
                }
                .padding(16)
            }
            .background(Color(hex: "#1C1C1E").ignoresSafeArea())
            .navigationTitle("🧾 月底薪資核對單")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    private func statementRenderableView(comp: PayrollEngine.MonthComputation, settings: PayrollSettings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(vm.viewYear)) 年 \(vm.viewMonth) 月・打工薪資核對單")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.gray)
                    Text("\(settings.myName)")
                        .font(.system(size: 22, weight: .heavy))
                        .foregroundStyle(.black)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("應領總額").font(.system(size: 11)).foregroundStyle(.gray)
                    Text(PayrollEngine.formatMoney(comp.total))
                        .font(.system(size: 26, weight: .heavy))
                        .monospacedDigit()
                        .foregroundStyle(Color(hex: "#0A84FF"))
                }
            }

            Divider()

            ForEach(comp.rows) { row in
                HStack {
                    Text("\(row.month)/\(row.day)(\(row.weekdayText))")
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.black)
                        .frame(width: 66, alignment: .leading)
                    Text("\(row.shift.start)-\(row.shift.end)")
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.black.opacity(0.8))
                    Spacer()
                    Text("\(PayrollEngine.formatHours(row.normalMin))h\(row.otMin > 0 ? " +\(row.otMin)m" : "")")
                        .font(.system(size: 12))
                        .monospacedDigit()
                        .foregroundStyle(.gray)
                    Text(PayrollEngine.formatMoneySmart(row.totalDayPay))
                        .font(.system(size: 12, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(.black)
                        .frame(width: 68, alignment: .trailing)
                }
            }

            Divider()

            HStack {
                Text("基本工時 (\(PayrollEngine.formatHours(comp.normalMinTotal))h)：\(PayrollEngine.formatMoney(comp.normalPay))")
                Spacer()
                Text("加班 (\(comp.otMinTotal)m)：\(PayrollEngine.formatMoney(comp.otPay))")
                Spacer()
                Text("全勤：\(PayrollEngine.formatMoney(comp.bonus))")
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.black.opacity(0.75))
        }
        .padding(18)
        .background(Color.white)
    }

    @MainActor
    private func saveStatementImageToPhotos(comp: PayrollEngine.MonthComputation, settings: PayrollSettings) {
        let viewToRender = statementRenderableView(comp: comp, settings: settings)
            .frame(width: 375)
        let renderer = ImageRenderer(content: viewToRender)
        renderer.scale = 3.0
        if let uiImage = renderer.uiImage {
            UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
            HapticsManager.shared.success()
            vm.showToast("📸 已將高清對帳單長圖儲存至 iPhone 相簿！", style: .success)
        }
    }
}
