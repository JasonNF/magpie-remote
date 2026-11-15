# Magpie Remote — iOS 原生客户端开发计划

> 用原生 Swift + SwiftUI（MVVM）构建一个 iPhone / iPad 应用，在线管理远程 magpie 实例。
> 目标：**1:1 复刻官方 Web UI 的布局与功能**，全程使用原生组件与最新 Apple API，遵循 Human Interface Guidelines。
>
> 本文档是开工前的具体执行计划。调研依据见 `research/magpie-ref/`（已下载的 magpie 源码与文档）。

---

## 0. 结论先行

- **可行性已确认**：magpie 自带一套完整的 Web 管理 API（`/api/*`，约 250 条路由）和浏览器鉴权机制，iOS 原生客户端可以直接复用，做到与官方 Web UI 功能对齐。
- **连接方式**：App 通过 HTTP(S) 连接一个**对外提供 Web UI 的 magpie 实例**（`magpie web --lan` / `magpie serve --web --lan` / Docker / NAS），用 Web Key 换取 Cookie 后调用 `/api/*`。
- **技术栈**：Swift 6.4 · SwiftUI · iOS 26.0 起步（Xcode 27.1 / iOS 27 SDK 构建）· MVVM · `@Observable` · `NavigationSplitView` / `TabView` · Liquid Glass · SwiftData · Keychain · URLSession async/await。**零第三方依赖**。
- **工程脚手架**：XcodeGen（已安装 2.46.0）用 `project.yml` 生成 `.xcodeproj`，避免手改 pbxproj。
- **本次交付**：本计划文档。确认后再进入编码（按第 11 节的垂直切片推进）。

---

## 1. 调研结论：magpie 是什么，能远程管什么

### 1.1 magpie 简介

magpie（`yetone/magpie`，Go 编写）是一个**本地 AI 网关**：把各家 provider（API key、订阅账号、本地模型）统一接到 `127.0.0.1:3425`，为 Claude Code / Codex / Gemini CLI 等编码 Agent 提供模型切换、配额故障转移、路由组、隐私脱敏、用量统计等能力。形态有菜单栏 App、窗口、TUI、**Web UI**、CLI、Docker。

### 1.2 远程管理的三条通道（关键决策依据）

| 通道 | 路径 | 鉴权 | 覆盖功能 | 是否选用 |
| --- | --- | --- | --- | --- |
| **Web 管理 API** | `/api/*`（约 250 路由） | Web Key → Cookie `magpie_web_<port>` | **全部**：Agents / Providers / Groups / Routing / Gateway / Usage / Sessions / Masking / Library / Plugins / Settings | ✅ **主通道**（唯一能 1:1 对齐） |
| Management API | `/v1/magpie/admin/*` | Bearer 网关 Key（需 `admin any`） | 仅 Providers / Keys / 登录 / Gateway Keys / Account Groups，**不含** Agents / 路由组 / 用量 / 会话 / 设置 | ⚠️ 子集，不作为主通道 |
| `/me` 自助页 | `/me` | 网关 Key | 仅当前 Key 的额度与用量 | ❌ 太窄 |

**结论**：要 1:1 复刻官方功能，必须走 **Web 管理 API（`/api/*`）**。Management API 是脚本用的子集，缺 Agents/路由/用量等核心页面。

### 1.3 Web 鉴权机制（已从 `internal/gui/web.go` 核实）

- 启动 `magpie web` 时打印带 Key 的链接：`http://<host>:<port>/?k=<key>`。Key 来自 `MAGPIE_WEB_KEY`（固定，推荐用于常驻服务）或每次启动随机生成。
- 鉴权流程（`webGuard`）：
  1. `GET /?k=<key>` → 校验通过 → `Set-Cookie: magpie_web_<port>=<key>; HttpOnly; SameSite=Lax` → 303 重定向到干净地址。
  2. 或 `POST /_magpie/sign-in`（表单字段 `key` + `back`）→ 同样种 Cookie。
  3. 之后所有请求携带该 Cookie 即可访问页面与 `/api/*`。
