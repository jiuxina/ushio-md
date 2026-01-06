# 汐 - 插件开发指南

本文档面向希望为汐（Ushio-MD）开发插件的开发者。

## 概述

汐采用**声明式插件架构**，插件通过 JSON 清单定义配置和资源，由应用内置渲染器解释执行。这种设计确保了安全性和稳定性，同时提供丰富的扩展能力。

### 核心特性

- **10大扩展点**：工具栏、主题、预览、导出、编辑器、文件操作、导航、快捷键、Widget注入、多语言
- **热更新**：插件安装/启用后立即生效，无需重启应用
- **去中心化**：无需官方审核，用户自主决定信任
- **权限系统**：危险权限需用户明确确认

---

## 插件结构

```
my-plugin/
├── manifest.json      # 必需：插件清单
├── icon.png           # 可选：插件图标 (128x128)
├── assets/            # 可选：资源文件
│   ├── styles.css
│   └── theme.json
└── locales/           # 可选：翻译文件
    ├── zh-CN.json
    └── en-US.json
```

### manifest.json

```json
{
  "id": "author.plugin-name",
  "name": "插件显示名称",
  "version": "1.0.0",
  "author": "作者名称",
  "description": "插件功能描述",
  "icon": "icon.png",
  "homepage": "https://github.com/author/plugin",
  "minAppVersion": "1.1.0",
  "permissions": ["toolbar", "theme"],
  "extensions": {
    "toolbar": [...],
    "theme": {...},
    "preview": {...}
  }
}
```

---

## 权限列表

| 权限 | 说明 | 危险 |
|------|------|------|
| `toolbar` | 添加工具栏按钮 | 否 |
| `theme` | 添加主题配色 | 否 |
| `preview` | 自定义预览样式 | 否 |
| `export` | 添加导出格式 | 否 |
| `editor` | 编辑器行为 | 否 |
| `navigation` | 导航扩展 | 否 |
| `shortcuts` | 快捷键绑定 | 否 |
| `widgets` | Widget注入 | 否 |
| `localization` | 多语言翻译 | 否 |
| `file_actions` | 文件操作菜单 | ⚠️ 是 |
| `cloud` | 云服务访问 | ⚠️ 是 |
| `network` | 网络请求 | ⚠️ 是 |
| `filesystem` | 文件系统访问 | ⚠️ 是 |

> **警告**：声明危险权限的插件在启用时会显示安全警告弹窗，用户必须明确确认才能启用。

---

## 扩展点详解

### 1. 工具栏扩展 (toolbar)

在 Markdown 编辑器工具栏添加自定义按钮。

```json
{
  "extensions": {
    "toolbar": [
      {
        "id": "callout",
        "icon": "info",
        "tooltip": "插入提示框",
        "insertBefore": "> [!NOTE]\n> ",
        "insertAfter": "\n",
        "group": "blocks",
        "priority": 50
      }
    ]
  }
}
```

**可用图标**：`code`, `format_quote`, `link`, `image`, `table_chart`, `checklist`, `format_bold`, `format_italic`, `info`, `warning`, `error`, `star`, `favorite` 等 Material Icons 名称。

### 2. 主题扩展 (theme)

添加自定义主题配色方案。

```json
{
  "extensions": {
    "theme": {
      "id": "dracula",
      "name": "德古拉",
      "light": {
        "primary": "#BD93F9",
        "secondary": "#FF79C6",
        "surface": "#F8F8F2",
        "background": "#FFFFFF"
      },
      "dark": {
        "primary": "#BD93F9",
        "secondary": "#FF79C6",
        "surface": "#44475A",
        "background": "#282A36"
      }
    }
  }
}
```

### 3. 预览扩展 (preview)

自定义 Markdown 预览的样式。

```json
{
  "extensions": {
    "preview": {
      "id": "custom-preview",
      "css": "h1 { color: #BD93F9; } code { background: #44475A; }",
      "codeTheme": "dracula",
      "fontFamily": "JetBrains Mono",
      "lineHeight": 1.8
    }
  }
}
```

### 4. 导出扩展 (export)

添加自定义导出格式。

```json
{
  "extensions": {
    "export": {
      "id": "latex",
      "name": "LaTeX",
      "extension": "tex",
      "template": "assets/latex-template.tex",
      "mimeType": "application/x-latex"
    }
  }
}
```

