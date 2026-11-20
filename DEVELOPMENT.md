# Magpie Remote 二次开发指南 (Development Guide)

欢迎参与 **Magpie Remote** 的二次开发！本文档旨在为所有希望对本项目进行功能定制、新特性扩展或提交 PR 贡献的开发者提供一份完整、易懂且专业的实战指南。

---

## 1. 架构总览

Magpie Remote 严格遵循现代化 **SwiftUI + MVVM + Observation** 架构，并坚持 **0 外部第三方库依赖** 的纯原生原则，以追求极小的安装包体积与极致的 120Hz 原生性能体验。

### 核心分层设计

```text
┌────────────────────────────────────────────────────────┐
│                      Views (视图层)                     │
│  - 纯 SwiftUI 声明式构建，遵循 Apple HIG 设计范式            │
│  - 负责页面渲染、动画呈现与用户事件捕获                      │
└───────────────────────────┬────────────────────────────┘
                            │ 双向绑定 / Action 触发
┌───────────────────────────▼────────────────────────────┐
│                    ViewModels (业务逻辑层)               │
│  - 使用 Swift @Observable 宏与 @MainActor               │
│  - 维护模块局部状态 (loading, error, list, draft)        │
└───────────────────────────┬────────────────────────────┘
                            │ 异步调用 (async/await)
┌───────────────────────────▼────────────────────────────┐
│                 MagpieAPIClient (网络与数据源)           │
│  - 基于原生 URLSession 与 HTTPCookieStorage 封装        │
│  - 自动处理服务端 Session 鉴权、401 自动重登录与错误映射    │
└───────────────────────────┬────────────────────────────┘
                            │ KeychainStore / Keychain
┌───────────────────────────▼────────────────────────────┐
│              Apple Keychain (凭据持久化层)              │
│  - 按连接保存 Web Key 与客户端证书材料                │
└────────────────────────────────────────────────────────┘
```

读取旧版连接时会迁移偏好设置中的 Web Key，确认钥匙串可用后清除明文副本。模拟器联调用 `MAGPIE_DEV_URL` 和 `MAGPIE_DEV_KEY` 提供连接凭据。

---

## 2. 开发环境准备

