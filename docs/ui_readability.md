# 弹窗与卡片可读性

## 公共表面

`AppStyleTheme.resolveSurface` 在渲染时生成独立于用户保存设置的内容配色。
`SurfaceRole.card` 的衬底 alpha 至少为 0.88，`modal` 至少为 0.94；
`inset` 是父级表面的不透明色阶。玻璃折射保留在内容衬底下方，不重复叠加玻璃。

普通文字与辅助说明的合成对比度至少为 4.5:1，必要图标、边界至少为 3:1。
解析器同时检查黑白背板，优先保留可读的用户色；无法同时满足时增加衬底 alpha。
该过程不采集图片或屏幕像素，不读取和改写用户设置。

需要显式读取颜色的内容应使用 `AppSurface.builder`、
`SettingsSection.builder` 或在区块内构建的 `Builder`，避免提前读取外层主题。
普通说明使用 `onSurfaceVariant`；`outline` 用于装饰边界。
选中状态使用 `primaryContainer` / `onPrimaryContainer`，错误状态使用相应 error 色对。

`showAppDialog` 与 `showAppModalBottomSheet` 提供局部弹层主题。
面板统一处理安全区、键盘避让和长内容滚动；确认返回值和业务回调保留原含义。
专用媒体查看器和颜色样本保留其展示语义。

## 编辑器内部浮层

Web 浮层通过现有主题载荷的 `overlay*` 颜色独立配色，正文、代码主题及文档
背景沿用原来的字段。`overlaySurface` 使用 RGBA；选中和悬停状态使用
`overlayPrimaryContainer` / `overlayOnPrimaryContainer` 成对的颜色。
旧载荷缺少新字段时，CSS 提供独立的浅深色默认值。

链接、右键、表格、Slash 菜单及图片/代码操作控件共用这些颜色。
链接提示允许长 URL 换行和滚动；浮层位置与可滚动高度共用同一可见区域计算，
同时考虑浏览器视口与 Flutter 的键盘、顶部栏、工具栏，避免重复扣除键盘高度。

源码修改后必须构建完整的平铺资源目录，再使用
`scripts/sync_milkdown_assets.ps1` 同步；只复制 `index.html` 不会更新完整运行时。
同步脚本在替换前将旧资源目录送入回收站。

## 验证约定

- 配色矩阵覆盖全部预设、三种风格、透明度 0.4/0.7/1.0、相反明暗自定义色。
- 布局矩阵覆盖 320/600/1280 逻辑像素宽度与 100%/200% 系统文字缩放。
- 修改期间仅运行相关定向验证；实现与文档完成后，全量测试各运行一次。
- 模拟器使用独立应用 ID 的合成界面，避免加载个人工作区或已有配置。

## 合成验收入口

`tools/readability_regression_app.dart` 不运行正常应用初始化，不初始化设置或文件
provider，不加载已有偏好、个人目录或云端配置。它用程序生成的背景与文档展示
共享卡片、对话框、面板及实际 Web 浮层。对外导航被限制为本地资源服务器。

在 PowerShell 中构建独立调试包（项目 Gradle 属性仅影响 debug 包名）：

```powershell
Push-Location android
.\gradlew.bat :app:assembleDebug -PreadabilityHarness=true `
  '-Ptarget=tools/readability_regression_app.dart' --no-daemon
Pop-Location
```

验收包应用 ID 为 `com.ushiomd.readability`，与正常应用隔离。安装后切换浅深色、
三种风格、黑白卡片、棋盘背景、320 宽度及 200% 字号，检查卡片、输入框、
确认弹窗、底部面板、链接提示及表格操作。输入内容只用于合成界面，不保存。

正常应用人工检查路径：最近文件卡片；文件长按菜单与新建/重命名表单；
设置中的文字与字体、表面与背景、编辑器、存储、云同步预览及关于页；
编辑器的目录、搜索、版本历史/差异、链接与表格操作浮层。

可通过定向命令生成共享组件的棋盘背景渲染图：

```powershell
flutter test --no-pub test/widgets/readable_surface_visual_test.dart --dart-define=READABILITY_CAPTURE=true
```

图片写入 `build/readability/captures/`；widget 测试默认字体用于布局验证，
文字字形和真实玻璃渲染仍需以上独立 Android 验收入口检查。
