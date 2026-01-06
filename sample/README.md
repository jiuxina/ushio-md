# 汐 - 官方插件市场

这是汐（Ushio-MD）Markdown 编辑器的官方插件仓库。

## 使用方式

1. 打开汐应用
2. 进入 **设置** → **插件** → **官方市场**
3. 浏览并安装感兴趣的插件

## 插件列表

| 插件名称 | 描述 | 版本 |
|----------|------|------|
| GitHub 风格提示框 | NOTE/TIP/WARNING 等提示框 | 1.0.0 |
| 代码块增强 | 快速插入编程语言代码块 | 1.0.0 |

## 提交插件

欢迎开发者提交插件！请参阅 [插件开发指南](https://github.com/jiuxina/ushio-md/blob/main/PLUGIN_DEVELOPMENT.md)。

### 提交流程

1. Fork 本仓库
2. 在 `plugins/` 目录下创建您的插件文件夹
3. 添加 `manifest.json` 和必要资源
4. 打包为 ZIP 文件
5. 更新 `plugins.json` 添加您的插件信息
6. 提交 Pull Request

## 目录结构

```
ushio-md-plugins/
├── plugins.json           # 插件索引
└── plugins/
    ├── github-alerts/
    │   ├── manifest.json
    │   └── icon.png
    └── code-blocks/
        ├── manifest.json
        └── icon.png
```

## 许可证

MIT License
