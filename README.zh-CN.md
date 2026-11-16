<p align="center">
  <a href="README.md">English</a> · <strong>简体中文</strong>
</p>

<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset=".github/assets/app-icon-dark.png">
    <img src="MagpieRemote/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png" alt="Magpie Remote" width="112" height="112">
  </picture>
</p>

<h1 align="center">Magpie Remote</h1>

<p align="center">
  <strong>专为 <a href="https://github.com/yetone/magpie">yetone/magpie</a> 打造的原生 Apple 控制中心</strong><br>
  1:1 对齐官方 Web 控制台 · iOS 26 / 27 Liquid Glass · 纯 SwiftUI 实现 · 零第三方依赖
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Swift-6.4-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.4" />
  <img src="https://img.shields.io/badge/iOS-26.0%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="iOS 26.0+" />
  <img src="https://img.shields.io/badge/iPadOS-26.0%2B-157EFB?style=flat-square&logo=apple&logoColor=white" alt="iPadOS 26.0+" />
  <img src="https://img.shields.io/badge/Dependencies-0-success?style=flat-square" alt="Zero Dependencies" />
  <img src="https://img.shields.io/badge/License-MIT-blue?style=flat-square" alt="MIT License" />
  <img src="https://img.shields.io/github/actions/workflow/status/zxfccmm4/magpie-remote/release.yml?branch=main&style=flat-square&label=Build%20IPA" alt="Build Status" />
</p>

## ✨ 为什么选择 Magpie Remote

[magpie](https://github.com/yetone/magpie) 是强大而优雅的开源 AI Agent 网关与路由中间件。Magpie Remote 把它的日常操作完整搬到 iPhone 与 iPad：实时决策流、智能体默认模型、平台配额签到、会话转写，都能随时在掌上完成。

- **原生优先** — 100% SwiftUI 驱动，没有 WebView 壳；启动即用，交互带原生触感反馈（Haptics）。
- **现代设计** — 遵循 Apple HIG 与 iOS 26 / 27 Liquid Glass 分层材质，自动适配系统深浅色与动态色彩。
- **流畅跟手** — `@Observable` 单向数据流配合分层渲染，120Hz ProMotion 下长列表滚动依然稳定。
- **安全纯净** — 零第三方依赖；Web Key 与密码保存在系统 Keychain，网络访问仅用原生 `URLSession`。

## 💎 核心功能

| 模块 | 功能亮点 | 原生实现 |
| :--- | :--- | :--- |
| **🤖 Agents** | 集中管理 Claude Code、Codex、Gemini 等智能体；多配置快照（Profiles）；细粒度模型开关与拖拽排序。 | 原生 `NavigationSplitView` 与可定制卡片，切换即时生效。 |
| **🏢 Providers** | 覆盖 70+ 预设厂商；多账号轮询池与权重分配；连通性诊断测速；支持 Vertex AI 与订阅式交互登录。 | 异步测速状态胶囊、连通性进度指示。 |
| **🔀 Groups** | 策略组一览与在线编排；支持亲和性匹配、多级回退、规则分类器与模板导入导出。 | 拖拽排序与原生策略微胶囊标识。 |
| **📊 Usage** | 实时 Token 统计与请求账本；一键签到（WorkBuddy / Trae / Qoder / MiniMax 等）；Tuned for you 上下文建议。 | Apple Charts 矢量趋势图与触觉反馈。 |
| **💬 Sessions** | 历史交互长文转写（Transcript）；Markdown 原生高亮与复制；跨智能体转写继承（Carry）；回收站与恢复。 | 虚拟化长列表，支持一键保存至服务器。 |
| **⚡ Routing** | 历史路由链路回溯；2 秒长轮询的实时路由决策流。 | 流光脉冲活动卡片，展示请求在多提供商间的命中与流转。 |
| **🔑 Gateway** | 网关调用凭据管理；滑动窗口配额（按日 / 周 / 月 / 小时限额 Token 或成本）。 | 原生限额进度条与动态重置倒计时。 |
| **🛡️ Masking** | 敏感实体脱敏规则库；即时交互预览沙盒与拦截请求审计。 | 实时语法对比与白名单标记。 |
| **📚 Library** | 技能库（Skills）与 MCP 服务器一站式管理；内置 Skills.sh 与 MCP Registry 市场；内置记忆库。 | 卡片化市场一览，支持一键装配与自动发现。 |
| **🧩 Plugins** | 社区插件中心、NPM 镜像源切换与参数配置。 | 原生表单与多源检索。 |
| **⚙️ Settings** | 外观自适应、货币切换、局域网访问、数据备份与 OTLP 遥测配置。 | 系统级分组样式，与 iOS 设置体验一致。 |

## 🚀 快速开始

### 1. 启动 magpie 服务端

确保服务器已部署并启动 [magpie](https://github.com/yetone/magpie)：

```bash
# 设置固定的 Web Key 并启动 Web 服务（支持局域网或公网访问）
export MAGPIE_WEB_KEY="your-custom-web-key"
magpie web --addr 0.0.0.0:3426 --lan --no-open
```

### 2. 安装 Magpie Remote

- **GitHub Releases（推荐）** — 发布新版本后，GitHub Actions 会构建 `MagpieRemote.ipa`。前往 [最新 Release](../../releases/latest) 下载，用 **TrollStore**、**AltStore** 或 **SideStore** 自签安装。
- **本地编译** — 按下方「从源码构建」使用 Xcode 直接部署到真机或模拟器。

### 3. 连接你的实例

1. 打开 Magpie Remote。
2. 点击「添加连接」，填入名称、服务地址（如 `http://192.168.1.100:3426` 或远程域名）与 `MAGPIE_WEB_KEY`。
3. 点击「连接」，客户端会完成安全握手并同步服务器状态。

## 🛠️ 从源码构建

工程由 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 声明式管理，`project.yml` 是唯一配置源；新增或删除文件后需重新生成工程。

| 环境 | 要求 |
| :--- | :--- |
| macOS | Sequoia 15.6+（Xcode 26.0–26.3）或 Tahoe 26.2+（Xcode 26.4+） |
| Xcode | 26.0+（iOS 26 SDK；CI 使用 26.6 验证，27.x 亦可） |
| XcodeGen | `brew install xcodegen` |

```bash
# 1. 生成 Xcode 工程
xcodegen generate

# 2. 模拟器编译检查
xcodebuild -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -destination 'generic/platform=iOS Simulator' \
  build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""

# 3. 运行单元测试
xcodebuild -project MagpieRemote.xcodeproj \
  -scheme MagpieRemote \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY=""
```

## 📦 自动构建与发布

CI/CD 配置位于 [`.github/workflows/release.yml`](.github/workflows/release.yml)：

- **触发** — 推送 `main`、推送 `v*` 标签、发布 Release，或手动运行 workflow。
- **构建** — 在 `macos-26` 运行器上使用 Xcode 26 完成未签名 Archive，导出 `MagpieRemote.ipa` 并生成 SHA256 校验和。
- **产物** — Action 归档保留 14 天；标签与 Release 触发时会自动附加到对应 GitHub Release。

## 🤝 参与开发

想定制主题、增加网关分析图表或接入更多 Agent 协议？请阅读 [二次开发指南](DEVELOPMENT.md) 与 [AI Agent 协作指南](AGENTS.md)。

## 📄 开源许可证

本项目基于 [MIT License](https://opensource.org/license/mit) 发布，欢迎个人与商业用户自由使用、二次开发与分发。

致敬并感谢 [yetone/magpie](https://github.com/yetone/magpie) 团队创造的出色 AI 网关基座。
