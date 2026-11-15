import SwiftUI
import SwiftData

/// 添加/编辑连接的表单（sheet）。
struct ConnectionEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(AppModel.self) private var app
    @State private var viewModel: ConnectionEditViewModel

    init(editing: Connection? = nil) {
        _viewModel = State(initialValue: ConnectionEditViewModel(editing: editing))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(String(localized: "名称"), text: $viewModel.name)
                        .textInputAutocapitalization(.words)
                    TextField(String(localized: "服务器地址"), text: $viewModel.urlString)
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
                    SecureField(String(localized: "Web Key"), text: $viewModel.key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } footer: {
                    Text(viewModel.isEditing
                         ? String(localized: "留空 Web Key 则保持不变。")
                         : String(localized: "可直接粘贴带 ?k= 的完整链接，或分别填写服务器地址与 Web Key。"))
                }

                if let error = viewModel.validationError {
                    Section {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(viewModel.isEditing ? String(localized: "编辑连接") : String(localized: "添加连接"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "取消")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "保存")) {
                        Task {
                            if await viewModel.save(context: context, app: app) {
                                dismiss()
                            }
                        }
                    }
                    .disabled(viewModel.isSaving)
                }
            }
            .scrollContentBackground(.hidden)
            .background(MagpieAuroraBackground())
            .overlay {
                if viewModel.isSaving { ProgressView() }
            }
        }
    }
}