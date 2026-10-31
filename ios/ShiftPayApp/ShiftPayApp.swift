import SwiftUI

@main
struct ShiftPayApp: App {
    @State private var viewModel = ShiftPayViewModel()

    var body: some Scene {
        WindowGroup {
            MainRootView(vm: viewModel)
                .preferredColorScheme(.dark)
        }
    }
}

struct MainRootView: View {
    @Bindable var vm: ShiftPayViewModel

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                topHeaderBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)

                if vm.activeTab == .schedule || vm.activeTab == .bill {
                    sharedMonthSwitcher
                        .padding(.horizontal, 16)
                        .padding(.bottom, 10)
                }

                TabContentContainer(vm: vm)
            }

            if vm.activeStampId != nil && vm.activeTab == .schedule {
                stampModeFloatingBar
                    .padding(.bottom, 78)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            liquidGlassTabBar

            if let toast = vm.toastMessage {
                toastOverlay(text: toast, style: vm.toastStyle)
                    .padding(.bottom, 128)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .sheet(item: Binding(
            get: { vm.editingDateKey.map { EditingDateWrapper(dateKey: $0) } },
            set: { vm.editingDateKey = $0?.dateKey }
        )) { item in
            DayEditorSheet(vm: vm, dateKey: item.dateKey)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.showStampManager) {
            StampManagerSheet(vm: vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $vm.showPhotoImportSheet) {
            PhotoImportSheet(vm: vm)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

struct EditingDateWrapper: Identifiable {
    let dateKey: String
    var id: String { dateKey }
}
