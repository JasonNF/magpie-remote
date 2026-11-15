import SwiftUI

/// 可搜索的模型/字段选择器（全局复用）。点选项即写入，支持输入列表外的自定义值。
struct ModelPickerView: View {
    let agentID: String
    let fieldKey: String

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel = AgentsViewModel()
    @State private var searchText = ""

    private var agent: AgentDTO? { app.state?.agents.first { $0.id == agentID } }
    private var field: FieldDTO? { agent?.fields.first { $0.key == fieldKey } }
    private var options: [ModelOption] {
        guard let field, let state = app.state else { return [] }
        return state.options(for: field)
    }

    private var filtered: [ModelOption] {
        guard !searchText.isEmpty else { return options }
        let query = searchText.lowercased()
        return options.filter {
            $0.value.lowercased().contains(query)
                || ($0.label?.lowercased().contains(query) ?? false)
        }
    }

    /// 输入了列表中不存在的值时，提供「使用自定义值」入口。
    private var customValue: String? {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let exact = options.contains { $0.value == trimmed }
        return exact ? nil : trimmed
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if let error = viewModel.saveError {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                    }
                    .font(.subheadline)
                    .foregroundStyle(MagpieTheme.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .magpieCard()
                }

                if let customValue {
                    Button {
                        select(customValue)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(MagpieTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(String(localized: "使用输入值"))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(MagpieTheme.textPrimary)
                                Text(customValue)
                                    .font(.caption)
                                    .foregroundStyle(MagpieTheme.accent)
                            }
                            Spacer()
                        }
                        .magpieCard()
                    }
                    .buttonStyle(.plain)
                }

                // 选项列表
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, option in
                        Button {
                            select(option.value)
                        } label: {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(option.displayName)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(option.value == field?.value ? MagpieTheme.accent : MagpieTheme.textPrimary)

                                    if !option.value.isEmpty && option.label != nil {
                                        Text(option.value)
                                            .font(.system(size: 11, design: .monospaced))
                                            .foregroundStyle(MagpieTheme.textMuted)
                                    }
                                    if let note = option.note {
                                        Text(note)
                                            .font(.caption2)
                                            .foregroundStyle(MagpieTheme.textSecondary)
                                    }
                                }
                                Spacer()
                                if option.value == field?.value {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(MagpieTheme.accent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(option.value == field?.value ? MagpieTheme.accentSoft.opacity(0.3) : Color.clear)
                        }
                        .buttonStyle(.plain)

                        if index < filtered.count - 1 {
                            Divider()
                                .background(MagpieTheme.borderSubtle)
                        }
                    }
                }
                .magpieCard(padding: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .magpiePageBackground()
        .searchable(text: $searchText, prompt: String(localized: "搜索模型或配置…"))
        .navigationTitle(field?.label ?? String(localized: "选择模型"))
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isSaving {
                ProgressView(String(localized: "正在应用…"))
                    .padding(20)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func select(_ value: String) {
        guard let client = app.client else { return }
        Task {
            if await viewModel.pick(client: client, app: app, agentID: agentID, fieldKey: fieldKey, value: value) {
                dismiss()
            }
        }
    }
}
