# Magpie Remote (iOS / iPadOS)

<p align="center">
  <img src="MagpieRemote/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" alt="Magpie Remote Logo" width="108" height="108" style="border-radius: 24px; box-shadow: 0 8px 24px rgba(0,0,0,0.15);" />
</p>

<p align="center">
  <strong>专为 <a href="https://github.com/yetone/magpie">yetone/magpie</a> 量身定制的下一代原生 Apple 控制中心</strong><br>
  1:1 完整对齐官方 Web 控制台功能 · iOS 26 / 27 原生 Liquid Glass 设计语言 · 纯 Swift 6.4 实现 · 0 第三方依赖
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.4-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.4" />
  <img src="https://img.shields.io/badge/iOS-26.0%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="iOS 26.0+" />
  <img src="https://img.shields.io/badge/iPadOS-26.0%2B-157EFB?style=flat-square&logo=apple&logoColor=white" alt="iPadOS 26.0+" />
  <img src="https://img.shields.io/badge/Dependencies-0-success?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="MIT License" />
  <img src="https://img.shields.io/github/actions/workflow/status/zxfccmm4/magpie-remote/release.yml?branch=main&style=flat-square&label=Build%20IPA" alt="Build Status" />
</p>

---

## 🌟 为什么选择 Magpie Remote？

**magpie** 是极其强大且优雅的开源 AI Agent 网关与路由中间件。在日常使用中，我们经常需要在 iPhone 或 iPad 上随时查看当前的实时决策流、调整智能体默认模型、一键签到各大平台配额，或在手机上处理会话转写。

**Magpie Remote** 应运而生：
- **拒绝 Web 壳包装**：全量代码均由原生 **SwiftUI** 驱动，无任何 Webkit/WebView 嵌套，拥有秒级启动速度与沉浸式触感反馈（Haptics）。
- **iOS 26 / 27 现代美学**：采用 Apple 最新的人机界面指南（HIG）与 **Liquid Glass** 分层液态材质，深度融合系统动态色彩，光影自然，层级纯净。
- **120Hz ProMotion 丝滑流畅**：精心设计的分层渲染架构与 `@Observable` 单向数据流，杜绝 GPU 离屏渲染瓶颈，长列表滚动零掉帧。
- **纯净与安全**：全项目保持 **0 外部第三方库依赖**，网络通信仅依赖系统原生 `URLSession`，密码与 Web Key 严格保存在系统安全隔离区 **Keychain** 中。

---

## 📱 界面与交互架构演示

```mermaid
graph TD
    subgraph Client [Magpie Remote - 原生客户端]
        App[RootView 核心调度器]
        App --> TabBar[iPhone: Liquid Glass 浮动胶囊底栏]
        App --> SideBar[iPad: 多区段自适应侧边栏]
        TabBar --> Modules
        SideBar --> Modules
        
        subgraph Modules [11 大核心功能矩阵]
            Agents[🤖 Agents 路由与快照]
            Providers[🏢 提供商与多 Key 轮询]
            Groups[🔀 智能路由组编排]
            Usage[📊 账本与 Quotas 签到]
            Sessions[💬 历史会话与回收站]
            Routing[⚡ 实时决策长轮询]
            Gateway[🔑 限流窗口与 API Key]
            Masking[🛡️ 敏感脱敏沙盒]
            Library[📚 技能与 MCP 市场]
            Plugins[🧩 扩展插件中心]
            Settings[⚙️ 全局配置与 OTLP]
        end
    end

    subgraph Server [远程 magpie 服务端]
        GatewayAPI[magpie web /api/*]
    end

    Modules -- 原生安全 Keychain 鉴权 / HTTPS -- GatewayAPI
```

### iPhone 浮动底栏与 iPad 侧栏体验
```text
┌────────────────────────────────────────────────────────┐
│                        iPhone                          │
│                                                        │
│   ┌────────────────────────────────────────────────┐   │
│   │  Claude Code               [ 运行中 · 正常 ]    │   │
│   │  当前模型: claude-3-7-sonnet-thought            │   │
│   │  Tokens: 1.2M  ·  成本: $4.18                  │   │
│   └────────────────────────────────────────────────┘   │
│                                                        │
│               [ 智能体 · 提供商 · 路由 · 账本 · 更多 ]  │  <- 物理级 Liquid Glass
└────────────────────────────────────────────────────────┘
```

---

## 💎 核心功能矩阵 (1:1 官方特性对齐)

