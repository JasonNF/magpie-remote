# Magpie Remote (iOS 原生客户端)

> 基于原生 **Swift 6.4 + SwiftUI**，采用 **MVVM 架构** 构建的 magpie 在线远程管理客户端。
> 1:1 对齐 [yetone/magpie](https://github.com/yetone/magpie) 官方 Web UI 的功能与布局，纯原生组件实现，无任何第三方依赖。

---

## 核心特性

- **1:1 原生功能对齐**：
  - **Agents**：集中管理本机或远程 Agent（Claude Code、Codex、Gemini CLI 等），为任意字段搜索并切换模型，支持 Profiles 方案；每个 Agent 有独立的「模型列表」（All / Shown / Order 三视图，点按即时保存，仅我选的、隐藏自带模型、全部显示/隐藏与拖拽排序）。
  - **Providers**：列表展示、启用/停用、连通性测试（可按账号测试并随时停止）、按当前表单拉取厂商模型；添加页含 70+ 预设、保存前获取模型目录、Vertex AI 与订阅登录（Claude / ChatGPT / Copilot 及插件 Provider 的逐步提问登录）。编辑器覆盖官方高级项：请求头、Extra body、TLS/HTTP1、认证头、价格倍率、模型行为、单模型设置（重命名、上下文/输出上限、推理档、图片能力）、多 Key（协议/权重）、复制、排序与忘记厂商列表。
  - **Groups**：路由组一览与完整编辑（新建、策略、亲和性、成员选择与排序、规则/分类器、仅经路由组使用、启停），支持模板、分享/导入、自动发现开关与排除、组默认值及多账号池展示。
  - **Usage**：用量总览、请求账本（CSV 复制/导出到服务器、清除统计）、会话与上下文；配额卡可单独刷新、一键签到（WorkBuddy/Trae/Qoder/MiniMax），并提供官方的「Tuned for you」上下文优化建议（采用/撤销）。
  - **Sessions**：历史会话列表与 Transcript；支持复制/导出 Markdown、导出到服务器 Downloads，以及转换为其他 Agent 的会话（carry）。
  - **Routing**：历史路由记录 + 实时决策流（`/api/gateway/trace`，2 秒轮询，进行中的请求带流光动画）。
  - **Gateway**：网关调用 Key 管理，支持开关、删除与权限标识；可为每个 Key 设置最多 5 个限额窗口（每天/周/月、每 N 天/小时、累计），限制 tokens 或美元成本、按模型范围计数，并查看本窗口用量与重置。
  - **Masking**：脱敏规则、预览沙盒与请求记录（按类型/Agent/提供方/拦截筛选），可查看实际发给厂商的请求体并对占位符「不再脱敏」。
  - **Library**：技能、MCP 服务器与指令管理；支持检查/更新技能，并内置 **Library 市场**（skills.sh 技能与 MCP Registry/精选服务器，一键安装到全部 Agent）。
  - **Settings**：外观、货币、LAN、脱敏、Claude 缓存时长、完整上下文、Codex 多 Agent V1、保持唤醒等；支持带口令的备份导出到服务器 Downloads。
- **现代化 Apple 设计与交互**：
  - **原生组件优先**：全程采用 `TabView`（iPhone 底部 Tab / iPad 侧边栏自动适配）、`NavigationStack`、`List`、`Form`、`LabeledContent`、`ContentUnavailableView`、`ProgressView`、`Chart`。
  - **图标与色彩**：全量使用 **SF Symbols** 与 Apple 语义色彩（无硬编码色值），自适应深浅色模式与动态字体（Dynamic Type）。
  - **安全凭据存储**：Web Key 与敏感 Token 隔离存储在系统 **Keychain** 中，不落明文磁盘。
  - **Swift 6 严格并发**：全流程基于 `async/await`、`@Observable` 与 `@MainActor`，数据流单向清晰。

---

## 技术架构

```
┌────────────────────────────────────────────────────────┐
│                      SwiftUI Views                     │
│  (MainTabView, AgentsView, ProvidersView, UsageView …) │
└───────────────────────────┬────────────────────────────┘
                            │ 绑定 / 触发 Intent
┌───────────────────────────▼────────────────────────────┐
│                  ViewModels (@Observable)              │
│ (AgentsViewModel, ProvidersViewModel, UsageViewModel …)│
└───────────────────────────┬────────────────────────────┘
                            │ 发起异步网络调用
┌───────────────────────────▼────────────────────────────┐
│                    MagpieAPIClient                     │
│    (URLSession, HTTPCookieStorage, 401 自动重登录)     │
└───────────────────────────┬────────────────────────────┘
                            │ HTTP / API 请求
┌───────────────────────────▼────────────────────────────┐
│           远程 magpie 实例 (magpie web /api/*)         │
└────────────────────────────────────────────────────────┘
```

---

## 快速开始

### 环境要求

- macOS 15+
- Xcode 27.1+（支持 iOS 26.0+ SDK）
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### 生成工程与编译

```bash
# 1. 生成 .xcodeproj 工程文件
xcodegen generate

# 2. 命令行编译 (针对 iOS 模拟器)
export DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer
xcodebuild -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  build

# 3. 运行测试套件
xcodebuild -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test
```

---

## 连接远程 magpie 实例

App 需要连接一个开启了 Web 服务的 magpie 实例：

1. **服务端启动 Web 模式**：
   ```bash
   # 设置固定 Web Key 并启动局域网 Web 服务
   export MAGPIE_WEB_KEY="your-secure-web-key-at-least-16-chars"
   magpie web --addr 0.0.0.0:3426 --lan --no-open
   ```
2. **在 iOS App 中添加连接**：
   - 打开 Magpie Remote 应用。
   - 点击「添加连接」。
   - 输入名称、服务器地址（如 `http://192.168.1.100:3426`）以及上述 `MAGPIE_WEB_KEY`。
   - 点击保存，客户端将自动执行握手与状态拉取，进入主控制台。