| 项目 | 要求 | 说明 |
| :--- | :--- | :--- |
| **操作系统** | macOS Sequoia (15.0+) | 推荐最新 macOS 环境 |
| **IDE** | Xcode 27.0+ (支持 iOS 26.0+ SDK) | 推荐使用当前官方稳定或候选版本 |
| **语言规范** | Swift 6.4 | 开启 Swift 严格并发检查模式 |
| **项目管理工具** | [XcodeGen](https://github.com/yonaskolb/XcodeGen) 2.40+ | 用于从 `project.yml` 声明式生成工程文件 |

### 快速初始化工程
```bash
# 1. 克隆代码仓库
git clone https://github.com/your-username/magpie-remote.git
cd magpie-remote

# 2. 安装 XcodeGen（如尚未安装）
brew install xcodegen

# 3. 声明式生成 .xcodeproj 工程
xcodegen generate

# 4. 双击打开工程进行开发
open MagpieRemote.xcodeproj
```

> **注意**：本项目使用 `project.yml` 集中管理工程配置与依赖关系，`.xcodeproj` 不会被提交到 Git 仓库。每次新增、删除文件或调整资源后，仅需运行 `xcodegen generate` 即可重新同步工程树。

---

## 3. 模块目录结构

```text
MagpieRemote/
├── App/                      # 应用程序入口与主导航
│   ├── MagpieRemoteApp.swift # @main 生命周期
│   ├── RootView.swift        # 路由分发器（未配置 -> 连接列表；已连接 -> 工作台）
│   ├── MainTabView.swift     # iPhone 浮动底栏与 iPad 多列侧边栏导航容器
│   └── MoreFanMenu.swift     # 以「更多」按钮为锚点的扇形菜单
├── Core/                     # 核心公用能力与基础设施
│   ├── Design/               # 官方设计系统与组件库
│   │   ├── MagpieTheme.swift       # Apple 原生语义色彩标准系统
│   │   ├── MagpieLiquidGlass.swift # 分层液态玻璃 (Liquid Glass) 与卡片修饰器
│   │   ├── MagpieVisuals.swift     # 状态胶囊 (StatusChip)、通用指示器与徽章
│   │   └── MagpieLogoView.swift    # 品牌矢量 Logo
│   ├── Models/               # RESTful API 交互数据模型 (Codable DTOs)
│   ├── Networking/           # 原生网络通信层
│   │   ├── MagpieAPIClient.swift   # 网络核心客户端
│   │   ├── Endpoint.swift          # 服务端路由定义
│   │   └── APIError.swift          # 统一业务与传输错误抽象
│   └── Stores/               # 全局持久化状态与上下文
│       ├── AppModel.swift          # @Observable 全局连接状态与当前选定服务器
│       └── KeychainStore.swift      # 系统 Keychain 密钥安全存储
├── Features/                 # 核心业务特性（高度自聚拢，按功能拆分模块）
│   ├── Agents/               # 智能体路由设置、模型清单与 Profiles 方案
│   ├── Providers/            # 模型供应商、多 Key 轮询与连通性诊断
│   ├── Groups/               # 智能路由组、策略配置与优先级
│   ├── Usage/                # 费用与 Token 账本、配额刷新与一键签到
│   ├── Sessions/             # 历史对话记录、Transcript 与回收站管理
│   ├── Routing/              # 历史路由、游标长轮询和按实际尝试更新的决策舞台
│   ├── Gateway/              # 网关令牌、限流窗口与时间窗口配额
│   ├── Masking/              # 敏感字段脱敏沙盒与拦截历史
│   ├── Library/              # Skills、MCP 工具服务与 Memory 记忆库
│   ├── Plugins/              # 第三方插件与 NPM Registry
│   ├── Connection/           # 实例配置、连通性检查与多服务器切换
│   ├── Settings/             # 全局首选项、OTLP 遥测与备份导出
│   └── More/                 # 扩展功能中心
└── Resources/                # 静态资产与本地化多语言 (Localizable.xcstrings)
```

---

## 4. 如何扩展新功能模块（实战示例）

假设你需要增加一个新的特性页面 `AnalyticsView`，请遵循以下标准流程：

### 第一步：在 `Core/Models/` 中定义数据模型 (DTO)
```swift
import Foundation

public struct AnalyticsMetricDTO: Identifiable, Codable, Sendable {
    public let id: String
    public let timestamp: TimeInterval
    public let requestCount: Int
    public let latencyMs: Double
}
```

### 第二步：在 `Core/Networking/Endpoint.swift` 注册 API 端点
```swift
extension Endpoint {
    static var analyticsSummary: Endpoint {
        Endpoint(path: "/api/analytics/summary", method: .get)
    }
}
```

### 第三步：编写业务 ViewModel
```swift
import SwiftUI
import Observation

@Observable
@MainActor
public final class AnalyticsViewModel {
    public var metrics: [AnalyticsMetricDTO] = []
    public var isLoading: Bool = false
    public var errorMessage: String? = nil

    private let apiClient: MagpieAPIClient

    public init(apiClient: MagpieAPIClient) {
        self.apiClient = apiClient
    }

    public func fetchMetrics() async {
        isLoading = true
        errorMessage = nil
        do {
            let data: [AnalyticsMetricDTO] = try await apiClient.request(.analyticsSummary)
            self.metrics = data
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
```

### 第四步：使用 Design System 搭建 SwiftUI 界面
```swift
import SwiftUI

public struct AnalyticsView: View {
    @Environment(AppModel.self) private var app
    @State private var viewModel: AnalyticsViewModel

    public init(apiClient: MagpieAPIClient) {
        _viewModel = State(initialValue: AnalyticsViewModel(apiClient: apiClient))
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 指标卡片
                VStack(alignment: .leading, spacing: 8) {
                    Text("请求延迟中位数")
                        .font(.subheadline)
                        .foregroundStyle(MagpieTheme.textSecondary)
                    Text("142 ms")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(MagpieTheme.textPrimary)
                }
                .magpieCard() // 统一应用原生卡片修饰器
            }
            .padding(16)
        }
        .background(MagpieTheme.backgroundGrouped)
        .navigationTitle("性能分析")
        .task {
            await viewModel.fetchMetrics()
        }
    }
}
```

### 第五步：在 `project.yml` 或目录中生效
执行 `xcodegen generate`，Xcode 会自动识别新创建的 Swift 文件并自动纳入目标 Target。

---

## 5. UI 设计系统使用规范

为了保持纯正的 Apple HIG 风格与极致的渲染性能，请务必遵守以下组件规范：

1. **统一使用系统语义颜色**：
   - 页面底色：`MagpieTheme.backgroundGrouped`（适配系统分组底色）
   - 卡片底色：`MagpieTheme.card`（自动适应深浅色材质）
   - 文字层次：`MagpieTheme.textPrimary`、`MagpieTheme.textSecondary`、`MagpieTheme.textMuted`
   - 品牌高亮：`MagpieTheme.accent`（基于系统靛蓝色）
2. **状态指示器**：
   - 使用 `MagpieStatusChip(text: "正常", color: MagpieTheme.green)` 展示状态，内置柔和半透明胶囊背景。
3. **卡片封装修饰器**：
   - 使用 `.magpieCard()` 替代繁杂的圆角 + 描边 + 背景手写代码，内置抗锯齿与自适应动态材质。
4. **浮动操作按钮**：
   - 在底栏、悬浮操作胶囊等需要前置物理折射交互的区域，使用 `.magpieLiquidSurface(cornerRadius: 999, interactive: true)`。
   - iPhone（含 Duo 内外屏）保留 2–4 个可固定标签及「更多」。未固定入口沿弧线展开，空间不足时可以滚动。开启「减少动态效果」后只淡入淡出。

---

## 6. 测试与验证

项目包含针对模型解码、网络错误封装与 API 协议的完整单元测试套件：

```bash
# 运行单元测试
xcodebuild -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

在提交任何改动前，请确保所有测试均绿灯通过，并且没有引入编译警告。

---

## 7. 提交规范 (Git Conventional Commits)

为了保持 Git 历史清晰，请使用标准语义化提交：
- `feat(scope)`: 新增功能（如 `feat(library): add memory search filter`）
- `fix(scope)`: 修复缺陷（如 `fix(routing): prevent race condition on long polling`）
- `perf(scope)`: 性能优化（如 `perf(cards): reduce redundant offscreen blur`）
- `docs(scope)`: 文档更新（如 `docs(readme): add screenshot preview`）
- `refactor(scope)`: 代码重构，不影响外部行为

---

感谢你的贡献，让我们一同打造最优雅好用的 Magpie 原生客户端！