| 模块 | 功能亮点 | 原生实现特色 |
| :--- | :--- | :--- |
| **🤖 Agents** | 集中管理 Claude Code、Codex、Gemini 等智能体；多配置快照（Profiles）；细粒度模型开关与拖拽排序。 | 原生 `NavigationSplitView` 与可定制化卡片；毫秒级切换生效。 |
| **🏢 Providers** | 覆盖 70+ 预设厂商；多账号轮询池与权重分配；连通性诊断测速；支持 Vertex AI 与订阅式交互登录。 | 实时异步测速状态胶囊、连通性进度柱状指示。 |
| **🔀 Groups** | 策略组一览与在线编排；支持亲和性匹配、多级回退备用机制、规则分类器与模板导入导出。 | 拖拽排序交互与原生策略微胶囊标识。 |
| **📊 Usage** | 实时 Token 消耗统计、详细请求账本；支持一键签到（WorkBuddy/Trae/Qoder/MiniMax 等）；Tuned for you 上下文优化建议。 | Apple Charts 矢量渲染用量趋势图；触控触觉反馈。 |
| **💬 Sessions** | 历史交互长文转写（Transcript）；Markdown 原生高亮与复制；跨智能体转写继承（Carry）；会话回收站与恢复。 | 虚拟化长列表流畅加载，支持一键保存至服务器。 |
| **⚡ Routing** | 历史路由执行链路回溯；支持 2 秒长轮询模式的实时路由决策流。 | 流光脉冲活动卡片，清晰直观展示请求在多提供商间的命中与流转。 |
| **🔑 Gateway** | 网关调用凭据管理；支持滑动窗口配额（按日/周/月/小时限额 Token 或成本）。 | 原生限额进度条与动态重置倒计时。 |
| **🛡️ Masking** | 敏感实体脱敏规则库；内置即时交互脱敏预览沙盒与拦截请求审计。 | 实时语法对比与白名单标记。 |
| **📚 Library** | 技能库（Skills）与 MCP 服务器一站式管理；内置官方 Skills.sh 与 MCP Registry 市场一键安装；内置记忆库管理。 | 卡片化市场一览，带有一键装配与自动发现提示。 |
| **🧩 Plugins** | 社区插件中心、NPM 镜像源切换与参数配置。 | 优雅表单与多源检索。 |
| **⚙️ Settings** | 外观自适应、货币切换、局域网访问、数据备份（导出至服务端 Downloads）以及 OTLP 遥测监控配置。 | 系统级分组样式，与 iOS 设置体验保持一致。 |

---

## 🚀 快速开始

### 1. 服务端准备
确保你的服务器已部署并启动了 [magpie](https://github.com/yetone/magpie)：

```bash
# 设置固定的 Web Key 并启动 Web 服务（支持局域网或公网访问）
export MAGPIE_WEB_KEY="your-custom-web-key"
magpie web --addr 0.0.0.0:3426 --lan --no-open
```

### 2. 客户端安装

你可以通过以下任一方式安装 Magpie Remote：

- **方式 A：GitHub Releases 直接下载 IPA（推荐）**
  每次项目发布新版本，GitHub Actions 会自动编译并生成开箱即用的 `.ipa` 文件。
  前往 [Releases 页面](../../releases) 下载最新的 `MagpieRemote.ipa`，使用 **TrollStore**、**AltStore** 或 **SideStore** 即可自签安装。
- **方式 B：本地源码编译**
  参照下方的源码编译指南，使用 Xcode 直接部署到连接的真机或模拟器。

### 3. 连接到你的实例
1. 打开 Magpie Remote 应用。
2. 点击「添加连接」，填入服务器名称、服务地址（如 `http://192.168.1.100:3426` 或你的远程域名）以及 `MAGPIE_WEB_KEY`。
3. 点击「连接」，客户端将完成安全握手并自动同步服务器全量状态！

---

## 🛠️ 源码编译与工程构建

项目使用声明式配置工具 **XcodeGen** 管理工程。

### 环境要求
- macOS 15.0 (Sequoia) 或更高版本
- Xcode 27.0+（支持 iOS 26.0+ SDK）
- 安装 XcodeGen：`brew install xcodegen`

### 本地编译步骤
```bash
# 1. 声明式生成 Xcode 工程
xcodegen generate

# 2. 命令行执行模拟器编译检查
xcodebuild -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -destination 'generic/platform=iOS Simulator' \
  build \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO

# 3. 运行自动化单元测试套件
xcodebuild -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test \
  CODE_SIGNING_ALLOWED=NO CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO
```

---

## 📦 自动打包与 GitHub Actions 发版

本项目配置了全自动化的 CI/CD 流程（位于 `.github/workflows/release.yml`）：
- **自动触发**：每当你向 GitHub 仓库推送版本标签（如 `git tag v0.1.0 && git push origin v0.1.0`）或在网页端创建 Release 时，流水线将自动运行；
- **免签导出**：在纯净的 macOS 运行器中自动完成构建与封装，生成开箱即用的标准 `MagpieRemote.ipa` 并附带 SHA256 校验和；
- **自动发布**：产物将自动上传附加至对应的 GitHub Release 资产中，供全球用户直接下载体验。

---

## 🤝 参与二次开发

想要定制属于自己的主题样式、增加新的网关分析图表或集成更多 Agent 协议？
请查阅我们专门编写的 **[二次开发指南 (DEVELOPMENT.md)](DEVELOPMENT.md)** 与 **[AI Agent 协作指南 (AGENTS.md)](AGENTS.md)**。

---

## 📄 开源许可证

本项目基于 [MIT License](LICENSE) 开源协议发布，欢迎个人与商业用户自由使用、二开与分发。

致敬并感谢 [yetone/magpie](https://github.com/yetone/magpie) 团队创造了如此卓越出色的 AI 网关基座！
