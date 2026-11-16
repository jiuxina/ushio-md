import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// 应用名称
  ///
  /// In zh, this message translates to:
  /// **'汐'**
  String get appName;

  /// 取消按钮
  ///
  /// In zh, this message translates to:
  /// **'取消'**
  String get cancel;

  /// 确认按钮
  ///
  /// In zh, this message translates to:
  /// **'确认'**
  String get confirm;

  /// 输入数值超出范围提示
  ///
  /// In zh, this message translates to:
  /// **'请输入有效范围内的数值'**
  String get invalidRange;

  /// 保存按钮
  ///
  /// In zh, this message translates to:
  /// **'保存'**
  String get save;

  /// 删除按钮
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get delete;

  /// 编辑按钮
  ///
  /// In zh, this message translates to:
  /// **'编辑'**
  String get edit;

  /// 预览模式
  ///
  /// In zh, this message translates to:
  /// **'预览'**
  String get preview;

  /// 搜索
  ///
  /// In zh, this message translates to:
  /// **'搜索'**
  String get search;

  /// 搜索内容提示
  ///
  /// In zh, this message translates to:
  /// **'搜索内容...'**
  String get searchContent;

  /// 关闭搜索按钮
  ///
  /// In zh, this message translates to:
  /// **'关闭搜索'**
  String get closeSearch;

  /// 搜索无匹配
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配'**
  String get noMatch;

  /// 上一个匹配
  ///
  /// In zh, this message translates to:
  /// **'上一个'**
  String get previous;

  /// 下一个匹配
  ///
  /// In zh, this message translates to:
  /// **'下一个'**
  String get next;

  /// 编辑器空状态提示
  ///
  /// In zh, this message translates to:
  /// **'开始编写你的 Markdown 内容...'**
  String get startWriting;

  /// 目录标题
  ///
  /// In zh, this message translates to:
  /// **'目录'**
  String get tableOfContents;

  /// 设置
  ///
  /// In zh, this message translates to:
  /// **'设置'**
  String get settings;

  /// 首页Tab标签
  ///
  /// In zh, this message translates to:
  /// **'首页'**
  String get homeTab;

  /// 我的文件部分
  ///
  /// In zh, this message translates to:
  /// **'我的文件'**
  String get myFiles;

  /// 历史Tab标签
  ///
  /// In zh, this message translates to:
  /// **'历史'**
  String get historyTab;

  /// 首次启动初始化对话框标题
  ///
  /// In zh, this message translates to:
  /// **'首次启动初始化中'**
  String get firstLaunchInitializing;

  /// 首次启动预热消息
  ///
  /// In zh, this message translates to:
  /// **'正在预热文档预览与缓存组件。首次完成后，再打开大型 Markdown 文档会更稳定、更快。'**
  String get firstLaunchWarmingUp;

  /// 首次启动完成消息
  ///
  /// In zh, this message translates to:
  /// **'首次启动初始化完成，后续打开文档会更快。'**
  String get firstLaunchComplete;

  /// 发现新版本消息
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String newVersionFound(String version);

  /// 查看按钮标签
  ///
  /// In zh, this message translates to:
  /// **'查看'**
  String get view;

  /// 编辑器设置
  ///
  /// In zh, this message translates to:
  /// **'编辑器'**
  String get editor;

  /// 存储设置
  ///
  /// In zh, this message translates to:
  /// **'存储'**
  String get storage;

  /// 外观设置
  ///
  /// In zh, this message translates to:
  /// **'外观'**
  String get appearance;

  /// 浅色主题
  ///
  /// In zh, this message translates to:
  /// **'浅色'**
  String get themeLight;

  /// 深色主题
  ///
  /// In zh, this message translates to:
  /// **'深色'**
  String get themeDark;

  /// 跟随系统主题
  ///
  /// In zh, this message translates to:
  /// **'跟随系统'**
  String get themeSystem;

  /// 字体大小设置
  ///
  /// In zh, this message translates to:
  /// **'字体大小'**
  String get fontSize;

  /// 编辑器字体设置
  ///
  /// In zh, this message translates to:
  /// **'编辑器字体'**
  String get editorFont;

  /// 行高设置
  ///
  /// In zh, this message translates to:
  /// **'行高'**
  String get lineHeight;

  /// 字间距设置
  ///
  /// In zh, this message translates to:
  /// **'字间距'**
  String get letterSpacing;

  /// 段落间距设置
  ///
  /// In zh, this message translates to:
  /// **'段落间距'**
  String get paragraphSpacing;

  /// 自动保存设置
  ///
  /// In zh, this message translates to:
  /// **'自动保存'**
  String get autoSave;

  /// 自动保存间隔设置
  ///
  /// In zh, this message translates to:
  /// **'自动保存间隔'**
  String get autoSaveInterval;

  /// 秒
  ///
  /// In zh, this message translates to:
  /// **'秒'**
  String get seconds;

  /// 语言设置
  ///
  /// In zh, this message translates to:
  /// **'语言'**
  String get language;

  /// 中文
  ///
  /// In zh, this message translates to:
  /// **'中文'**
  String get languageZh;

  /// 英文
  ///
  /// In zh, this message translates to:
  /// **'English'**
  String get languageEn;

  /// 云同步设置
  ///
  /// In zh, this message translates to:
  /// **'云同步'**
  String get cloudSync;

  /// WebDAV 同步
  ///
  /// In zh, this message translates to:
  /// **'WebDAV'**
  String get webdav;

  /// FTP 同步
  ///
  /// In zh, this message translates to:
  /// **'FTP'**
  String get ftp;

  /// 立即同步按钮
  ///
  /// In zh, this message translates to:
  /// **'立即同步'**
  String get syncNow;

  /// 同步中状态
  ///
  /// In zh, this message translates to:
  /// **'同步中...'**
  String get syncing;

  /// 新建文件夹
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get newFolder;

  /// 重命名
  ///
  /// In zh, this message translates to:
  /// **'重命名'**
  String get rename;

  /// 复制
  ///
  /// In zh, this message translates to:
  /// **'复制'**
  String get copy;

  /// 粘贴
  ///
  /// In zh, this message translates to:
  /// **'粘贴'**
  String get paste;

  /// 分享
  ///
  /// In zh, this message translates to:
  /// **'分享'**
  String get share;

  /// 导出为 PDF
  ///
  /// In zh, this message translates to:
  /// **'导出为 PDF'**
  String get exportAsPdf;

  /// 生成 PDF 中
  ///
  /// In zh, this message translates to:
  /// **'正在生成 PDF...'**
  String get generatingPdf;

  /// 插入按钮
  ///
  /// In zh, this message translates to:
  /// **'插入'**
  String get insert;

  /// 未命名文件
  ///
  /// In zh, this message translates to:
  /// **'未命名'**
  String get untitled;

  /// 未保存更改提示
  ///
  /// In zh, this message translates to:
  /// **'有未保存的更改'**
  String get unsavedChanges;

  /// 文件夹不存在错误
  ///
  /// In zh, this message translates to:
  /// **'文件夹不存在'**
  String get folderNotFound;

  /// 受保护目录访问失败提示
  ///
  /// In zh, this message translates to:
  /// **'无法访问该目录'**
  String get protectedDirectory;

  /// 受保护目录访问失败详细说明
  ///
  /// In zh, this message translates to:
  /// **'该目录受 Android 系统保护，请选择其他目录（如 Documents 或应用工作区）'**
  String get protectedDirectoryHint;

  /// 立即更新按钮
  ///
  /// In zh, this message translates to:
  /// **'立即更新'**
  String get updateNow;

  /// 稍后按钮
  ///
  /// In zh, this message translates to:
  /// **'稍后'**
  String get later;

  /// 版本
  ///
  /// In zh, this message translates to:
  /// **'版本'**
  String get version;

  /// 关于
  ///
  /// In zh, this message translates to:
  /// **'关于'**
  String get about;

  /// 行号
  ///
  /// In zh, this message translates to:
  /// **'行号'**
  String get lineNumber;

  /// 粗体
  ///
  /// In zh, this message translates to:
  /// **'粗体'**
  String get bold;

  /// 斜体
  ///
  /// In zh, this message translates to:
  /// **'斜体'**
  String get italic;

  /// 删除线
  ///
  /// In zh, this message translates to:
  /// **'删除线'**
  String get strikethrough;

  /// 一级标题
  ///
  /// In zh, this message translates to:
  /// **'一级标题'**
  String get heading1;

  /// 二级标题
  ///
  /// In zh, this message translates to:
  /// **'二级标题'**
  String get heading2;

  /// 三级标题
  ///
  /// In zh, this message translates to:
  /// **'三级标题'**
  String get heading3;

  /// 无序列表
  ///
  /// In zh, this message translates to:
  /// **'无序列表'**
  String get bulletList;

  /// 有序列表
  ///
  /// In zh, this message translates to:
  /// **'有序列表'**
  String get orderedList;

  /// 任务列表
  ///
  /// In zh, this message translates to:
  /// **'任务列表'**
  String get taskList;

  /// 引用
  ///
  /// In zh, this message translates to:
  /// **'引用'**
  String get blockquote;

  /// 代码
  ///
  /// In zh, this message translates to:
  /// **'代码'**
  String get code;

  /// 行内代码
  ///
  /// In zh, this message translates to:
  /// **'行内代码'**
  String get inlineCode;

  /// 代码块
  ///
  /// In zh, this message translates to:
  /// **'代码块'**
  String get codeBlock;

  /// 链接
  ///
  /// In zh, this message translates to:
  /// **'链接'**
  String get link;

  /// 图片
  ///
  /// In zh, this message translates to:
  /// **'图片'**
  String get image;

  /// 分隔线
  ///
  /// In zh, this message translates to:
  /// **'分隔线'**
  String get horizontalRule;

  /// 表格
  ///
  /// In zh, this message translates to:
  /// **'表格'**
  String get table;

  /// 撤销
  ///
  /// In zh, this message translates to:
  /// **'撤销'**
  String get undo;

  /// 重做
  ///
  /// In zh, this message translates to:
  /// **'重做'**
  String get redo;

  /// 编辑器背景设置
  ///
  /// In zh, this message translates to:
  /// **'编辑器背景'**
  String get editorBackground;

  /// 选择图片
  ///
  /// In zh, this message translates to:
  /// **'选择图片'**
  String get selectImage;

  /// 清除背景
  ///
  /// In zh, this message translates to:
  /// **'清除背景'**
  String get clearBackground;

  /// 背景模糊设置
  ///
  /// In zh, this message translates to:
  /// **'背景模糊'**
  String get backgroundBlur;

  /// 背景亮度设置
  ///
  /// In zh, this message translates to:
  /// **'背景亮度'**
  String get backgroundBrightness;

  /// 主题模式设置
  ///
  /// In zh, this message translates to:
  /// **'主题模式'**
  String get themeMode;

  /// 主题色设置
  ///
  /// In zh, this message translates to:
  /// **'主题色'**
  String get themeColor;

  /// UI风格-透明度提示
  ///
  /// In zh, this message translates to:
  /// **'透明度过低时液态玻璃会变得不明显，可适当提高卡片透明度'**
  String get uiStyleOpacityHint;

  /// UI风格设置项标题
  ///
  /// In zh, this message translates to:
  /// **'UI风格'**
  String get uiStyle;

  /// UI风格-经典描边
  ///
  /// In zh, this message translates to:
  /// **'经典描边'**
  String get uiStyleClassic;

  /// UI风格-经典描边说明
  ///
  /// In zh, this message translates to:
  /// **'保留当前的实线边框按钮样式'**
  String get uiStyleClassicDesc;

  /// UI风格-简洁立体
  ///
  /// In zh, this message translates to:
  /// **'简洁立体'**
  String get uiStyleSoftShadow;

  /// UI风格-简洁立体说明
  ///
  /// In zh, this message translates to:
  /// **'柔和阴影的立体按钮效果'**
  String get uiStyleSoftShadowDesc;

  /// UI风格-液态玻璃
  ///
  /// In zh, this message translates to:
  /// **'液态玻璃'**
  String get uiStyleLiquidGlass;

  /// UI风格-液态玻璃说明
  ///
  /// In zh, this message translates to:
  /// **'波动折射的玻璃质感，自动适配卡片透明度'**
  String get uiStyleLiquidGlassDesc;

  /// 卡片透明度设置
  ///
  /// In zh, this message translates to:
  /// **'卡片透明度'**
  String get cardOpacity;

  /// 浅色主题方案
  ///
  /// In zh, this message translates to:
  /// **'浅色主题'**
  String get lightTheme;

  /// 夜间主题方案
  ///
  /// In zh, this message translates to:
  /// **'夜间主题'**
  String get darkTheme;

  /// 字体设置
  ///
  /// In zh, this message translates to:
  /// **'字体'**
  String get font;

  /// 背景设置
  ///
  /// In zh, this message translates to:
  /// **'背景'**
  String get background;

  /// 桌面图标设置
  ///
  /// In zh, this message translates to:
  /// **'桌面图标'**
  String get appIcon;

  /// 主页图标设置
  ///
  /// In zh, this message translates to:
  /// **'主页图标'**
  String get homeIcon;

  /// 透明度
  ///
  /// In zh, this message translates to:
  /// **'透明度'**
  String get opacity;

  /// 主页标题设置
  ///
  /// In zh, this message translates to:
  /// **'主页标题'**
  String get homeTitle;

  /// 底部导航栏设置
  ///
  /// In zh, this message translates to:
  /// **'底部导航栏'**
  String get bottomNavBar;

  /// 清除图片按钮
  ///
  /// In zh, this message translates to:
  /// **'清除图片'**
  String get clearImage;

  /// 模糊效果设置
  ///
  /// In zh, this message translates to:
  /// **'模糊效果'**
  String get blurEffect;

  /// 模糊强度设置
  ///
  /// In zh, this message translates to:
  /// **'模糊强度'**
  String get blurStrength;

  /// 默认图标选项
  ///
  /// In zh, this message translates to:
  /// **'默认'**
  String get defaultIcon;

  /// 自定义图片选项
  ///
  /// In zh, this message translates to:
  /// **'自定义图片'**
  String get customImage;

  /// 界面字体设置
  ///
  /// In zh, this message translates to:
  /// **'界面字体'**
  String get uiFont;

  /// 代码块字体选项
  ///
  /// In zh, this message translates to:
  /// **'代码块字体'**
  String get customFont;

  /// 安装自定义字体按钮
  ///
  /// In zh, this message translates to:
  /// **'安装自定义字体'**
  String get installFont;

  /// 字体安装成功提示
  ///
  /// In zh, this message translates to:
  /// **'字体安装成功'**
  String get fontInstalled;

  /// 编辑器设置页面标题
  ///
  /// In zh, this message translates to:
  /// **'编辑器设置'**
  String get editorSettings;

  /// 当前值指示器
  ///
  /// In zh, this message translates to:
  /// **'当前: {size}'**
  String current(int size);

  /// 示例文字
  ///
  /// In zh, this message translates to:
  /// **'示例文字'**
  String get sampleText;

  /// 启用自动保存开关标签
  ///
  /// In zh, this message translates to:
  /// **'启用自动保存'**
  String get enableAutoSave;

  /// 保存间隔设置标签
  ///
  /// In zh, this message translates to:
  /// **'保存间隔'**
  String get saveInterval;

  /// 浮动按钮显示方式设置标签
  ///
  /// In zh, this message translates to:
  /// **'浮动按钮显示方式'**
  String get permanentFloatingButtons;

  /// 智能隐藏选项
  ///
  /// In zh, this message translates to:
  /// **'智能隐藏'**
  String get floatingButtonsAuto;

  /// 智能隐藏选项描述
  ///
  /// In zh, this message translates to:
  /// **'滚动或点击时自动隐藏，静止后显示'**
  String get floatingButtonsAutoDesc;

  /// 始终显示选项
  ///
  /// In zh, this message translates to:
  /// **'始终显示'**
  String get floatingButtonsAlways;

  /// 始终显示选项描述
  ///
  /// In zh, this message translates to:
  /// **'浮动按钮始终显示在右下角'**
  String get floatingButtonsAlwaysDesc;

  /// 始终隐藏选项
  ///
  /// In zh, this message translates to:
  /// **'始终隐藏'**
  String get floatingButtonsNever;

  /// 始终隐藏选项描述
  ///
  /// In zh, this message translates to:
  /// **'隐藏浮动按钮，可通过工具栏或快捷键操作'**
  String get floatingButtonsNeverDesc;

  /// 分钟
  ///
  /// In zh, this message translates to:
  /// **'分钟'**
  String get minutes;

  /// No description provided for @openSource.
  ///
  /// In zh, this message translates to:
  /// **'开源地址'**
  String get openSource;

  /// No description provided for @openSourceLicense.
  ///
  /// In zh, this message translates to:
  /// **'开放源代码许可'**
  String get openSourceLicense;

  /// No description provided for @openSourceLicenseDesc.
  ///
  /// In zh, this message translates to:
  /// **'查看项目使用的开源依赖及许可信息'**
  String get openSourceLicenseDesc;

  /// No description provided for @updates.
  ///
  /// In zh, this message translates to:
  /// **'更新'**
  String get updates;

  /// No description provided for @autoCheckUpdate.
  ///
  /// In zh, this message translates to:
  /// **'启动时自动检查更新'**
  String get autoCheckUpdate;

  /// No description provided for @updateChannel.
  ///
  /// In zh, this message translates to:
  /// **'更新规则'**
  String get updateChannel;

  /// No description provided for @updateChannelStable.
  ///
  /// In zh, this message translates to:
  /// **'稳定版'**
  String get updateChannelStable;

  /// No description provided for @updateChannelPrerelease.
  ///
  /// In zh, this message translates to:
  /// **'测试版'**
  String get updateChannelPrerelease;

  /// No description provided for @updateChannelStableDesc.
  ///
  /// In zh, this message translates to:
  /// **'仅检查 GitHub latest 稳定版'**
  String get updateChannelStableDesc;

  /// No description provided for @updateChannelPrereleaseDesc.
  ///
  /// In zh, this message translates to:
  /// **'优先检查最新 pre-release'**
  String get updateChannelPrereleaseDesc;

  /// No description provided for @autoCheckUpdateDesc.
  ///
  /// In zh, this message translates to:
  /// **'有新版本时显示提示'**
  String get autoCheckUpdateDesc;

  /// No description provided for @checkForUpdates.
  ///
  /// In zh, this message translates to:
  /// **'检查更新'**
  String get checkForUpdates;

  /// No description provided for @checkForUpdatesDesc.
  ///
  /// In zh, this message translates to:
  /// **'检查是否有新版本'**
  String get checkForUpdatesDesc;

  /// No description provided for @updateProxies.
  ///
  /// In zh, this message translates to:
  /// **'下载代理'**
  String get updateProxies;

  /// No description provided for @updateProxiesNotConfigured.
  ///
  /// In zh, this message translates to:
  /// **'未添加，将直连下载'**
  String get updateProxiesNotConfigured;

  /// No description provided for @updateProxiesConfigured.
  ///
  /// In zh, this message translates to:
  /// **'已添加 {count} 个，按顺序尝试'**
  String updateProxiesConfigured(int count);

  /// No description provided for @updateProxiesManage.
  ///
  /// In zh, this message translates to:
  /// **'管理'**
  String get updateProxiesManage;

  /// No description provided for @updateProxiesEmpty.
  ///
  /// In zh, this message translates to:
  /// **'暂无代理，更新时将直连下载'**
  String get updateProxiesEmpty;

  /// No description provided for @updateProxiesHint.
  ///
  /// In zh, this message translates to:
  /// **'最终下载地址 = 代理前缀 + 原始下载链接'**
  String get updateProxiesHint;

  /// No description provided for @updateProxyExampleNote.
  ///
  /// In zh, this message translates to:
  /// **'示例（无效占位地址，仅供格式参考）'**
  String get updateProxyExampleNote;

  /// No description provided for @addUpdateProxy.
  ///
  /// In zh, this message translates to:
  /// **'添加代理'**
  String get addUpdateProxy;

  /// No description provided for @editUpdateProxy.
  ///
  /// In zh, this message translates to:
  /// **'编辑代理'**
  String get editUpdateProxy;

  /// No description provided for @updateProxyInvalid.
  ///
  /// In zh, this message translates to:
  /// **'请输入以 http:// 或 https:// 开头的完整地址'**
  String get updateProxyInvalid;

  /// No description provided for @updateProxyDuplicate.
  ///
  /// In zh, this message translates to:
  /// **'该代理已在列表中'**
  String get updateProxyDuplicate;

  /// No description provided for @upToDate.
  ///
  /// In zh, this message translates to:
  /// **'已是最新版本'**
  String get upToDate;

  /// No description provided for @checkUpdateFailed.
  ///
  /// In zh, this message translates to:
  /// **'检查更新失败: {error}'**
  String checkUpdateFailed(String error);

  /// No description provided for @newVersionAvailable.
  ///
  /// In zh, this message translates to:
  /// **'新版本 {version} 已发布，是否立即更新？'**
  String newVersionAvailable(String version);

  /// No description provided for @downloadingUpdate.
  ///
  /// In zh, this message translates to:
  /// **'正在下载更新'**
  String get downloadingUpdate;

  /// No description provided for @downloadingWithProxy.
  ///
  /// In zh, this message translates to:
  /// **'使用自定义代理下载中...'**
  String get downloadingWithProxy;

  /// No description provided for @downloadFailed.
  ///
  /// In zh, this message translates to:
  /// **'下载或安装失败，建议手动下载'**
  String get downloadFailed;

  /// No description provided for @updateError.
  ///
  /// In zh, this message translates to:
  /// **'更新出错: {error}'**
  String updateError(String error);

  /// No description provided for @foundNewVersion.
  ///
  /// In zh, this message translates to:
  /// **'发现新版本'**
  String get foundNewVersion;

  /// 云同步服务配置标题
  ///
  /// In zh, this message translates to:
  /// **'云同步服务配置'**
  String get cloudSyncConfig;

  /// 同步服务类型下拉框标签
  ///
  /// In zh, this message translates to:
  /// **'同步服务类型'**
  String get syncServiceType;

  /// 云端文件夹名称输入框标签
  ///
  /// In zh, this message translates to:
  /// **'云端文件夹名称'**
  String get cloudFolderName;

  /// 文件夹名称帮助文本
  ///
  /// In zh, this message translates to:
  /// **'修改此名称将重命名云端文件夹（不会创建新文件夹）'**
  String get folderNameHelper;

  /// 文件夹名称验证消息
  ///
  /// In zh, this message translates to:
  /// **'请输入文件夹名称'**
  String get enterFolderName;

  /// 文件夹名称验证消息（包含斜杠）
  ///
  /// In zh, this message translates to:
  /// **'文件夹名称不能包含斜杠'**
  String get folderNameNoSlashes;

  /// 云端路径前缀输入框标签
  ///
  /// In zh, this message translates to:
  /// **'云端路径前缀（可选）'**
  String get cloudPathPrefix;

  /// 云端路径帮助文本
  ///
  /// In zh, this message translates to:
  /// **'云端文件夹的完整路径会自动补齐为：路径前缀'**
  String get cloudPathHelper;

  /// 测试中状态
  ///
  /// In zh, this message translates to:
  /// **'测试中...'**
  String get testing;

  /// 测试连接按钮
  ///
  /// In zh, this message translates to:
  /// **'测试连接'**
  String get testConnection;

  /// 保存配置按钮
  ///
  /// In zh, this message translates to:
  /// **'保存配置'**
  String get saveConfig;

  /// 连接成功提示
  ///
  /// In zh, this message translates to:
  /// **'连接成功！'**
  String get connectionSuccess;

  /// 连接失败提示
  ///
  /// In zh, this message translates to:
  /// **'连接失败，请检查配置'**
  String get connectionFailed;

  /// 服务器地址输入框标签
  ///
  /// In zh, this message translates to:
  /// **'服务器地址'**
  String get serverAddress;

  /// 服务器地址验证消息
  ///
  /// In zh, this message translates to:
  /// **'请输入服务器地址'**
  String get enterServerAddress;

  /// URL 验证消息
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的 URL（以 http:// 或 https:// 开头）'**
  String get enterValidUrl;

  /// 用户名输入框标签
  ///
  /// In zh, this message translates to:
  /// **'用户名'**
  String get username;

  /// 用户名验证消息
  ///
  /// In zh, this message translates to:
  /// **'请输入用户名'**
  String get enterUsername;

  /// 密码输入框标签
  ///
  /// In zh, this message translates to:
  /// **'密码'**
  String get password;

  /// 密码验证消息
  ///
  /// In zh, this message translates to:
  /// **'请输入密码'**
  String get enterPassword;

  /// FTP 服务器地址输入框标签
  ///
  /// In zh, this message translates to:
  /// **'FTP 服务器地址'**
  String get ftpServerAddress;

  /// FTP 服务器地址验证消息
  ///
  /// In zh, this message translates to:
  /// **'请输入FTP服务器地址'**
  String get enterFtpServer;

  /// FTP 地址格式验证消息
  ///
  /// In zh, this message translates to:
  /// **'地址应以 ftp:// 开头'**
  String get addressShouldStartWithFtp;

  /// 主机地址验证消息
  ///
  /// In zh, this message translates to:
  /// **'请输入有效的主机地址'**
  String get enterValidHost;

  /// FTP 格式验证消息
  ///
  /// In zh, this message translates to:
  /// **'格式错误，应为 ftp://主机:端口'**
  String get invalidFormat;

  /// 端口范围验证消息
  ///
  /// In zh, this message translates to:
  /// **'端口号应在 1-65535 之间'**
  String get portRange;

  /// 同步控制标题
  ///
  /// In zh, this message translates to:
  /// **'同步控制'**
  String get syncControls;

  /// 自动同步开关标签
  ///
  /// In zh, this message translates to:
  /// **'自动同步'**
  String get autoSync;

  /// 自动同步描述
  ///
  /// In zh, this message translates to:
  /// **'保存文件时自动上传到云端'**
  String get autoSyncDescription;

  /// 同步状态标题
  ///
  /// In zh, this message translates to:
  /// **'同步状态'**
  String get syncStatus;

  /// 同步服务标签
  ///
  /// In zh, this message translates to:
  /// **'同步服务'**
  String get syncService;

  /// 配置状态标签
  ///
  /// In zh, this message translates to:
  /// **'配置状态'**
  String get configStatus;

  /// 已配置状态
  ///
  /// In zh, this message translates to:
  /// **'已配置'**
  String get configured;

  /// 未配置状态
  ///
  /// In zh, this message translates to:
  /// **'未配置'**
  String get notConfigured;

  /// 上次同步标签
  ///
  /// In zh, this message translates to:
  /// **'上次同步'**
  String get lastSync;

  /// 从未同步状态
  ///
  /// In zh, this message translates to:
  /// **'从未同步'**
  String get neverSynced;

  /// 刚刚
  ///
  /// In zh, this message translates to:
  /// **'刚刚'**
  String get justNow;

  /// 分钟前
  ///
  /// In zh, this message translates to:
  /// **'{count} 分钟前'**
  String minutesAgo(int count);

  /// 小时前
  ///
  /// In zh, this message translates to:
  /// **'{count} 小时前'**
  String hoursAgo(int count);

  /// 配置已保存提示
  ///
  /// In zh, this message translates to:
  /// **'配置已保存'**
  String get configSaved;

  /// 无法连接到服务器错误
  ///
  /// In zh, this message translates to:
  /// **'无法连接到服务器'**
  String get cannotConnectServer;

  /// 同步完成提示
  ///
  /// In zh, this message translates to:
  /// **'同步完成：上传 {uploaded}，下载 {downloaded}{deleted}'**
  String syncComplete(int uploaded, int downloaded, String deleted);

  /// 同步预览对话框标题
  ///
  /// In zh, this message translates to:
  /// **'同步预览'**
  String get syncPreview;

  /// 将上传文件数
  ///
  /// In zh, this message translates to:
  /// **'📤 将上传 {count} 个文件'**
  String willUpload(int count);

  /// 将下载文件数
  ///
  /// In zh, this message translates to:
  /// **'📥 将下载 {count} 个文件'**
  String willDownload(int count);

  /// 冲突警告
  ///
  /// In zh, this message translates to:
  /// **'⚠️ {count} 个文件存在冲突'**
  String conflictWarning(int count);

  /// 冲突描述
  ///
  /// In zh, this message translates to:
  /// **'这些文件在本地和云端都有修改，请选择保留哪个版本：'**
  String get conflictDescription;

  /// 保留本地选项
  ///
  /// In zh, this message translates to:
  /// **'保留本地'**
  String get keepLocal;

  /// 保留云端选项
  ///
  /// In zh, this message translates to:
  /// **'保留云端'**
  String get keepRemote;

  /// 跳过选项
  ///
  /// In zh, this message translates to:
  /// **'跳过'**
  String get skip;

  /// 本地版本标签
  ///
  /// In zh, this message translates to:
  /// **'本地'**
  String get localVersion;

  /// 云端版本标签
  ///
  /// In zh, this message translates to:
  /// **'云端'**
  String get cloudVersion;

  /// 开始同步按钮
  ///
  /// In zh, this message translates to:
  /// **'开始同步'**
  String get startSync;

  /// 存储设置页面标题
  ///
  /// In zh, this message translates to:
  /// **'存储设置'**
  String get storageSettings;

  /// No description provided for @storagePermissionTitle.
  ///
  /// In zh, this message translates to:
  /// **'「所有文件访问」权限'**
  String get storagePermissionTitle;

  /// No description provided for @storagePermissionDesc.
  ///
  /// In zh, this message translates to:
  /// **'用于浏览、编辑和保存设备上的 Markdown 文件。'**
  String get storagePermissionDesc;

  /// No description provided for @storagePermissionCan.
  ///
  /// In zh, this message translates to:
  /// **'授权后可直接读写手机任意文件夹中的笔记。'**
  String get storagePermissionCan;

  /// No description provided for @storagePermissionWithout.
  ///
  /// In zh, this message translates to:
  /// **'未授权时只能访问应用私有目录，已有笔记无法打开。'**
  String get storagePermissionWithout;

  /// No description provided for @grantStoragePermission.
  ///
  /// In zh, this message translates to:
  /// **'去授予权限'**
  String get grantStoragePermission;

  /// No description provided for @openSystemSettings.
  ///
  /// In zh, this message translates to:
  /// **'打开系统设置'**
  String get openSystemSettings;

  /// No description provided for @storagePermissionManualHint.
  ///
  /// In zh, this message translates to:
  /// **'Android 11 及以上需在系统设置中手动开启。'**
  String get storagePermissionManualHint;

  /// No description provided for @storagePermissionDenied.
  ///
  /// In zh, this message translates to:
  /// **'请在设置中授予存储权限'**
  String get storagePermissionDenied;

  /// No description provided for @openSettings.
  ///
  /// In zh, this message translates to:
  /// **'打开设置'**
  String get openSettings;

  /// 工作区
  ///
  /// In zh, this message translates to:
  /// **'工作区'**
  String get workspace;

  /// 新建文件默认位置
  ///
  /// In zh, this message translates to:
  /// **'新建文件默认位置'**
  String get newFileDefaultLocation;

  /// 未设置提示
  ///
  /// In zh, this message translates to:
  /// **'未设置 (默认使用当前或最近位置)'**
  String get notSetUseCurrentOrRecent;

  /// 更改按钮
  ///
  /// In zh, this message translates to:
  /// **'更改'**
  String get change;

  /// 默认位置重置消息
  ///
  /// In zh, this message translates to:
  /// **'已重置默认位置'**
  String get defaultLocationReset;

  /// 清理部分
  ///
  /// In zh, this message translates to:
  /// **'清理'**
  String get cleanup;

  /// 清除最近文件按钮
  ///
  /// In zh, this message translates to:
  /// **'清除最近文件'**
  String get clearRecentFiles;

  /// 清除最近文件夹按钮
  ///
  /// In zh, this message translates to:
  /// **'清除最近文件夹'**
  String get clearRecentFolders;

  /// 加载消息
  ///
  /// In zh, this message translates to:
  /// **'加载中...'**
  String get loading;

  /// 工作区文件夹名称设置
  ///
  /// In zh, this message translates to:
  /// **'工作区文件夹名称'**
  String get workspaceFolderName;

  /// 自定义基础路径设置
  ///
  /// In zh, this message translates to:
  /// **'自定义基础路径（高级）'**
  String get customBasePathAdvanced;

  /// 使用默认路径提示
  ///
  /// In zh, this message translates to:
  /// **'使用默认路径'**
  String get useDefaultPath;

  /// 重置按钮
  ///
  /// In zh, this message translates to:
  /// **'重置'**
  String get reset;

  /// 工作区同步信息
  ///
  /// In zh, this message translates to:
  /// **'工作区文件会自动同步到云端'**
  String get workspaceFilesSyncToCloud;

  /// 文件数量
  ///
  /// In zh, this message translates to:
  /// **'{count} 个文件'**
  String filesCount(int count);

  /// 文件夹数量
  ///
  /// In zh, this message translates to:
  /// **'{count} 个文件夹'**
  String foldersCount(int count);

  /// 清除按钮
  ///
  /// In zh, this message translates to:
  /// **'清除'**
  String get clear;

  /// 确认清除最近文件消息
  ///
  /// In zh, this message translates to:
  /// **'确定要清除所有最近访问的文件记录吗？'**
  String get confirmClearRecentFiles;

  /// 确认清除最近文件夹消息
  ///
  /// In zh, this message translates to:
  /// **'确定要清除所有最近访问的文件夹记录吗？'**
  String get confirmClearRecentFolders;

  /// 已清除消息
  ///
  /// In zh, this message translates to:
  /// **'已清除'**
  String get cleared;

  /// 更改工作区名称对话框标题
  ///
  /// In zh, this message translates to:
  /// **'更改工作区名称'**
  String get changeWorkspaceName;

  /// 输入工作区文件夹名称提示
  ///
  /// In zh, this message translates to:
  /// **'输入新的工作区文件夹名称：'**
  String get inputWorkspaceFolderName;

  /// 名称更改后关于云同步的警告
  ///
  /// In zh, this message translates to:
  /// **'注意：更改名称后需要重新配置云同步'**
  String get warningChangeNameRequiresCloudSync;

  /// 名称不能为空错误
  ///
  /// In zh, this message translates to:
  /// **'名称不能为空'**
  String get nameCannotBeEmpty;

  /// 名称不能包含斜杠错误
  ///
  /// In zh, this message translates to:
  /// **'名称不能包含斜杠'**
  String get nameCannotContainSlash;

  /// 工作区名称已更新消息
  ///
  /// In zh, this message translates to:
  /// **'工作区名称已更新为 {name}'**
  String workspaceNameUpdated(String name);

  /// 自定义基础路径对话框标题
  ///
  /// In zh, this message translates to:
  /// **'自定义基础路径'**
  String get customBasePath;

  /// 输入自定义基础路径提示
  ///
  /// In zh, this message translates to:
  /// **'输入自定义的基础路径：'**
  String get inputCustomBasePath;

  /// 默认路径显示
  ///
  /// In zh, this message translates to:
  /// **'默认路径：{path}'**
  String defaultPath(String path);

  /// 关于基础路径更改的警告
  ///
  /// In zh, this message translates to:
  /// **'警告：更改基础路径将影响工作区位置，请确保路径存在且可访问'**
  String get warningChangeBasePathAffectsWorkspace;

  /// 重置为默认路径消息
  ///
  /// In zh, this message translates to:
  /// **'已重置为默认路径'**
  String get resetToDefaultPath;

  /// 基础路径已更新消息
  ///
  /// In zh, this message translates to:
  /// **'基础路径已更新'**
  String get basePathUpdated;

  /// 保存成功提示
  ///
  /// In zh, this message translates to:
  /// **'已保存'**
  String get saveSuccess;

  /// 保存失败提示
  ///
  /// In zh, this message translates to:
  /// **'保存失败: {error}'**
  String saveFailedWithError(String error);

  /// 未保存更改对话框消息
  ///
  /// In zh, this message translates to:
  /// **'您有未保存的更改，要保存吗？'**
  String get unsavedChangesMessage;

  /// 放弃按钮
  ///
  /// In zh, this message translates to:
  /// **'放弃'**
  String get discard;

  /// 搜索无匹配内容
  ///
  /// In zh, this message translates to:
  /// **'未找到匹配内容'**
  String get noMatchContent;

  /// 字数统计显示
  ///
  /// In zh, this message translates to:
  /// **'{chars} 字符 · {glyphs} 文字 · {words} 单词'**
  String wordCount(int chars, int glyphs, int words);

  /// FTP 格式帮助文本
  ///
  /// In zh, this message translates to:
  /// **'格式：ftp://主机:端口'**
  String get ftpFormatHelper;

  /// 图标2选项
  ///
  /// In zh, this message translates to:
  /// **'图标 2'**
  String get icon2;

  /// 隐藏选项
  ///
  /// In zh, this message translates to:
  /// **'隐藏'**
  String get hidden;

  /// 主页图标选择器提示
  ///
  /// In zh, this message translates to:
  /// **'选择主页左上角显示的图标'**
  String get homeIconSelectorHint;

  /// 仅Android可用提示
  ///
  /// In zh, this message translates to:
  /// **'注意：自定义图标仅 Android 可用'**
  String get appIconAndroidOnly;

  /// 图标更换成功提示
  ///
  /// In zh, this message translates to:
  /// **'图标已更换'**
  String get appIconChanged;

  /// 图标更换失败提示
  ///
  /// In zh, this message translates to:
  /// **'图标更换失败'**
  String get appIconChangeFailed;

  /// 从相册选择按钮
  ///
  /// In zh, this message translates to:
  /// **'从相册选择'**
  String get selectFromGallery;

  /// 主页标题输入提示
  ///
  /// In zh, this message translates to:
  /// **'自定义主页图标旁显示的文字'**
  String get homeTitleHint;

  /// 应用图标选择器提示
  ///
  /// In zh, this message translates to:
  /// **'选择在主屏幕显示的应用图标'**
  String get appIconSelectorHint;

  /// 亮度设置
  ///
  /// In zh, this message translates to:
  /// **'亮度'**
  String get brightness;

  /// 目录中没有找到标题
  ///
  /// In zh, this message translates to:
  /// **'没有找到标题'**
  String get noHeadingsFound;

  /// 清空历史提示
  ///
  /// In zh, this message translates to:
  /// **'清空历史'**
  String get clearHistory;

  /// 清空历史记录对话框标题
  ///
  /// In zh, this message translates to:
  /// **'清空历史记录'**
  String get clearHistoryConfirm;

  /// 清空历史记录确认消息
  ///
  /// In zh, this message translates to:
  /// **'确定要清空所有最近{type}记录吗？'**
  String clearHistoryConfirmMessage(String type);

  /// 文件标签
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get file;

  /// 文件夹标签
  ///
  /// In zh, this message translates to:
  /// **'文件夹'**
  String get folder;

  /// 文件标签（复数）
  ///
  /// In zh, this message translates to:
  /// **'文件'**
  String get files;

  /// 最近文件为空状态
  ///
  /// In zh, this message translates to:
  /// **'没有最近打开的文件'**
  String get noRecentFiles;

  /// 最近文件夹为空状态
  ///
  /// In zh, this message translates to:
  /// **'没有最近文件夹'**
  String get noRecentFolders;

  /// 新建 Markdown 文件菜单项
  ///
  /// In zh, this message translates to:
  /// **'新建 Markdown'**
  String get newMarkdown;

  /// 新建文件夹对话框标题
  ///
  /// In zh, this message translates to:
  /// **'新建文件夹'**
  String get createFolder;

  /// 文件夹名称输入标签
  ///
  /// In zh, this message translates to:
  /// **'文件夹名称'**
  String get folderName;

  /// 创建失败错误
  ///
  /// In zh, this message translates to:
  /// **'创建失败'**
  String get createFailed;

  /// 创建按钮
  ///
  /// In zh, this message translates to:
  /// **'创建'**
  String get create;

  /// 加载失败错误
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadFailed;

  /// 文件夹为空消息
  ///
  /// In zh, this message translates to:
  /// **'此文件夹为空'**
  String get folderEmpty;

  /// 无搜索结果消息
  ///
  /// In zh, this message translates to:
  /// **'没有找到匹配的文件'**
  String get noMatchingFiles;

  /// 文件数量显示
  ///
  /// In zh, this message translates to:
  /// **'{count} 个文件'**
  String fileCount(int count);

  /// 搜索文件提示
  ///
  /// In zh, this message translates to:
  /// **'搜索文件...'**
  String get searchFiles;

  /// 排序菜单标题
  ///
  /// In zh, this message translates to:
  /// **'排序方式'**
  String get sortBy;

  /// 自定义排序选项
  ///
  /// In zh, this message translates to:
  /// **'自定义排序'**
  String get customSort;

  /// 按名称升序排列
  ///
  /// In zh, this message translates to:
  /// **'名称 A-Z'**
  String get nameAZ;

  /// 按名称降序排列
  ///
  /// In zh, this message translates to:
  /// **'名称 Z-A'**
  String get nameZA;

  /// 按最近修改排序
  ///
  /// In zh, this message translates to:
  /// **'最近修改'**
  String get recentModified;

  /// 按最早修改排序
  ///
  /// In zh, this message translates to:
  /// **'最早修改'**
  String get oldestModified;

  /// 按最大大小排序
  ///
  /// In zh, this message translates to:
  /// **'最大优先'**
  String get largestFirst;

  /// 按最小大小排序
  ///
  /// In zh, this message translates to:
  /// **'最小优先'**
  String get smallestFirst;

  /// 卡片颜色设置
  ///
  /// In zh, this message translates to:
  /// **'卡片颜色'**
  String get cardColor;

  /// 自定义卡片颜色开关
  ///
  /// In zh, this message translates to:
  /// **'自定义卡片颜色'**
  String get customCardColor;

  /// 使用主题默认颜色
  ///
  /// In zh, this message translates to:
  /// **'使用主题默认'**
  String get useThemeDefault;

  /// 卡片外观区块标题
  ///
  /// In zh, this message translates to:
  /// **'卡片外观'**
  String get cardAppearance;

  /// 代码块主题设置
  ///
  /// In zh, this message translates to:
  /// **'代码块主题'**
  String get codeBlockTheme;

  /// 自动代码块主题
  ///
  /// In zh, this message translates to:
  /// **'跟随应用主题'**
  String get codeBlockThemeAuto;

  /// One Dark 代码块主题
  ///
  /// In zh, this message translates to:
  /// **'One Dark'**
  String get codeBlockThemeOneDark;

  /// One Light 代码块主题
  ///
  /// In zh, this message translates to:
  /// **'One Light'**
  String get codeBlockThemeOneLight;

  /// GitHub Dark 代码块主题
  ///
  /// In zh, this message translates to:
  /// **'GitHub Dark'**
  String get codeBlockThemeGithubDark;

  /// GitHub Light 代码块主题
  ///
  /// In zh, this message translates to:
  /// **'GitHub Light'**
  String get codeBlockThemeGithubLight;

  /// Nord 代码块主题
  ///
  /// In zh, this message translates to:
  /// **'Nord'**
  String get codeBlockThemeNord;

  /// Material 代码块主题
  ///
  /// In zh, this message translates to:
  /// **'Material'**
  String get codeBlockThemeMaterial;

  /// 自定义主题色开关
  ///
  /// In zh, this message translates to:
  /// **'自定义主题色'**
  String get customThemeColor;

  /// 从图片提取强调色按钮
  ///
  /// In zh, this message translates to:
  /// **'从图片取色'**
  String get accentFromImage;

  /// 图片取色失败提示
  ///
  /// In zh, this message translates to:
  /// **'无法从该图片提取颜色'**
  String get accentFromImageFailed;

  /// 字间距设置描述
  ///
  /// In zh, this message translates to:
  /// **'调整文字之间的水平间距'**
  String get letterSpacingDesc;

  /// 段落间距设置描述
  ///
  /// In zh, this message translates to:
  /// **'调整段落之间的垂直间距'**
  String get paragraphSpacingDesc;

  /// 行高设置描述
  ///
  /// In zh, this message translates to:
  /// **'调整文本行与行之间的垂直间距'**
  String get lineHeightDesc;

  /// 启动行为设置
  ///
  /// In zh, this message translates to:
  /// **'启动行为'**
  String get startupBehavior;

  /// 启动时显示空白页
  ///
  /// In zh, this message translates to:
  /// **'显示空白页'**
  String get startupShowBlank;

  /// 启动时恢复上次打开的文件
  ///
  /// In zh, this message translates to:
  /// **'恢复上次文件'**
  String get startupRestoreLast;

  /// 恢复上次文件描述
  ///
  /// In zh, this message translates to:
  /// **'自动打开上次编辑的文件'**
  String get startupRestoreLastDesc;

  /// 退出时保存
  ///
  /// In zh, this message translates to:
  /// **'退出时保存'**
  String get saveOnExit;

  /// 启用退出时自动保存
  ///
  /// In zh, this message translates to:
  /// **'退出时自动保存'**
  String get enableSaveOnExit;

  /// 退出时自动保存描述
  ///
  /// In zh, this message translates to:
  /// **'退出文档时自动保存未保存的更改'**
  String get saveOnExitDesc;

  /// 启动时选项标签
  ///
  /// In zh, this message translates to:
  /// **'启动时'**
  String get onOpen;

  /// 界面字体颜色设置
  ///
  /// In zh, this message translates to:
  /// **'界面字体颜色'**
  String get uiFontColor;

  /// 自定义界面字体颜色开关
  ///
  /// In zh, this message translates to:
  /// **'自定义字体颜色'**
  String get customUiFontColor;

  /// 全局图标颜色设置
  ///
  /// In zh, this message translates to:
  /// **'全局图标颜色'**
  String get globalIconColor;

  /// 自定义全局图标颜色开关
  ///
  /// In zh, this message translates to:
  /// **'自定义全局图标颜色'**
  String get customGlobalIconColor;

  /// 全局图标颜色描述
  ///
  /// In zh, this message translates to:
  /// **'开启后，应用内所有图标统一使用所选颜色'**
  String get globalIconColorDesc;

  /// 编辑器文字颜色设置
  ///
  /// In zh, this message translates to:
  /// **'编辑器文字颜色'**
  String get editorFontColor;

  /// 自定义编辑器文字颜色开关
  ///
  /// In zh, this message translates to:
  /// **'自定义文字颜色'**
  String get customEditorFontColor;

  /// 编辑器文字颜色描述
  ///
  /// In zh, this message translates to:
  /// **'作用于文档正文与编辑区，不影响界面文字'**
  String get editorFontColorDesc;

  /// 颜色预览文字
  ///
  /// In zh, this message translates to:
  /// **'预览文字'**
  String get previewText;

  /// 配色与主题设置标题
  ///
  /// In zh, this message translates to:
  /// **'配色与主题'**
  String get colorThemeSettings;

  /// 配色与主题描述
  ///
  /// In zh, this message translates to:
  /// **'主题模式、强调色、浅色与深色配色方案'**
  String get colorThemeSettingsDesc;

  /// 文字与字体设置标题
  ///
  /// In zh, this message translates to:
  /// **'文字与字体'**
  String get textAndFontSettings;

  /// 文字与字体描述
  ///
  /// In zh, this message translates to:
  /// **'语言、字体、界面与编辑器文字颜色、代码块主题'**
  String get textAndFontSettingsDesc;

  /// 表面与背景设置标题
  ///
  /// In zh, this message translates to:
  /// **'表面与背景'**
  String get surfaceAndBackgroundSettings;

  /// 表面与背景描述
  ///
  /// In zh, this message translates to:
  /// **'UI 风格、卡片、图标、导航栏、背景与首页外观'**
  String get surfaceAndBackgroundSettingsDesc;

  /// 下载字体对话框标题
  ///
  /// In zh, this message translates to:
  /// **'下载字体'**
  String get downloadFont;

  /// 下载字体确认消息
  ///
  /// In zh, this message translates to:
  /// **'是否下载「{fontName}」字体？'**
  String downloadFontConfirm(String fontName);

  /// 下载字体提示
  ///
  /// In zh, this message translates to:
  /// **'字体将从网络下载，首次使用需要网络连接。'**
  String get downloadFontNote;

  /// 下载按钮
  ///
  /// In zh, this message translates to:
  /// **'下载'**
  String get download;

  /// 下载字体进度消息
  ///
  /// In zh, this message translates to:
  /// **'正在下载「{fontName}」...'**
  String downloadingFont(String fontName);

  /// 字体下载成功消息
  ///
  /// In zh, this message translates to:
  /// **'「{fontName}」下载完成'**
  String fontDownloadSuccess(String fontName);

  /// No description provided for @selectItems.
  ///
  /// In zh, this message translates to:
  /// **'选择项目'**
  String get selectItems;

  /// No description provided for @selectedItemCount.
  ///
  /// In zh, this message translates to:
  /// **'已选择 {count} 项'**
  String selectedItemCount(int count);

  /// No description provided for @selectAllItems.
  ///
  /// In zh, this message translates to:
  /// **'全选'**
  String get selectAllItems;

  /// No description provided for @invertSelection.
  ///
  /// In zh, this message translates to:
  /// **'反选'**
  String get invertSelection;

  /// No description provided for @moveSelectedItems.
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get moveSelectedItems;

  /// No description provided for @deleteSelectedItems.
  ///
  /// In zh, this message translates to:
  /// **'删除'**
  String get deleteSelectedItems;

  /// No description provided for @deleteSelectedConfirmation.
  ///
  /// In zh, this message translates to:
  /// **'删除所选的 {count} 项？此操作不可撤销。'**
  String deleteSelectedConfirmation(int count);

  /// No description provided for @batchOperationSummary.
  ///
  /// In zh, this message translates to:
  /// **'成功 {succeeded} 项，失败 {failed} 项'**
  String batchOperationSummary(int succeeded, int failed);

  /// No description provided for @batchOperationFailed.
  ///
  /// In zh, this message translates to:
  /// **'部分项目未完成'**
  String get batchOperationFailed;

  /// No description provided for @destinationConflict.
  ///
  /// In zh, this message translates to:
  /// **'目标已存在同名项目或版本历史'**
  String get destinationConflict;

  /// No description provided for @invalidMoveDestination.
  ///
  /// In zh, this message translates to:
  /// **'不能移动到自身或子目录'**
  String get invalidMoveDestination;

  /// No description provided for @missingFileItem.
  ///
  /// In zh, this message translates to:
  /// **'项目或目标文件夹不存在'**
  String get missingFileItem;

  /// No description provided for @switchToSource.
  ///
  /// In zh, this message translates to:
  /// **'切换到源码编辑'**
  String get switchToSource;

  /// No description provided for @switchToPreview.
  ///
  /// In zh, this message translates to:
  /// **'切换到渲染编辑'**
  String get switchToPreview;

  /// 字体下载失败消息
  ///
  /// In zh, this message translates to:
  /// **'「{fontName}」下载失败，请检查网络'**
  String fontDownloadFailed(String fontName);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