- **跨域保护**（`webOwnPage` / `CrossOriginProtection`）：只拦截带浏览器 `Origin` / `Sec-Fetch-Site` 头的请求。**原生 iOS 客户端不发这些头，天然通过**，无需特殊处理。
- Cookie 有效期：固定 Key 为 400 天；随机 Key 随进程结束失效。→ App 需保存 Key，遇 401 自动重新登录。
- 同一端口同时服务页面与网关（`onePort`）：`/v1/*`、`/mcp/*` 走网关 Key，页面与 `/api/*` 走 Web Key Cookie。

### 1.4 官方 UI 结构（已从 `assets/index.html` / `phonetabs.js` 核实）

桌面窗口左侧边栏共 **10 个页面**（另有 Settings）：

```
agents · sessions · library · providers · routing · groups · gateway · usage · masking · plugins
```

**手机 Web 布局**（`phonetabs.js`）：底部 Tab Bar，**最多 5 个**；超出时第 5 个为 **More**（其余页面的列表，带图标，当前页高亮）——与 iPhone 原生 App 的 More 行为一致。

> 这正是 iOS 原生 `TabView`（iPhone 底部 Tab + 自动 More）与 `NavigationSplitView`（iPad 侧边栏）的原生映射，可 1:1 对齐。

### 1.5 核心数据契约（已从源码核实）

- `GET /api/state` → `stateJSON`：`agents[]`、`clients[]`、`profiles[]`、`catalog`、`settings`、`fx`、`options[]` + `optionLists[]`（模型选项去重索引）、`served`、`notice` 等。**几乎每次写操作后都返回最新 `state()`**，是 App 的主数据源。
- `POST /api/set` body `{Agent, Field, Value}` → 为某 Agent 的某字段选值（核心「为 Agent 选模型」动作），返回最新 state。
- `GET /api/providers` → provider 列表（key 已脱敏）；`POST /api/provider/{action}`（save/delete/on/off/test/models/list/…）。
- `GET /api/groups` → 路由组 + 可选模型 + 池 + 模板；`POST /api/groups/{action}`。
- `GET /api/usage`、`/api/usage/requests`、`/api/usage/quotas`、`/api/usage/heatmap`、`/api/usage/traffic`。
- `GET /api/sessions`、`/api/sessions/one`、`/api/sessions/transcript`、`/api/sessions/stats`。
- `GET /api/settings` + 60 余个 `POST /api/settings/*` 开关。
- 完整路由清单见 `research/magpie-ref/all-routes.txt`（250 条）。

---

## 2. 技术选型与版本策略

| 维度 | 选择 | 理由 |
| --- | --- | --- |
| 语言 | Swift 6.4（严格并发） | 本机已装 Swift 6.4.2；现代 concurrency |
| UI | SwiftUI（**不用 UIKit**） | 用户要求原生；swiftui-pro 规范 |
| 最低系统 | **iOS 26.0**（建议） | Liquid Glass / 原生 `WebView` / `Tab` API / `@Observable` 均可用；覆盖较新设备 |
| 构建工具 | Xcode 27.1（iOS 27 SDK） | 本机已装；iOS 27 新 API 用 `#available` 条件启用 |
| 架构 | MVVM + Repository | 用户指定；iosdev 模板 |
| 状态 | `@Observable` + `@MainActor` | 替代 `ObservableObject`，最新数据流 |
| 导航 | `TabView`(`Tab`) + `NavigationStack` / `NavigationSplitView` | 1:1 映射官方手机/桌面布局 |
| 网络 | `URLSession` + async/await + 类型化 Endpoint | 零依赖；自动 Cookie |
| 持久化 | SwiftData（连接配置）+ Keychain（密钥/Cookie） | 最新 Apple 持久化；密钥不落明文 |
| 设计 | Liquid Glass + SF Symbols + 系统字体 + Asset 命名色 | Apple 设计语言 |
| 依赖 | **零第三方** | swiftui-pro 要求；全部用系统框架 |
| 工程 | XcodeGen `project.yml` | 已安装；可版本化、可复现 |

