import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// 添加/编辑连接的表单（iOS 26/27 原生 Liquid Glass 风格）。
struct ConnectionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var app
    @State private var viewModel: ConnectionEditViewModel
    @State private var importing: ConnectionEditViewModel.CertificateKind?

    init(editing: Connection? = nil) {
        _viewModel = State(initialValue: ConnectionEditViewModel(editing: editing))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    serverInfoSection
                    certificateSection

                    if let error = viewModel.validationError {
                        errorCard(error)
                    }
                    if let error = viewModel.certificateError {
                        errorCard(error)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .magpiePageBackground()
            .navigationTitle(viewModel.isEditing ? String(localized: "编辑连接") : String(localized: "添加连接"))
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(
                isPresented: Binding(
                    get: { importing != nil },
                    set: { if !$0 { importing = nil } }
                ),
                allowedContentTypes: [.plainText, .data]
            ) { result in
                defer { importing = nil }
                guard let kind = importing else { return }
                switch result {
                case .success(let url):
                    let secured = url.startAccessingSecurityScopedResource()
                    defer { if secured { url.stopAccessingSecurityScopedResource() } }
                    if let data = try? Data(contentsOf: url) {
                        viewModel.importCertificate(kind: kind, data: data)
                    } else {
                        viewModel.certificateError = String(localized: "无法读取证书文件。")
                    }
                case .failure:
                    break
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            if await viewModel.save(context: context, app: app) {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView().controlSize(.small)
                        } else {
                            Text(String(localized: "保存")).fontWeight(.semibold)
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
    }

    private var serverInfoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "服务器信息"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(MagpieTheme.textMuted)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "tag.fill")
                        .foregroundStyle(MagpieTheme.accent)
                        .frame(width: 22)
                    TextField(String(localized: "名称（如 Home Server / VPS）"), text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                }

                Divider().background(MagpieTheme.borderSubtle)

                HStack(spacing: 12) {
                    Image(systemName: "link")
                        .foregroundStyle(MagpieTheme.cyan)
                        .frame(width: 22)
                    TextField(String(localized: "服务器地址（如 https://mapm.example.com）"), text: $viewModel.urlString)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .onChange(of: viewModel.urlString) { _, newValue in
                            if newValue.contains("?k=") || newValue.contains("&k=") {
                                let (clean, key) = ConnectionEditViewModel.extractCleanURLAndKey(from: newValue)
                                if let key {
                                    viewModel.urlString = clean
                                    viewModel.key = key
                                }
                            }
                        }
                }

                Divider().background(MagpieTheme.borderSubtle)

                HStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .foregroundStyle(MagpieTheme.amber)
                        .frame(width: 22)
                    SecureField(String(localized: "Web Key"), text: $viewModel.key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
            .magpieLiquidCard(padding: 16, cornerRadius: 20)

            Text(viewModel.isEditing
                 ? String(localized: "留空 Web Key 则保持不变。")
                 : String(localized: "可直接粘贴带 ?k= 的完整链接，或分别填写服务器地址与 Web Key。"))
                .font(.caption)
                .foregroundStyle(MagpieTheme.textMuted)
                .padding(.horizontal, 6)
        }
    }

    private var certificateSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(String(localized: "客户端证书（mTLS）"))
                .font(.caption.weight(.semibold))
                .foregroundStyle(MagpieTheme.textMuted)
                .padding(.horizontal, 4)

            VStack(spacing: 12) {
                Text(String(localized: "若服务端在设置中开启了「要求客户端证书」，导入 magpie 签发的三份文件后即可连接。"))
                    .font(.caption)
                    .foregroundStyle(MagpieTheme.textMuted)

                certificateRow(
                    title: "client.pem",
                    isSet: viewModel.clientCertPEM != nil,
                    kind: .clientCert
                )
                Divider().background(MagpieTheme.borderSubtle)
                certificateRow(
                    title: "client-key.pem",
                    isSet: viewModel.clientKeyPEM != nil,
                    kind: .clientKey
                )
                Divider().background(MagpieTheme.borderSubtle)
                certificateRow(
                    title: "ca.pem",
                    isSet: viewModel.caPEM != nil,
                    kind: .ca
                )

                if viewModel.hasAnyCertificate {
                    Button(role: .destructive) {
                        viewModel.clearCertificates()
                    } label: {
                        Text(String(localized: "移除客户端证书"))
                            .font(.subheadline)
                    }
                }
            }
            .magpieLiquidCard(padding: 16, cornerRadius: 20)
        }
    }

    private func certificateRow(title: String, isSet: Bool, kind: ConnectionEditViewModel.CertificateKind) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSet ? "checkmark.circle.fill" : "doc.badge.plus")
                .foregroundStyle(isSet ? MagpieTheme.green : MagpieTheme.textMuted)
                .frame(width: 22)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
            Button(String(localized: isSet ? "重新导入" : "导入")) {
                importing = kind
            }
            .buttonStyle(.borderless)
            .tint(MagpieTheme.accent)
        }
    }

    private func errorCard(_ error: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(MagpieTheme.red)
            Text(error)
                .font(.subheadline)
                .foregroundStyle(MagpieTheme.red)
            Spacer()
        }
        .magpieLiquidCard(padding: 14, cornerRadius: 16, tint: MagpieTheme.red.opacity(0.1))
    }
}
