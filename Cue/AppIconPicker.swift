import SwiftUI
import UIKit

private enum CueAppIcon: String, CaseIterable, Identifiable, Sendable {
    case cobalt
    case midnight
    case plum
    case ivory

    var id: Self { self }

    var alternateName: String? {
        switch self {
        case .cobalt: nil
        case .midnight: "AppIconMidnight"
        case .plum: "AppIconPlum"
        case .ivory: "AppIconIvory"
        }
    }

    var previewAsset: String {
        switch self {
        case .cobalt: "PreviewCobalt"
        case .midnight: "PreviewMidnight"
        case .plum: "PreviewPlum"
        case .ivory: "PreviewIvory"
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .cobalt: "코발트"
        case .midnight: "미드나이트"
        case .plum: "플럼"
        case .ivory: "아이보리"
        }
    }
}

struct AppIconPickerSection: View {
    @State private var selectedName: String?
    @State private var errorMessage: String?

    init() {
        _selectedName = State(initialValue: UIApplication.shared.alternateIconName)
    }

    var body: some View {
        Section {
            if UIApplication.shared.supportsAlternateIcons {
                HStack(spacing: 12) {
                    ForEach(CueAppIcon.allCases) { icon in
                        Button {
                            select(icon)
                        } label: {
                            VStack(spacing: 6) {
                                Image(icon.previewAsset)
                                    .resizable()
                                    .scaledToFit()
                                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                                    .overlay(alignment: .topTrailing) {
                                        if selectedName == icon.alternateName {
                                            Image(systemName: "checkmark.circle.fill")
                                                .symbolRenderingMode(.palette)
                                                .foregroundStyle(.white, .blue)
                                                .background(Circle().fill(.white))
                                                .offset(x: 5, y: -5)
                                        }
                                    }
                                    .frame(width: 56, height: 56)
                                Text(icon.title)
                                    .font(.caption2)
                                    .foregroundStyle(.primary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(selectedName == icon.alternateName ? .isSelected : [])
                    }
                }
                .padding(.vertical, 4)
            } else {
                Text("이 기기에서는 대체 앱 아이콘을 지원하지 않습니다.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("앱 아이콘")
        } footer: {
            Text("선택한 아이콘은 홈 화면과 검색 결과에 적용됩니다.")
        }
        .alert("아이콘을 변경할 수 없습니다", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("확인", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func select(_ icon: CueAppIcon) {
        guard selectedName != icon.alternateName else { return }
        UIApplication.shared.setAlternateIconName(icon.alternateName) { error in
            Task { @MainActor in
                if let error {
                    errorMessage = error.localizedDescription
                } else {
                    selectedName = icon.alternateName
                }
            }
        }
    }
}