**版本决策（已确认）**：**iOS 26.0** 起步（兼顾设备覆盖）；iOS 27 专属 API（`ToolbarOverflowMenu`、`safeAreaBar`、新 toolbar 角色等）用 `#available(iOS 27, *)` 渐进增强并提供 iOS 26 回退。Xcode 27.1 / iOS 27 SDK 构建。

---

## 3. 架构设计（MVVM）

### 3.1 分层

```
View (SwiftUI)
   │  绑定 / 调用 intent
   ▼
ViewModel (@Observable, @MainActor)      ← 每个页面一个，持有加载/错误/编辑状态
   │  调用
   ▼
Repository / Service (protocol)           ← 按领域划分，聚合 endpoint，返回领域模型
   │  调用
   ▼
MagpieAPIClient (URLSession, async)       ← 统一请求/鉴权/解码/错误/重试
   │
   ▼
远程 magpie /api/*
```

- **View**：只负责渲染与转发用户意图，不写业务逻辑；尽量用原生组件。
- **ViewModel**：`@Observable`，`@MainActor`；暴露 `state`（loading/loaded/error）、列表数据、编辑草稿；方法为 `async` intent（`load()`、`pickModel()`、`save()`…）。
- **Repository**：协议化（`AgentsRepositoryProtocol` 等），便于注入 mock 做单元测试与 Preview。
- **APIClient**：单例按「连接」隔离（每个服务器一个 `URLSession` + 独立 `HTTPCookieStorage`）。

### 3.2 共享状态

- `AppModel`（`@Observable`）：当前连接、连接列表、全局刷新信号。经 `.environment()` 注入。
- `ConnectionStore`：SwiftData 存连接配置（名称/URL/排序），Keychain 存 Web Key 与 Cookie。
- 每个连接的 `MagpieAPIClient` 独立持有 Cookie，互不串扰。

### 3.3 目录结构（按功能组织）

```
Magpie-remote/
├── PLAN.md
├── project.yml                      # XcodeGen 定义
├── MagpieRemote/
│   ├── App/                         # MagpieRemoteApp、RootView、Tab/侧边栏导航
│   ├── Core/
│   │   ├── Networking/              # MagpieAPIClient、Endpoint、APIError、Auth、Cookie
│   │   ├── Models/                  # StateDTO、AgentDTO、ProviderDTO、GroupDTO、UsageDTO…（Codable）
│   │   ├── Stores/                  # ConnectionStore(SwiftData)、KeychainStore、AppModel
│   │   └── Design/                  # DesignConstants、共享原生组件封装、主题
│   ├── Features/
│   │   ├── Connection/              # 服务器列表 / 添加 / 编辑 / 登录
│   │   ├── Agents/                  # Views + AgentsViewModel + 模型选择器
│   │   ├── Providers/
│   │   ├── Groups/                  # 路由组
│   │   ├── Routing/                 # 实时路由决策
│   │   ├── Gateway/                 # 网关 Key / 局域网共享
│   │   ├── Usage/                   # 用量 / 配额 / 图表
│   │   ├── Sessions/                # 会话列表 / 详情
│   │   ├── Masking/                 # 隐私脱敏
│   │   ├── Library/
│   │   ├── Plugins/
│   │   └── Settings/
│   └── Resources/                   # Assets.xcassets、Localizable.xcstrings、Info.plist
├── MagpieRemoteTests/               # XCTest：解码 / ViewModel / Repository(mock)
└── research/magpie-ref/             # magpie API 参考（已下载源码/文档/路由清单）
```

> 规范：一个类型一个 Swift 文件；按功能分文件夹；共享常量进 `DesignConstants`。

---

## 4. 网络层与连接模型

### 4.1 连接建立（登录）流程

