import SwiftUI

extension MainRootView {

    @ViewBuilder
    var stampModeFloatingBar: some View {
        let isClear = (vm.activeStampId == "clear")
        let stamp = vm.state.stamps.first { $0.id == vm.activeStampId }
        HStack(spacing: 10) {
            Circle()
                .fill(isClear ? Color.red : Color(hex: stamp?.color ?? "#0A84FF"))
                .frame(width: 24, height: 24)
                .overlay {
                    Image(systemName: isClear ? "eraser.fill" : "stamp.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                }
            Text(isClear ? "橡皮擦模式：點選月曆日期即可清除排班" : "蓋章模式：點選月曆蓋上「\(stamp?.name ?? "")」")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
            Button {
                withAnimation(.spring(response: 0.25)) {
                    vm.activeStampId = nil
                }
            } label: {
                Text("完成")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white, in: Capsule())
                    .foregroundStyle(.black)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.15), lineWidth: 1))
        .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
    }

    var liquidGlassTabBar: some View {
        HStack(spacing: 0) {
            tabBarItem(tab: .schedule, icon: "calendar", title: "排班")
            tabBarItem(tab: .bill, icon: "filemenu.and.selection", title: "帳單")
            tabBarItem(tab: .tools, icon: "alarm.waves.left.and.right.fill", title: "鬧鐘與小工具")
            tabBarItem(tab: .settings, icon: "slider.horizontal.3", title: "設定")
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider().background(.white.opacity(0.12))
        }
    }

    private func tabBarItem(tab: ShiftPayViewModel.AppTab, icon: String, title: String) -> some View {
        let selected = (vm.activeTab == tab)
        return Button {
            KeyboardDismissManager.dismiss()
            HapticsManager.shared.lightTap()
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                vm.activeTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: selected ? .bold : .medium))
                    .scaleEffect(selected ? 1.08 : 1.0)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(selected ? Color(hex: "#0A84FF") : .white.opacity(0.42))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    func toastOverlay(text: String, style: ShiftPayViewModel.ToastStyle) -> some View {
        let borderColor: Color = {
            switch style {
            case .normal: return .white.opacity(0.18)
            case .success: return Color.green.opacity(0.5)
            case .warning: return Color.orange.opacity(0.5)
            case .error: return Color.red.opacity(0.5)
            }
        }()
        return Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(hex: "#2C2C2E").opacity(0.95), in: Capsule())
            .overlay(Capsule().stroke(borderColor, lineWidth: 1))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)
    }
}

struct TabContentContainer: View {
    @Bindable var vm: ShiftPayViewModel

    var body: some View {
        Group {
            switch vm.activeTab {
            case .schedule:
                ScheduleTabView(vm: vm)
            case .bill:
                BillTabView(vm: vm)
            case .tools:
                ToolsTabView(vm: vm)
            case .settings:
                SettingsTabView(vm: vm)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
