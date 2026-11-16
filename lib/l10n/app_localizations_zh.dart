// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => '汐';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get invalidRange => '请输入有效范围内的数值';

  @override
  String get save => '保存';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get preview => '预览';

  @override
  String get search => '搜索';

  @override
  String get searchContent => '搜索内容...';

  @override
  String get closeSearch => '关闭搜索';

  @override
  String get noMatch => '未找到匹配';

  @override
  String get previous => '上一个';

  @override
  String get next => '下一个';

  @override
  String get startWriting => '开始编写你的 Markdown 内容...';

  @override
  String get tableOfContents => '目录';

  @override
  String get settings => '设置';

  @override
  String get homeTab => '首页';

  @override
  String get myFiles => '我的文件';

  @override
  String get historyTab => '历史';

  @override
  String get firstLaunchInitializing => '首次启动初始化中';

  @override
  String get firstLaunchWarmingUp =>
      '正在预热文档预览与缓存组件。首次完成后，再打开大型 Markdown 文档会更稳定、更快。';

  @override
  String get firstLaunchComplete => '首次启动初始化完成，后续打开文档会更快。';

  @override
  String newVersionFound(String version) {
    return '发现新版本';
  }

  @override
  String get view => '查看';

  @override
  String get editor => '编辑器';

  @override
  String get storage => '存储';

  @override
  String get appearance => '外观';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get fontSize => '字体大小';

  @override
  String get editorFont => '编辑器字体';

  @override
  String get lineHeight => '行高';

  @override
  String get letterSpacing => '字间距';

  @override
  String get paragraphSpacing => '段落间距';

  @override
  String get autoSave => '自动保存';

  @override
  String get autoSaveInterval => '自动保存间隔';

  @override
  String get seconds => '秒';

  @override
  String get language => '语言';

  @override
  String get languageZh => '中文';

  @override
  String get languageEn => 'English';

  @override
  String get cloudSync => '云同步';

  @override
  String get webdav => 'WebDAV';

  @override
  String get ftp => 'FTP';

  @override
  String get syncNow => '立即同步';

  @override
  String get syncing => '同步中...';

  @override
  String get newFolder => '新建文件夹';

  @override
  String get rename => '重命名';

  @override
  String get copy => '复制';

  @override
  String get paste => '粘贴';

  @override
  String get share => '分享';

  @override
  String get exportAsPdf => '导出为 PDF';

  @override
  String get generatingPdf => '正在生成 PDF...';

  @override
  String get insert => '插入';

  @override
  String get untitled => '未命名';

  @override
  String get unsavedChanges => '有未保存的更改';

  @override
  String get folderNotFound => '文件夹不存在';

  @override
  String get protectedDirectory => '无法访问该目录';

  @override
  String get protectedDirectoryHint =>
      '该目录受 Android 系统保护，请选择其他目录（如 Documents 或应用工作区）';

  @override
  String get updateNow => '立即更新';

  @override
  String get later => '稍后';

  @override
  String get version => '版本';

  @override
  String get about => '关于';

  @override
  String get lineNumber => '行号';

  @override
  String get bold => '粗体';

  @override
  String get italic => '斜体';

  @override
  String get strikethrough => '删除线';

  @override
  String get heading1 => '一级标题';

  @override
  String get heading2 => '二级标题';

  @override
  String get heading3 => '三级标题';

  @override
  String get bulletList => '无序列表';

  @override
  String get orderedList => '有序列表';

  @override
  String get taskList => '任务列表';

  @override
  String get blockquote => '引用';

  @override
  String get code => '代码';

  @override
  String get inlineCode => '行内代码';

  @override
  String get codeBlock => '代码块';

  @override
  String get link => '链接';

  @override
  String get image => '图片';

  @override
  String get horizontalRule => '分隔线';

  @override
  String get table => '表格';

  @override
  String get undo => '撤销';

  @override
  String get redo => '重做';

  @override
  String get editorBackground => '编辑器背景';

  @override
  String get selectImage => '选择图片';

  @override
  String get clearBackground => '清除背景';

  @override
  String get backgroundBlur => '背景模糊';

  @override
  String get backgroundBrightness => '背景亮度';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeColor => '主题色';

  @override
  String get uiStyleOpacityHint => '透明度过低时液态玻璃会变得不明显，可适当提高卡片透明度';

  @override
  String get uiStyle => 'UI风格';

  @override
  String get uiStyleClassic => '经典描边';

  @override
  String get uiStyleClassicDesc => '保留当前的实线边框按钮样式';

  @override
  String get uiStyleSoftShadow => '简洁立体';

  @override
  String get uiStyleSoftShadowDesc => '柔和阴影的立体按钮效果';

  @override
  String get uiStyleLiquidGlass => '液态玻璃';

  @override
  String get uiStyleLiquidGlassDesc => '波动折射的玻璃质感，自动适配卡片透明度';

  @override
  String get cardOpacity => '卡片透明度';

  @override
  String get lightTheme => '浅色主题';

  @override
  String get darkTheme => '夜间主题';

  @override
  String get font => '字体';

  @override
  String get background => '背景';

  @override
  String get appIcon => '桌面图标';

  @override
  String get homeIcon => '主页图标';

  @override
  String get opacity => '透明度';

  @override
  String get homeTitle => '主页标题';

  @override
  String get bottomNavBar => '底部导航栏';

  @override
  String get clearImage => '清除图片';

  @override
  String get blurEffect => '模糊效果';

  @override
  String get blurStrength => '模糊强度';

  @override
  String get defaultIcon => '默认';

  @override
  String get customImage => '自定义图片';

  @override
  String get uiFont => '界面字体';

  @override
  String get customFont => '代码块字体';

  @override
  String get installFont => '安装自定义字体';

  @override
  String get fontInstalled => '字体安装成功';

  @override
  String get editorSettings => '编辑器设置';

  @override
  String current(int size) {
    return '当前: $size';
  }

  @override
  String get sampleText => '示例文字';

  @override
  String get enableAutoSave => '启用自动保存';

  @override
  String get saveInterval => '保存间隔';

  @override
  String get permanentFloatingButtons => '浮动按钮显示方式';

  @override
  String get floatingButtonsAuto => '智能隐藏';

  @override
  String get floatingButtonsAutoDesc => '滚动或点击时自动隐藏，静止后显示';

  @override
  String get floatingButtonsAlways => '始终显示';

  @override
  String get floatingButtonsAlwaysDesc => '浮动按钮始终显示在右下角';

  @override
  String get floatingButtonsNever => '始终隐藏';

  @override
  String get floatingButtonsNeverDesc => '隐藏浮动按钮，可通过工具栏或快捷键操作';

  @override
  String get minutes => '分钟';

  @override
  String get openSource => '开源地址';

  @override
  String get openSourceLicense => '开放源代码许可';

  @override
  String get openSourceLicenseDesc => '查看项目使用的开源依赖及许可信息';

  @override
  String get updates => '更新';

  @override
  String get autoCheckUpdate => '启动时自动检查更新';

  @override
  String get updateChannel => '更新规则';

  @override
  String get updateChannelStable => '稳定版';

  @override
  String get updateChannelPrerelease => '测试版';

  @override
  String get updateChannelStableDesc => '仅检查 GitHub latest 稳定版';

  @override
  String get updateChannelPrereleaseDesc => '优先检查最新 pre-release';

  @override
  String get autoCheckUpdateDesc => '有新版本时显示提示';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get checkForUpdatesDesc => '检查是否有新版本';

  @override
  String get updateProxies => '下载代理';

  @override
  String get updateProxiesNotConfigured => '未添加，将直连下载';

  @override
  String updateProxiesConfigured(int count) {
    return '已添加 $count 个，按顺序尝试';
  }

  @override
  String get updateProxiesManage => '管理';

  @override
  String get updateProxiesEmpty => '暂无代理，更新时将直连下载';

  @override
  String get updateProxiesHint => '最终下载地址 = 代理前缀 + 原始下载链接';

  @override
  String get updateProxyExampleNote => '示例（无效占位地址，仅供格式参考）';

  @override
  String get addUpdateProxy => '添加代理';

  @override
  String get editUpdateProxy => '编辑代理';

  @override
  String get updateProxyInvalid => '请输入以 http:// 或 https:// 开头的完整地址';

  @override
  String get updateProxyDuplicate => '该代理已在列表中';

  @override
  String get upToDate => '已是最新版本';

  @override
  String checkUpdateFailed(String error) {
    return '检查更新失败: $error';
  }

  @override
  String newVersionAvailable(String version) {
    return '新版本 $version 已发布，是否立即更新？';
  }

  @override
  String get downloadingUpdate => '正在下载更新';

  @override
  String get downloadingWithProxy => '使用自定义代理下载中...';

  @override
  String get downloadFailed => '下载或安装失败，建议手动下载';

  @override
  String updateError(String error) {
    return '更新出错: $error';
  }

  @override
  String get foundNewVersion => '发现新版本';

  @override
  String get cloudSyncConfig => '云同步服务配置';

  @override
  String get syncServiceType => '同步服务类型';

  @override
  String get cloudFolderName => '云端文件夹名称';

  @override
  String get folderNameHelper => '修改此名称将重命名云端文件夹（不会创建新文件夹）';

  @override
  String get enterFolderName => '请输入文件夹名称';

  @override
  String get folderNameNoSlashes => '文件夹名称不能包含斜杠';

  @override
  String get cloudPathPrefix => '云端路径前缀（可选）';

  @override
  String get cloudPathHelper => '云端文件夹的完整路径会自动补齐为：路径前缀';

  @override
  String get testing => '测试中...';

  @override
  String get testConnection => '测试连接';

  @override
  String get saveConfig => '保存配置';

  @override
  String get connectionSuccess => '连接成功！';

  @override
  String get connectionFailed => '连接失败，请检查配置';

  @override
  String get serverAddress => '服务器地址';

  @override
  String get enterServerAddress => '请输入服务器地址';

  @override
  String get enterValidUrl => '请输入有效的 URL（以 http:// 或 https:// 开头）';

  @override
  String get username => '用户名';

  @override
  String get enterUsername => '请输入用户名';

  @override
  String get password => '密码';

  @override
  String get enterPassword => '请输入密码';

  @override
  String get ftpServerAddress => 'FTP 服务器地址';

  @override
  String get enterFtpServer => '请输入FTP服务器地址';

  @override
  String get addressShouldStartWithFtp => '地址应以 ftp:// 开头';

  @override
  String get enterValidHost => '请输入有效的主机地址';

  @override
  String get invalidFormat => '格式错误，应为 ftp://主机:端口';

  @override
  String get portRange => '端口号应在 1-65535 之间';

  @override
  String get syncControls => '同步控制';

  @override
  String get autoSync => '自动同步';

  @override
  String get autoSyncDescription => '保存文件时自动上传到云端';

  @override
  String get syncStatus => '同步状态';

  @override
  String get syncService => '同步服务';

  @override
  String get configStatus => '配置状态';

  @override
  String get configured => '已配置';

  @override
  String get notConfigured => '未配置';

  @override
  String get lastSync => '上次同步';

  @override
  String get neverSynced => '从未同步';

  @override
  String get justNow => '刚刚';

  @override
  String minutesAgo(int count) {
    return '$count 分钟前';
  }

  @override
  String hoursAgo(int count) {
    return '$count 小时前';
  }

  @override
  String get configSaved => '配置已保存';

  @override
  String get cannotConnectServer => '无法连接到服务器';

  @override
  String syncComplete(int uploaded, int downloaded, String deleted) {
    return '同步完成：上传 $uploaded，下载 $downloaded$deleted';
  }

  @override
  String get syncPreview => '同步预览';

  @override
  String willUpload(int count) {
    return '📤 将上传 $count 个文件';
  }

  @override
  String willDownload(int count) {
    return '📥 将下载 $count 个文件';
  }

  @override
  String conflictWarning(int count) {
    return '⚠️ $count 个文件存在冲突';
  }

  @override
  String get conflictDescription => '这些文件在本地和云端都有修改，请选择保留哪个版本：';

  @override
  String get keepLocal => '保留本地';

  @override
  String get keepRemote => '保留云端';

  @override
  String get skip => '跳过';

  @override
  String get localVersion => '本地';

  @override
  String get cloudVersion => '云端';

  @override
  String get startSync => '开始同步';

  @override
  String get storageSettings => '存储设置';

  @override
  String get storagePermissionTitle => '「所有文件访问」权限';

  @override
  String get storagePermissionDesc => '用于浏览、编辑和保存设备上的 Markdown 文件。';

  @override
  String get storagePermissionCan => '授权后可直接读写手机任意文件夹中的笔记。';

  @override
  String get storagePermissionWithout => '未授权时只能访问应用私有目录，已有笔记无法打开。';

  @override
  String get grantStoragePermission => '去授予权限';

  @override
  String get openSystemSettings => '打开系统设置';

  @override
  String get storagePermissionManualHint => 'Android 11 及以上需在系统设置中手动开启。';

  @override
  String get storagePermissionDenied => '请在设置中授予存储权限';

  @override
  String get openSettings => '打开设置';

  @override
  String get workspace => '工作区';

  @override
  String get newFileDefaultLocation => '新建文件默认位置';

  @override
  String get notSetUseCurrentOrRecent => '未设置 (默认使用当前或最近位置)';

  @override
  String get change => '更改';

  @override
  String get defaultLocationReset => '已重置默认位置';

  @override
  String get cleanup => '清理';

  @override
  String get clearRecentFiles => '清除最近文件';

  @override
  String get clearRecentFolders => '清除最近文件夹';

  @override
  String get loading => '加载中...';

  @override
  String get workspaceFolderName => '工作区文件夹名称';

  @override
  String get customBasePathAdvanced => '自定义基础路径（高级）';

  @override
  String get useDefaultPath => '使用默认路径';

  @override
  String get reset => '重置';

  @override
  String get workspaceFilesSyncToCloud => '工作区文件会自动同步到云端';

  @override
  String filesCount(int count) {
    return '$count 个文件';
  }

  @override
  String foldersCount(int count) {
    return '$count 个文件夹';
  }

  @override
  String get clear => '清除';

  @override
  String get confirmClearRecentFiles => '确定要清除所有最近访问的文件记录吗？';

  @override
  String get confirmClearRecentFolders => '确定要清除所有最近访问的文件夹记录吗？';

  @override
  String get cleared => '已清除';

  @override
  String get changeWorkspaceName => '更改工作区名称';

  @override
  String get inputWorkspaceFolderName => '输入新的工作区文件夹名称：';

  @override
  String get warningChangeNameRequiresCloudSync => '注意：更改名称后需要重新配置云同步';

  @override
  String get nameCannotBeEmpty => '名称不能为空';

  @override
  String get nameCannotContainSlash => '名称不能包含斜杠';

  @override
  String workspaceNameUpdated(String name) {
    return '工作区名称已更新为 $name';
  }

  @override
  String get customBasePath => '自定义基础路径';

  @override
  String get inputCustomBasePath => '输入自定义的基础路径：';

  @override
  String defaultPath(String path) {
    return '默认路径：$path';
  }

  @override
  String get warningChangeBasePathAffectsWorkspace =>
      '警告：更改基础路径将影响工作区位置，请确保路径存在且可访问';

  @override
  String get resetToDefaultPath => '已重置为默认路径';

  @override
  String get basePathUpdated => '基础路径已更新';

  @override
  String get saveSuccess => '已保存';

  @override
  String saveFailedWithError(String error) {
    return '保存失败: $error';
  }

  @override
  String get unsavedChangesMessage => '您有未保存的更改，要保存吗？';

  @override
  String get discard => '放弃';

  @override
  String get noMatchContent => '未找到匹配内容';

  @override
  String wordCount(int chars, int glyphs, int words) {
    return '$chars 字符 · $glyphs 文字 · $words 单词';
  }

  @override
  String get ftpFormatHelper => '格式：ftp://主机:端口';

  @override
  String get icon2 => '图标 2';

  @override
  String get hidden => '隐藏';

  @override
  String get homeIconSelectorHint => '选择主页左上角显示的图标';

  @override
  String get appIconAndroidOnly => '注意：自定义图标仅 Android 可用';

  @override
  String get appIconChanged => '图标已更换';

  @override
  String get appIconChangeFailed => '图标更换失败';

  @override
  String get selectFromGallery => '从相册选择';

  @override
  String get homeTitleHint => '自定义主页图标旁显示的文字';

  @override
  String get appIconSelectorHint => '选择在主屏幕显示的应用图标';

  @override
  String get brightness => '亮度';

  @override
  String get noHeadingsFound => '没有找到标题';

  @override
  String get clearHistory => '清空历史';

  @override
  String get clearHistoryConfirm => '清空历史记录';

  @override
  String clearHistoryConfirmMessage(String type) {
    return '确定要清空所有最近$type记录吗？';
  }

  @override
  String get file => '文件';

  @override
  String get folder => '文件夹';

  @override
  String get files => '文件';

  @override
  String get noRecentFiles => '没有最近打开的文件';

  @override
  String get noRecentFolders => '没有最近文件夹';

  @override
  String get newMarkdown => '新建 Markdown';

  @override
  String get createFolder => '新建文件夹';

  @override
  String get folderName => '文件夹名称';

  @override
  String get createFailed => '创建失败';

  @override
  String get create => '创建';

  @override
  String get loadFailed => '加载失败';

  @override
  String get folderEmpty => '此文件夹为空';

  @override
  String get noMatchingFiles => '没有找到匹配的文件';

  @override
  String fileCount(int count) {
    return '$count 个文件';
  }

  @override
  String get searchFiles => '搜索文件...';

  @override
  String get sortBy => '排序方式';

  @override
  String get customSort => '自定义排序';

  @override
  String get nameAZ => '名称 A-Z';

  @override
  String get nameZA => '名称 Z-A';

  @override
  String get recentModified => '最近修改';

  @override
  String get oldestModified => '最早修改';

  @override
  String get largestFirst => '最大优先';

  @override
  String get smallestFirst => '最小优先';

  @override
  String get cardColor => '卡片颜色';

  @override
  String get customCardColor => '自定义卡片颜色';

  @override
  String get useThemeDefault => '使用主题默认';

  @override
  String get cardAppearance => '卡片外观';

  @override
  String get codeBlockTheme => '代码块主题';

  @override
  String get codeBlockThemeAuto => '跟随应用主题';

  @override
  String get codeBlockThemeOneDark => 'One Dark';

  @override
  String get codeBlockThemeOneLight => 'One Light';

  @override
  String get codeBlockThemeGithubDark => 'GitHub Dark';

  @override
  String get codeBlockThemeGithubLight => 'GitHub Light';

  @override
  String get codeBlockThemeNord => 'Nord';

  @override
  String get codeBlockThemeMaterial => 'Material';

  @override
  String get customThemeColor => '自定义主题色';

  @override
  String get accentFromImage => '从图片取色';

  @override
  String get accentFromImageFailed => '无法从该图片提取颜色';

  @override
  String get letterSpacingDesc => '调整文字之间的水平间距';

  @override
  String get paragraphSpacingDesc => '调整段落之间的垂直间距';

  @override
  String get lineHeightDesc => '调整文本行与行之间的垂直间距';

  @override
  String get startupBehavior => '启动行为';

  @override
  String get startupShowBlank => '显示空白页';

  @override
  String get startupRestoreLast => '恢复上次文件';

  @override
  String get startupRestoreLastDesc => '自动打开上次编辑的文件';

  @override
  String get saveOnExit => '退出时保存';

  @override
  String get enableSaveOnExit => '退出时自动保存';

  @override
  String get saveOnExitDesc => '退出文档时自动保存未保存的更改';

  @override
  String get onOpen => '启动时';

  @override
  String get uiFontColor => '界面字体颜色';

  @override
  String get customUiFontColor => '自定义字体颜色';

  @override
  String get globalIconColor => '全局图标颜色';

  @override
  String get customGlobalIconColor => '自定义全局图标颜色';

  @override
  String get globalIconColorDesc => '开启后，应用内所有图标统一使用所选颜色';

  @override
  String get editorFontColor => '编辑器文字颜色';

  @override
  String get customEditorFontColor => '自定义文字颜色';

  @override
  String get editorFontColorDesc => '作用于文档正文与编辑区，不影响界面文字';

  @override
  String get previewText => '预览文字';

  @override
  String get colorThemeSettings => '配色与主题';

  @override
  String get colorThemeSettingsDesc => '主题模式、强调色、浅色与深色配色方案';

  @override
  String get textAndFontSettings => '文字与字体';

  @override
  String get textAndFontSettingsDesc => '语言、字体、界面与编辑器文字颜色、代码块主题';

  @override
  String get surfaceAndBackgroundSettings => '表面与背景';

  @override
  String get surfaceAndBackgroundSettingsDesc => 'UI 风格、卡片、图标、导航栏、背景与首页外观';

  @override
  String get downloadFont => '下载字体';

  @override
  String downloadFontConfirm(String fontName) {
    return '是否下载「$fontName」字体？';
  }

  @override
  String get downloadFontNote => '字体将从网络下载，首次使用需要网络连接。';

  @override
  String get download => '下载';

  @override
  String downloadingFont(String fontName) {
    return '正在下载「$fontName」...';
  }

  @override
  String fontDownloadSuccess(String fontName) {
    return '「$fontName」下载完成';
  }

  @override
  String get selectItems => '选择项目';

  @override
  String selectedItemCount(int count) {
    return '已选择 $count 项';
  }

  @override
  String get selectAllItems => '全选';

  @override
  String get invertSelection => '反选';

  @override
  String get moveSelectedItems => '移动';

  @override
  String get deleteSelectedItems => '删除';

  @override
  String deleteSelectedConfirmation(int count) {
    return '删除所选的 $count 项？此操作不可撤销。';
  }

  @override
  String batchOperationSummary(int succeeded, int failed) {
    return '成功 $succeeded 项，失败 $failed 项';
  }

  @override
  String get batchOperationFailed => '部分项目未完成';

  @override
  String get destinationConflict => '目标已存在同名项目或版本历史';

  @override
  String get invalidMoveDestination => '不能移动到自身或子目录';

  @override
  String get missingFileItem => '项目或目标文件夹不存在';

  @override
  String get switchToSource => '切换到源码编辑';

  @override
  String get switchToPreview => '切换到渲染编辑';

  @override
  String fontDownloadFailed(String fontName) {
    return '「$fontName」下载失败，请检查网络';
  }
}