```
用户输入: 名称 + URL(http(s)://host:port) + Web Key
   │
   ▼
GET {url}/?k={key}   (URLSession 自动跟随 303、存 Cookie)
   │  成功 → Cookie magpie_web_<port> 已种
   ▼
GET /api/state  验证 → 成功则保存连接
   │
   ▼
Keychain 存 Web Key；SwiftData 存连接配置；进入主界面
```

- 用 `URLSessionConfiguration.default` + 独立 `HTTPCookieStorage`，`httpShouldSetCookies = true`。
- **401 自动重登**：拦截 401 → 用 Keychain 里的 Key 重新 `GET /?k=` → 重放原请求（一次）。随机 Key 在 magpie 重启后会变，此时提示用户更新 Key。
- **多服务器**：连接列表可增删切换；每个连接独立 client/cookie/state。MVP 先做「单活动连接 + 可切换」，多连接并行刷新放后期。
- **安全**：Web Key 与 Cookie 只存 Keychain；URL 支持 https（自签证书场景提供「信任此证书」开关，默认关闭）；`ITSAppUsesNonExemptEncryption=false`。

### 4.2 APIClient 设计

- 类型化 `Endpoint`（path / method / body / query），`func send<T: Decodable>(_ e: Endpoint) async throws -> T`。
- 统一错误 `APIError`：`unauthorized` / `forbidden` / `http(status, message)` / `decoding` / `transport` / `offline`，映射为可读提示。
- 解码：`JSONDecoder`，对 magpie 大量 `omitempty` 字段全部用可选类型容错；`state` 的 `options/optionLists` 索引在 Repository 层展开为模型选项。
- 写操作后多数接口直接返回新 `state` → 统一刷新 `AppModel`，减少往返。
- 轮询：官方页面靠轮询刷新；App 对「实时路由 / 用量」用 `.task` + 定时刷新（可配置间隔），其余页面进入时拉取 + 下拉刷新。

---

## 5. 数据模型（Codable 映射）

按 magpie JSON 建 DTO（全部 `Codable`、`Identifiable`、`Sendable`，字段可选以容错 `omitempty`）：

| DTO | 对应 | 关键字段 |
| --- | --- | --- |
| `StateDTO` | `stateJSON` | agents, clients, profiles, catalog, settings, fx, options, optionLists, served, notice |
| `AgentDTO` | `agentJSON` | id, name, icon, fields[], wired, drift, models, menu, source, stale… |
| `FieldDTO` | `fieldJSON` | key, label, value, list(选项索引), live… |
| `ProfileDTO` | `profileJSON` | name, summary, inUse, agents |
| `ProviderDTO` | `providerJSON` | id, name, icon, preset, host, keys, accounts, models, on/off… |
| `GroupDTO` | `groupJSON` | ref, name, members, routing(smart/order/rotate/usage/pace), ready, offers… |
| `UsageDTO` / `RequestDTO` / `QuotaDTO` | usage 系列 | tokens, cost, cache, windows, balances… |
| `SessionDTO` | `sessionJSON` | id, name, agent, via[], cost, tokens, last… |
| `SettingsDTO` | `settings.Settings` | 各开关（按页面分组） |

> 模型选项去重：`state.options[]` + 每个 field 的 `optionLists` 索引 → Repository 展开成 `[ModelOption]` 供选择器用。

---

## 6. 功能模块与官方页面 1:1 映射

> 每个模块 = 一个 Feature 文件夹（Views + ViewModel + 组件）。下表给出官方页面 → iOS 呈现 → 主要 API。

