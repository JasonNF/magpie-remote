import SwiftUI

/// 账户组编辑器（官方 `/api/account-groups`）：一组跨 Provider 的账号集合，
/// Key 的账号菜单里可以 "@id" 引用；重命名/成员/删除即时保存。
struct GatewayAccountGroupsSheet: View {
    let viewModel: GatewayViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var app
    @State private var groups: [GatewayAccountGroupDTO] = []
    @State private var newName = ""
    @State private var errorMessage: String?
    @State private var primed = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                        accountGroupRow(group, index: index)
                    }

                    if groups.isEmpty {
                        Text(String(localized: "还没有账户组；在下方新建一个。"))
                            .font(.caption)
                            .foregroundStyle(MagpieTheme.textMuted)
                    }
                } footer: {
                    Text(String(localized: "账户组是账号的命名集合；网关 Key 的账号菜单里可用 @组ID 引用。"))
                }

                Section {
                    HStack(spacing: 8) {
                        TextField(String(localized: "新账户组名称"), text: $newName)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button(String(localized: "添加")) {
                            createGroup()
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(MagpieTheme.accent)
                        .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(MagpieTheme.red)
                    }
                }
            }
            .navigationTitle(String(localized: "账户组"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "完成")) { dismiss() }
                }
            }
            .task {
                guard !primed else { return }
                primed = true
                if let client = app.client {
                    await viewModel.loadAccountGroups(client: client)
                }
                groups = viewModel.accountGroups
            }
            .onChange(of: viewModel.accountGroups) { _, newValue in
                groups = newValue
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func accountGroupRow(_ group: GatewayAccountGroupDTO, index: Int) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(MagpieTheme.accent)
                .frame(width: 26, height: 26)
                .background(MagpieTheme.accentSoft, in: RoundedRectangle(cornerRadius: 7, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(group.displayName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MagpieTheme.textPrimary)
                Text(group.accounts.isEmpty
                    ? String(localized: "没有账号")
                    : group.accounts.count == 1
                        ? group.accounts[0]
                        : String(localized: "\(group.accounts.count) 个账号"))
                    .font(.caption2)
                    .foregroundStyle(MagpieTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Menu {
                ForEach(viewModel.accounts) { account in
                    Button {
                        toggleAccount(group, account)
                    } label: {
                        HStack(spacing: 8) {
                            Text(account.displayName)
                            if group.accounts.contains(account.id) {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Text(group.accounts.isEmpty ? String(localized: "选账号") : "\(group.accounts.count)")
                        .font(.caption.weight(.semibold))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundStyle(group.accounts.isEmpty ? MagpieTheme.textSecondary : MagpieTheme.accent)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(MagpieTheme.pill, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            Button {
                deleteGroup(group)
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 12))
                    .foregroundStyle(MagpieTheme.red.opacity(0.85))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 3)
    }

    private func createGroup() {
        guard let client = app.client else { return }
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        Task {
            let ok = await viewModel.saveAccountGroup(
                client: client,
                id: nil,
                name: name,
                accounts: []
            )
            if ok { newName = "" }
            else { errorMessage = viewModel.errorMessage }
        }
    }

    private func deleteGroup(_ group: GatewayAccountGroupDTO) {
        guard let client = app.client else { return }
        Task {
            let ok = await viewModel.removeAccountGroup(client: client, id: group.id)
            if !ok { errorMessage = viewModel.errorMessage }
        }
    }

    private func toggleAccount(_ group: GatewayAccountGroupDTO, _ account: GatewayModelDTO) {
        guard let client = app.client else { return }
        var accounts = group.accounts
        if let index = accounts.firstIndex(where: { $0.caseInsensitiveCompare(account.id) == .orderedSame }) {
            accounts.remove(at: index)
        } else {
            accounts.append(account.id)
        }
        Task {
            let ok = await viewModel.saveAccountGroup(
                client: client,
                id: group.id,
                name: group.name,
                accounts: accounts
            )
            if !ok { errorMessage = viewModel.errorMessage }
        }
    }
}
