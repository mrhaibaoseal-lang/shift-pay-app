import SwiftUI

extension ScheduleTabView {

    var stampToolbarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("常用班別印章（點選後點月曆即可快速蓋章）", systemImage: "stamp.fill")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                Spacer()
                Button {
                    HapticsManager.shared.lightTap()
                    vm.showStampManager = true
                } label: {
                    Label("管理班別", systemImage: "slider.horizontal.3")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: "#0A84FF"))
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(vm.state.stamps) { stamp in
                        let isSelected = (vm.activeStampId == stamp.id)
                        Button {
                            HapticsManager.shared.lightTap()
                            withAnimation(.spring(response: 0.25)) {
                                vm.activeStampId = isSelected ? nil : stamp.id
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Circle().fill(Color(hex: stamp.color)).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(stamp.name).font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                    Text("\(stamp.start)-\(stamp.end)").font(.system(size: 10)).monospacedDigit().foregroundStyle(.white.opacity(0.55))
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14).stroke(isSelected ? Color(hex: stamp.color) : .white.opacity(0.08), lineWidth: isSelected ? 2 : 1))
                        }
                    }

                    let isEraser = (vm.activeStampId == "clear")
                    Button {
                        HapticsManager.shared.lightTap()
                        withAnimation(.spring(response: 0.25)) {
                            vm.activeStampId = isEraser ? nil : "clear"
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "eraser.fill").font(.system(size: 13)).foregroundStyle(Color(hex: "#FF453A"))
                            VStack(alignment: .leading, spacing: 1) {
                                Text("橡皮擦").font(.system(size: 13, weight: .bold)).foregroundStyle(.white)
                                Text("點日期清除").font(.system(size: 10)).foregroundStyle(.white.opacity(0.5))
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#1C1C1E"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(isEraser ? Color(hex: "#FF453A") : .white.opacity(0.08), lineWidth: isEraser ? 2 : 1))
                    }
                }
            }
        }
    }
}