| 官方页面 | iOS 呈现（原生组件） | 主要 API |
| --- | --- | --- |
| **Agents** | `List` + 每行 `Label`/`LabeledContent`；点字段弹**模型选择器**（`NavigationStack` + `searchable` 列表）；底部 Profiles 用 `Menu`/`confirmationDialog` | `GET /api/state`、`POST /api/set`、`POST /api/profile/{action}`、`POST /api/agents/{action}/{id}` |
| **Providers** | `List`（图标+名称+开关 `Toggle`）；详情 `Form`；添加用 `sheet` + 预设网格（`LazyVGrid`）；Test 按钮 | `GET /api/providers`、`POST /api/provider/{action}`、`POST /api/keys/{action}`、`POST /api/signin` |
| **Groups（路由组）** | `List` 卡片；编辑 `Form` + 成员多选；路由模式 `Picker` | `GET /api/groups`、`POST /api/groups/{action}` |
| **Routing（实时路由）** | 实时决策流 `List` + 详情；定时刷新 | `GET /api/gateway/route`、`/trace`、`/history`、`/call` |
| **Gateway（网关 Key/共享）** | Key 列表 `List` + 额度 `Form`；局域网开关 `Toggle` | `GET /api/caller-keys`、`POST /api/caller-keys/{action}`、`/api/settings/lan` |
| **Usage** | 统计卡 + **Swift Charts** 柱状/热力图；配额 `Gauge`/`ProgressView`；请求明细 `List` | `GET /api/usage`、`/requests`、`/quotas`、`/heatmap`、`/traffic` |
| **Sessions** | 会话 `List`（标题/Agent/成本）；详情 transcript；搜索 `searchable` | `GET /api/sessions`、`/one`、`/transcript`、`/stats` |
| **Masking** | 摘要卡 + 记录 `List`；规则编辑 `Form`；Try-it `sheet` | `GET /api/masking/summary`、`/records`；`POST /api/masking/preview`、`settings/redact-*` |
| **Library** | 指令/MCP/Skills/子代理 分区 `List` + 编辑 `Form` | `GET /api/library`、`POST /api/library/{what}/{action}` |
| **Plugins** | 已安装 `List` + 发现市场 `List`；安装/登录 `sheet` | `GET /api/plugins`、`/market`；`POST /api/plugins/{op}` |
| **Settings** | 分组 `Form`（`Section` + `Toggle`/`Picker`/`LabeledContent`） | `GET /api/settings`、`POST /api/settings/*` |
| **Connection（新增）** | 服务器列表 + 添加/编辑 `Form` + 登录 | `GET /?k=`、`GET /api/state` |

**导航骨架（1:1 官方）**：
- iPhone：`TabView`（新 `Tab` API）底部 Tab；前 4 个高频页 + **More**（其余页面列表）。用 `.tabViewStyle(.sidebarAdaptable)`。
- iPad：同一 `TabView` 自动适配为**侧边栏**（`NavigationSplitView` 语义），与官方桌面侧边栏一致。
- 每页内部 `NavigationStack` + `navigationDestination(for:)` 统一注册。

---

## 7. 组件复用策略（尽量原生，不自造）

### 7.1 优先使用的原生组件

`List` / `Form` / `Section` / `Label` / `LabeledContent` / `Toggle` / `Picker` / `Menu` / `NavigationStack` / `NavigationSplitView` / `TabView`(`Tab`) / `searchable` / `sheet` / `confirmationDialog` / `alert` / `ContentUnavailableView`（空态/错误态）/ `ProgressView` / `Gauge` / `Chart`（Swift Charts）/ `WebView`（iOS 26 原生，用于插件页/登录页）/ `TextField` / `SecureField` / `Stepper` / `Slider` / `DatePicker`。

### 7.2 少量共享封装（仅为复用，不重复造轮子）

| 共享组件 | 基于 | 用途 |
| --- | --- | --- |
| `ModelPicker` | `NavigationStack` + `searchable` + `List` | 全局「为字段选模型」，Agents/Groups 复用 |
| `StatusBadge` | `Label` + `.glassEffect` | 在线/离线/配额状态 |
| `AsyncContentView` | `ContentUnavailableView` + `ProgressView` | 统一 loading/empty/error 三态 |
| `ConnectionSwitcher` | `Menu` | 顶栏切换服务器 |
| `ProviderIcon` | `AsyncImage` + SF Symbol 回退 | 加载 provider/agent 图标（`/api/icons/{name}`） |
| `DesignConstants` | enum 常量 | 间距/圆角/字号/动画统一 |

