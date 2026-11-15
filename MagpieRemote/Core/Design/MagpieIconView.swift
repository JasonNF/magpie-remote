import SwiftUI

/// 渲染 magpie 官方 180+ 品牌与 Agent 图标的自适应视图。
/// 支持自动识别官方矢量 Asset、名称别名、纯色与彩色变体，并提供高质感兜底。
struct MagpieIconView: View {
    let icon: String?
    let name: String
    var size: CGFloat = 28
    var cornerRadius: CGFloat = 7

    var body: some View {
        Group {
            if let assetName = resolveAssetName(for: icon, name: name) {
                Image(assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            } else {
                fallbackIcon
            }
        }
        .frame(width: size, height: size)
    }

    /// 高质感首字母兜底头像（原版设计风格 + Liquid Glass 微光）。
    private var fallbackIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fallbackBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 0.6)
                )
            Text(fallbackInitial)
                .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }

    private var fallbackInitial: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first {
            return String(first).uppercased()
        }
        return "M"
    }

    private var fallbackBackground: LinearGradient {
        // 基于名称生成稳定的品牌感渐变
        let hash = abs(name.hashValue)
        let colors: [(Color, Color)] = [
            (Color(hex: "4f46e5"), Color(hex: "7c3aed")),
            (Color(hex: "0ea5e9"), Color(hex: "2563eb")),
            (Color(hex: "10b981"), Color(hex: "059669")),
            (Color(hex: "f59e0b"), Color(hex: "d97706")),
            (Color(hex: "ec4899"), Color(hex: "db2777")),
            (Color(hex: "8b5cf6"), Color(hex: "6d28d9")),
            (Color(hex: "06b6d4"), Color(hex: "0284c7"))
        ]
        let pair = colors[hash % colors.count]
        return LinearGradient(colors: [pair.0, pair.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// 根据 magpie 服务端返回的 icon 字符串解析已导入的 Asset 资源名称。
    private func resolveAssetName(for icon: String?, name: String) -> String? {
        var candidates: [String] = []

        if let icon, !icon.isEmpty {
            var raw = icon
            // 剥离 file: 前缀及 .svg / .png 扩展名
            if raw.hasPrefix("file:") {
                raw = String(raw.dropFirst(5))
            }
            if raw.hasSuffix(".svg") {
                raw = String(raw.dropLast(4))
            } else if raw.hasSuffix(".png") {
                raw = String(raw.dropLast(4))
            }
            candidates.append(raw)
            candidates.append("\(raw)-color")
            if raw.hasSuffix("-color") {
                candidates.append(String(raw.dropLast(6)))
            }
        }

        // 基于 name 的常见别名猜测
        let lowerName = name.lowercased()
        if lowerName.contains("claude") {
            candidates.append(contentsOf: ["claudecode-color", "claude-color", "anthropic"])
        } else if lowerName.contains("codex") {
            candidates.append(contentsOf: ["codex-color", "openai"])
        } else if lowerName.contains("gemini") {
            candidates.append(contentsOf: ["gemini-color", "google-color"])
        } else if lowerName.contains("deepseek") {
            candidates.append("deepseek-color")
        } else if lowerName.contains("kimi") || lowerName.contains("moonshot") {
            candidates.append("kimi-color")
        } else if lowerName.contains("minimax") {
            candidates.append("minimax-color")
        } else if lowerName.contains("qwen") || lowerName.contains("tongyi") {
            candidates.append("qwen-color")
        } else if lowerName.contains("grok") || lowerName.contains("xai") {
            candidates.append("xai")
        } else if lowerName.contains("copilot") {
            candidates.append(contentsOf: ["copilot-color", "githubcopilot", "github-color"])
        } else if lowerName.contains("cursor") {
            candidates.append("cursor")
        } else if lowerName.contains("mistral") {
            candidates.append("mistral-color")
        } else if lowerName.contains("groq") {
            candidates.append("groq-color")
        } else if lowerName.contains("ollama") {
            candidates.append("ollama")
        } else if lowerName.contains("openrouter") {
            candidates.append("openrouter")
        }

        // 验证 Asset Catalog 中是否存在
        for candidate in candidates {
            if UIImage(named: candidate) != nil {
                return candidate
            }
        }
        return nil
    }
}
