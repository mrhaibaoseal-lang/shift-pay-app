import SwiftUI

extension MainRootView {

    var topHeaderBar: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(LinearGradient(colors: [Color(hex: "#0A84FF"), Color(hex: "#5E5CE6")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 36, height: 36)
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("打工薪水帳")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                        Text("iOS 27 原生版")
                            .font(.system(size: 10, weight: .bold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.22), in: Capsule())
                            .foregroundStyle(Color(hex: "#64D2FF"))
                    }
                    Text("\(vm.state.settings.myName)・\(vm.state.settings.aiProvider.shortBadge)")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Spacer()
            Button {
                HapticsManager.shared.lightTap()
                vm.showPhotoImportSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 14, weight: .bold))
                    Text("拍班表匯入")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    LinearGradient(colors: [Color(hex: "#0A84FF"), Color(hex: "#BF5AF2")], startPoint: .leading, endPoint: .trailing),
                    in: Capsule()
                )
                .foregroundStyle(.white)
            }
        }
    }

    var sharedMonthSwitcher: some View {
        HStack(spacing: 10) {
            Button { vm.changeMonth(delta: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.1), in: Circle())
                    .foregroundStyle(.white)
            }
            Spacer()
            HStack(spacing: 8) {
                Text("\(String(vm.viewYear)) 年 \(vm.viewMonth) 月")
                    .font(.system(size: 18, weight: .heavy))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                Button { vm.jumpToToday() } label: {
                    Text("今天")
                        .font(.system(size: 12, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.1), in: Capsule())
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            Spacer()
            Button { vm.changeMonth(delta: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 38, height: 38)
                    .background(.white.opacity(0.1), in: Circle())
                    .foregroundStyle(.white)
            }
        }
        .contentShape(Rectangle())
        .horizontalMonthSwipe(vm: vm)
    }
}

public extension View {
    func horizontalMonthSwipe(vm: ShiftPayViewModel) -> some View {
        self.simultaneousGesture(
            DragGesture(minimumDistance: 28, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    guard abs(dx) > abs(dy) * 1.35, abs(dx) > 42 else { return }
                    if dx < 0 {
                        vm.changeMonth(delta: 1)
                    } else {
                        vm.changeMonth(delta: -1)
                    }
                }
        )
    }
}