> 原则：能用系统组件就不自定义；自定义仅限「组合原生组件 + 统一样式」，不画自定义控件。

---

## 8. Apple 设计规范落地（iosdev + swiftui-pro + liquid-glass）

- **Liquid Glass（iOS 26+）**：浮动工具条/状态徽章/卡片用 `.glassEffect(...)`，多玻璃元素包 `GlassEffectContainer`；可点元素 `.interactive()`；按钮 `.buttonStyle(.glass/.glassProminent)`；`#available` 回退 `.ultraThinMaterial`。
- **SF Symbols**：所有功能图标用 SF Symbols，**禁 emoji 当图标**。Agent/Provider 品牌图标走 `/api/icons` + `AsyncImage`，缺失回退 SF Symbol。
- **深色模式**：颜色全部进 Asset Catalog 命名色（Light/Dark 双变体），禁硬编码；优先系统语义色与 hierarchical style（`.secondary`）。
- **动态字体**：系统字体（SF Pro / PingFang），支持 Dynamic Type；`ViewThatFits` 应对大字号/窄屏。
- **无障碍**：VoiceOver 标签、≥44×44 点击区、`sensoryFeedback()` 触觉、Reduce Motion 适配。
- **本地化**：`Localizable.xcstrings`（String Catalog），首版 **简体中文 + 英文**；所有用户可见文本走本地化。
- **现代 API 纪律**：`foregroundStyle`/`tint`/`clipShape(.rect)`/`Tab`/两参或零参 `onChange`/`toolbarVisibility`/语义化 toolbar 角色（`.primaryAction`/`.confirmationAction`）/`@Entry`/`@ContentBuilder`（Xcode 27）；iOS 27 工具栏用 `ToolbarOverflowMenu` + `visibilityPriority`（条件启用）。
- **布局韧性**：不用 `UIScreen.main`；用 `containerRelativeFrame`/`safeAreaInset`/`safeAreaBar`；iPhone Duo / iPad 多任务下功能不缺失。
- **反 AI 俗套**：无紫蓝渐变英雄区、无 emoji 图标、无 Inter/Roboto 字体。

---

## 9. 工程脚手架与构建

- **XcodeGen**：根目录 `project.yml` 定义 target（App + Tests）、部署目标、Info.plist、Asset/String Catalog、签名（自动）。`xcodegen generate` 生成 `.xcodeproj`。
- **构建/运行**（本机 Xcode 在 `Xcode-27.1.0-Release.Candidate.app`，`xcode-select` 当前指向 CLT，用 `DEVELOPER_DIR` 覆盖，无需 sudo）：

```sh
export DEVELOPER_DIR=/Applications/Xcode-27.1.0-Release.Candidate.app/Contents/Developer
xcodegen generate
xcodebuild -project MagpieRemote.xcodeproj -scheme MagpieRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' build
xcrun simctl boot "iPhone 17 Pro Max"   # 可用模拟器: iPhone 17 Pro Max / 17e / Duo
```

- **可用模拟器**：iPhone 17 Pro Max、iPhone 17e、iPhone Duo（均 iOS 27）。
- **联调前提**：需要一个开了 Web UI 的 magpie 实例。可用 Docker（`ghcr.io/yetone/magpie`）或本机 `magpie serve --web --lan`，设 `MAGPIE_WEB_KEY` 固定 Key 便于 App 连接。

---

## 10. 测试与验证策略

- **单元测试（XCTest）**：DTO 解码（用真实 magpie JSON 样本，含 `omitempty`/索引展开）；ViewModel 状态机（loading→loaded/error）；Repository 用 mock APIClient。
- **Preview**：每个 View 配 `#Preview`，注入 mock Repository，覆盖空/载/错/深色/大字号。
- **集成验证**：连真实 magpie 实例，逐页对照官方 Web UI 核对数据与动作。
- **设计自检**：跑 iosdev 的 `design_quality_checker.py`；按 swiftui-pro 清单做 API/无障碍/导航复查。
- **相称原则**：只为「解码、状态机、关键业务」写测试；纯渲染/复述实现的改动不堆测试。

