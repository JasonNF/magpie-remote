# AGENTS.md

本文件是 Magpie Remote iOS 项目专用的 AI 编码代理与开发者工作规范指南。
在进行任何代码修改、特性扩展或构建排查前，请务必完整阅读并严格遵守以下约定。

---

## 1. 项目速览

- **定位**：[yetone/magpie](https://github.com/yetone/magpie) 官方生态的 iOS / iPadOS 原生远程控制客户端。
- **技术栈**：Swift 6.4 · SwiftUI · Observation 框架（`@Observable`） · MVVM 架构 · Swift 严格并发模型。
- **设计风格**：完全遵循 iOS 26 / 27 现代 Apple 人机界面指南（HIG），采用系统动态语义颜色、原生组件排版与 Liquid Glass 分层渲染。
- **依赖原则**：**0 第三方依赖**。不得私自引入任何 CocoaPods / Carthage / 第三方 SPM 库，保持纯净轻量。
- **工程管理**：使用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 声明式管理（`project.yml` 为唯一源），`.xcodeproj` 由脚本生成，**严禁手动提交 .xcodeproj**。

---

## 2. 常用构建与测试命令（重要）

所有开发者与 AI 代理请统一使用以下标准命令验证代码：

### 环境前置检查
```bash
# 安装 XcodeGen（若未安装）
brew install xcodegen

# 确认系统 Xcode 路径（若安装有特定版本，可配置 DEVELOPER_DIR）
xcode-select -p
# 例如指向特定 Xcode:
# export DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer
```

### 生成与重新生成工程
每次新增文件、删除文件或修改 `project.yml` 后必须执行：
```bash
xcodegen generate
```

### 命令行编译（无证书 / 模拟器）
```bash
# 针对通用 iOS 模拟器编译检查语法与类型：
xcodebuild -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -destination 'generic/platform=iOS Simulator' \
  build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

### 运行单元测试
```bash
# 在指定模拟器上执行单元测试（如 iPhone 17 Pro Max）：
xcodebuild -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""
```

### 本地打包生成无签名 IPA（用于自签/TrollStore/AltStore 测试）
```bash
# 1. 归档
xcodebuild archive \
  -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -archivePath build/MagpieRemote.xcarchive \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY=""

# 2. 组装标准 IPA
mkdir -p build/ipa/Payload
cp -r "build/MagpieRemote.xcarchive/Products/Applications/MagpieRemote.app" build/ipa/Payload/
cd build/ipa && zip -r -q ../MagpieRemote.ipa Payload && cd ../..
```

---

## 3. 代码架构与目录规范

```text
MagpieRemote/
├── App/                # App 生命周期入口、RootView、MainTabView 导航
├── Core/
│   ├── Design/         # Apple 语义主题系统 (MagpieTheme)、Liquid Glass (MagpieLiquidGlass)、图标系统
│   ├── Models/         # 严格遵循 Codable 的 RESTful DTO 模型
│   ├── Networking/     # 原生 URLSession 封装客户端 (MagpieAPIClient)、Endpoint、APIError
│   └── Stores/         # 全局状态 (@Observable AppModel)、KeychainStore 安全持久化
├── Features/           # 各业务特性模块（按业务领域完全自聚拢，包含 View 与 ViewModel）
│   ├── Agents/         # 智能体路由与快照管理
│   ├── Providers/      # 模型提供商、多密钥与连通性测试
│   ├── Groups/         # 路由组策略与亲和性编排
│   ├── Usage/          # Token 账本、配额签到与上下文调优
│   ├── Routing/        # 实时决策追踪与调用历史
│   ├── Gateway/        # 网关调用令牌与滑动窗口限额
│   ├── Sessions/       # 会话历史转写与回收站管理
│   ├── Masking/        # 敏感信息沙盒与脱敏规则
│   ├── Library/        # 技能库、MCP 服务器与记忆库 (Memory)
│   ├── Plugins/        # 插件系统与 NPM 镜像管理
│   ├── Connection/     # 服务器实例连接管理与扫码绑定
│   ├── Settings/       # 全局参数、导出与 OTLP 可观测性
│   └── More/           # iPad 侧栏聚合与紧凑模式原生导航抽屉
└── Resources/          # Assets 静态资源、多语言本地化（Localizable.xcstrings）
```

---

## 4. 关键开发守则

1. **Apple HIG 规范**：
   - 严禁在视图中硬编码非系统十六进制背景或无边距的大块色卡。必须统一使用 `MagpieTheme` 系统语义色彩与系统材质（如 `Color(.systemGroupedBackground)`、`.background(.regularMaterial)`）。
   - 保持 120Hz ProMotion 极致流畅性能：避免在长列表循环项中滥用高半径离屏模糊（`blur`）或多重连续投射阴影。
2. **状态与并发规范**：
   - 全面使用 `@Observable` 宏管理状态，严格标注 `@MainActor` 隔离 UI 交互状态；
   - 跨异步调用时保持 `Sendable` 线程安全，严禁在后台线程直接触发 UI 变动。
3. **网络与数据反序列化**：
   - 严格处理服务端接口的驼峰与蛇形命名兼容（magpie 官方 Go 后端部分字段为 PascalCase 或 lowercase）；
   - 反序列化错误统一抛出明确的 `APIError`，避免吃掉错误或静默失败。
4. **提交约定**：
   - 遵循规范化提交：`<type>(<scope>): <subject>`（如 `feat(sessions): add restore session capability`）。
   - 严禁将本地调试日志、缓存、密钥文件（`.dev/`、`*.log`、`cookies.txt`）以及临时构建产物提交入库。
