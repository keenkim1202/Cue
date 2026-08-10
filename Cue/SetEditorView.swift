import SwiftUI

struct SetEditorView: View {
    @ObservedObject var model: CueViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(model.config.sets) { set in
                    Section {
                        NavigationLink {
                            ActionListView(model: model, setID: set.id)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(set.name)
                                Text("\(set.actions.count)개 액션")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if model.config.sets.count > 1 {
                            Button("세트 삭제", role: .destructive) {
                                model.deleteSet(set)
                            }
                        }
                    }
                }
                Section {
                    Button("세트 추가", systemImage: "plus", action: model.addSet)
                        .accessibilityIdentifier(CueID.addSet)
                }
            }
            .navigationTitle("세트 편집")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("완료") { dismiss() }
                        .accessibilityIdentifier(CueID.doneEditing)
                }
            }
        }
    }
}

// MARK: - 세트 안의 액션 목록

private struct ActionListView: View {
    @ObservedObject var model: CueViewModel
    let setID: UUID

    private var set: CueSet? {
        model.config.sets.first { $0.id == setID }
    }

    /// `.openURL` 액션의 주소를 세트에 되쓰는 바인딩.
    private func urlBinding(for action: CueAction, in set: CueSet) -> Binding<String> {
        Binding(
            get: { action.urlString },
            set: { newValue in
                var updated = set
                guard let index = updated.actions.firstIndex(where: { $0.id == action.id }) else { return }
                updated.actions[index].urlString = newValue
                model.update(updated)
            }
        )
    }

    var body: some View {
        List {
            if let set {
                Section("이름") {
                    TextField("세트 이름", text: Binding(
                        get: { set.name },
                        set: { newValue in
                            var updated = set
                            updated.name = newValue
                            model.update(updated)
                        }
                    ))
                }

                Section {
                    ForEach(set.actions) { action in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 12) {
                                Image(systemName: action.symbol)
                                    .frame(width: 24)
                                    .foregroundStyle(.tint)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(action.title)
                                    Text(action.kind.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            if action.kind == .openURL {
                                TextField("https://example.com", text: urlBinding(for: action, in: set))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.URL)
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        var updated = set
                        updated.actions.remove(atOffsets: offsets)
                        model.update(updated)
                    }
                    .onMove { source, destination in
                        var updated = set
                        updated.actions.move(fromOffsets: source, toOffset: destination)
                        model.update(updated)
                    }
                } header: {
                    Text("순환 순서")
                } footer: {
                    Text("액션 버튼을 누를 때 이 순서대로 넘어갑니다. 끌어서 순서를 바꿀 수 있습니다.")
                }

                Section {
                    ForEach(CueAction.Kind.allCases, id: \.self) { kind in
                        Button {
                            var updated = set
                            updated.actions.append(CueAction(
                                title: kind.label,
                                symbol: kind.defaultSymbol,
                                kind: kind
                            ))
                            model.update(updated)
                        } label: {
                            Label(kind.label, systemImage: kind.defaultSymbol)
                        }
                    }
                } header: {
                    Text("액션 추가")
                } footer: {
                    Text("링크 열기는 https 주소만 됩니다. 커스텀 스킴은 iOS가 거부합니다.")
                }
            }
        }
        .navigationTitle(set?.name ?? "세트")
        .toolbar { EditButton() }
    }
}