---

## 11. 开发阶段与里程碑（垂直切片，逐片可运行）

> 每片都端到端可用（界面→ViewModel→API→真实数据），完成即可在模拟器演示。

| 阶段 | 内容 | 验收 |
| --- | --- | --- |
| **M0 脚手架** | XcodeGen 工程、目录、DesignConstants、主题、空 `TabView` 骨架、本地化/Asset 就绪 | 模拟器跑起空壳，深色/动态字体正常 |
| **M1 连接 + 网络层** | APIClient、登录流程、Keychain/SwiftData、连接列表/添加/切换、401 重登 | 能连真实 magpie 并拉到 `state` |
| **M2 Agents（核心）** | Agents 列表、模型选择器、`/api/set`、Profiles 切换 | 在手机上为 Agent 切模型，官方 UI 同步可见 |
| **M3 Providers** | 列表/开关/详情/添加预设/Test/Key 管理 | 增删 provider、测连通 |
| **M4 Usage + Sessions** | Swift Charts 用量、配额、会话列表/详情 | 图表与官方数据一致 |
| **M5 Groups + Routing** | 路由组编辑、实时路由刷新 | 建组、看实时决策 |
| **M6 Gateway + Settings** | 网关 Key、局域网共享、设置分组 | 改设置即时生效 |
| **M7 Masking + Library + Plugins** | 脱敏记录/规则、Library 编辑、插件市场 | 三个页面功能对齐 |
| **M8 打磨** | Liquid Glass 细化、无障碍、本地化补全、iPad/Duo 适配、性能、设计自检 | 通过设计/无障碍清单 |
| **M9 收尾** | 清理临时文件、README、构建说明、（可选）TestFlight 准备 | 可交付 |

**推进方式**：M0→M2 先打通「连接 + 核心切模型」最小闭环给你看，再按片推进；每片完成汇报并可演示。

---

## 12. 风险与待决策项

| # | 事项 | 说明 / 建议 |
| --- | --- | --- |
| 1 | **部署目标** | ✅ 已确认 **iOS 26.0**，iOS 27 API 条件增强 |
| 2 | **联调实例** | ✅ 已确认 **由你提供地址 + Web Key**（开 Web UI 的 magpie，建议固定 `MAGPIE_WEB_KEY`）。凭据到位后做真实联调 |
| 3 | **随机 Key 失效** | magpie 重启会换随机 Key；建议服务端用固定 `MAGPIE_WEB_KEY`，App 遇 401 提示更新 |
| 4 | **HTTPS/自签证书** | 远程建议 https；自签证书提供「信任」开关（默认关），避免默认降级安全 |
| 5 | **功能取舍** | 官方部分动作是「操作本机 App」（重启/打开终端等），远程无意义 → 这些按钮在 iOS 端隐藏或置灰，其余 1:1 |
| 6 | **Bundle ID / 签名** | 暂定 `app.magpie.remote`（可改）；真机/上架需你的开发者账号签名 |
| 7 | **图标版权** | magpie 图标 MIT 许可可复用；App 图标用其图标或自绘，避免冒充官方 |

---

## 13. 交付物清单

1. 本计划文档 `PLAN.md`（本次）。
2. XcodeGen 工程 + 完整 SwiftUI 源码（MVVM，按功能分目录）。
3. 单元测试 + Preview。
4. `README.md`：构建、连接 magpie、运行说明。
5. （可选）模拟器运行截图 / 演示。

---

## 14. 下一步

确认本计划（尤其 **部署目标**、**联调实例**、**Bundle ID** 三项）后，我从 **M0 脚手架 + M1 连接层** 开始，先打通「连接真实 magpie → 拉到 state → Agents 切模型」最小闭环，再逐片推进到功能对齐。