### 5. 编辑器扩展 (editor)

修改编辑器行为。

```json
{
  "extensions": {
    "editor": {
      "id": "vim-mode",
      "autoComplete": [
        {"trigger": "```", "completion": "```\n\n```", "cursorOffset": -4}
      ],
      "indentSize": 2,
      "useTabs": false
    }
  }
}
```

### 6. 文件操作扩展 (file_actions)

在文件上下文菜单添加操作（需要 `file_actions` 权限）。

```json
{
  "extensions": {
    "file_actions": [
      {
        "id": "upload-to-cloud",
        "name": "上传到云端",
        "icon": "upload",
        "type": "upload",
        "extensions": ["md", "txt"]
      }
    ]
  }
}
```

### 7. 导航扩展 (navigation)

添加自定义导航项。

```json
{
  "extensions": {
    "navigation": {
      "id": "plugin-dashboard",
      "title": "插件面板",
      "icon": "dashboard",
      "position": "tab",
      "contentType": "webview",
      "contentPath": "assets/dashboard.html"
    }
  }
}
```

### 8. 快捷键扩展 (shortcuts)

注册自定义快捷键。

```json
{
  "extensions": {
    "shortcuts": [
      {
        "id": "insert-date",
        "description": "插入当前日期",
        "keys": ["ctrl", "d"],
        "actionType": "insertText",
        "actionParams": {"text": "{{DATE}}"}
      }
    ]
  }
}
```

### 9. Widget扩展 (widgets)

在应用特定位置注入自定义 Widget。

```json
{
  "extensions": {
    "widgets": [
      {
        "id": "promo-banner",
        "injectionPoint": "homeTab",
        "type": "banner",
        "config": {
          "title": "新功能上线",
          "subtitle": "点击了解更多"
        }
      }
    ]
  }
}
```

### 10. 多语言扩展 (localization)

提供翻译或添加新语言。

```json
{
  "extensions": {
    "localization": {
      "id": "japanese",
      "locales": ["ja"],
      "translations": {
        "ja": {
          "settings": "設定",
          "editor": "エディター"
        }
      }
    }
  }
}
```

---

## 打包与发布

### 打包

将插件目录压缩为 ZIP 文件：

```bash
cd my-plugin
zip -r ../my-plugin.zip .
```

### 本地测试

1. 打开汐应用
2. 进入 设置 → 插件
3. 点击"导入本地插件"
4. 选择 ZIP 文件

### 发布到官方市场

1. Fork 官方仓库：https://github.com/jiuxina/ushio-md-plugins
2. 将插件 ZIP 放入 `plugins/` 目录
3. 更新 `plugins.json` 添加插件信息
4. 提交 Pull Request

---

## 最佳实践

1. **唯一ID**：使用 `author.plugin-name` 格式避免冲突
2. **语义化版本**：遵循 SemVer (1.0.0, 1.1.0, 2.0.0)
3. **最小权限**：只申请必要的权限
4. **清晰描述**：帮助用户理解插件功能
5. **提供图标**：128x128 PNG 格式

---

## 示例插件

### GitHub 风格提示框

```json
{
  "id": "example.github-alerts",
  "name": "GitHub 风格提示框",
  "version": "1.0.0",
  "author": "Example",
  "description": "快速插入 GitHub 风格的 NOTE/TIP/WARNING 提示框",
  "permissions": ["toolbar"],
  "extensions": {
    "toolbar": [
      {
        "id": "note",
        "icon": "info",
        "tooltip": "NOTE 提示",
        "insertBefore": "> [!NOTE]\n> ",
        "insertAfter": "\n"
      },
      {
        "id": "tip",
        "icon": "tips_and_updates",
        "tooltip": "TIP 提示",
        "insertBefore": "> [!TIP]\n> ",
        "insertAfter": "\n"
      },
      {
        "id": "warning",
        "icon": "warning",
        "tooltip": "WARNING 警告",
        "insertBefore": "> [!WARNING]\n> ",
        "insertAfter": "\n"
      }
    ]
  }
}
```

---

## 问题反馈

- GitHub Issues: https://github.com/jiuxina/ushio-md/issues
- 开发者交流群：（待添加）

---

*最后更新：2026年1月*
