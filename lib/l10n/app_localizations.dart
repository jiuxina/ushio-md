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

  /// 主题设置
  ///
  /// In zh, this message translates to:
  /// **'主题'**
  String get theme;

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

  /// 代码字体设置
  ///
  /// In zh, this message translates to:
  /// **'代码字体'**
  String get codeFont;

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

  /// 同步成功提示
  ///
  /// In zh, this message translates to:
  /// **'同步成功'**
  String get syncSuccess;

  /// 同步失败提示
  ///
  /// In zh, this message translates to:
  /// **'同步失败'**
  String get syncFailed;

  /// 新建文件
  ///
  /// In zh, this message translates to:
  /// **'新建文件'**
  String get newFile;

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

  /// 移动
  ///
  /// In zh, this message translates to:
  /// **'移动'**
  String get move;

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

  /// 导出
  ///
  /// In zh, this message translates to:
  /// **'导出'**
  String get export;

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

  /// 插入图片
  ///
  /// In zh, this message translates to:
  /// **'插入图片'**
  String get insertImage;

  /// 从链接插入图片
  ///
  /// In zh, this message translates to:
  /// **'输入图片链接'**
  String get insertImageFromUrl;

  /// 从设备选择图片
  ///
  /// In zh, this message translates to:
  /// **'从设备选择'**
  String get insertImageFromDevice;

  /// 图片 URL 输入框标签
  ///
  /// In zh, this message translates to:
  /// **'图片 URL'**
  String get imageUrl;

  /// 图片 URL 输入提示
  ///
  /// In zh, this message translates to:
  /// **'https://example.com/image.png'**
  String get imageUrlHint;

  /// 图片替代文本
  ///
  /// In zh, this message translates to:
  /// **'替代文本（可选）'**
  String get imageAlt;

  /// 替代文本提示
  ///
  /// In zh, this message translates to:
  /// **'用于无障碍与图片说明'**
  String get imageAltHint;

  /// 插入按钮
  ///
  /// In zh, this message translates to:
  /// **'插入'**
  String get insert;

  /// 图片上传失败提示
  ///
  /// In zh, this message translates to:
  /// **'图片上传失败'**
  String get imageUploadFailed;

  /// 重试按钮
  ///
  /// In zh, this message translates to:
  /// **'重试'**
  String get retry;

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

  /// 放弃更改按钮
  ///
  /// In zh, this message translates to:
  /// **'放弃更改'**
  String get discardChanges;

  /// 继续编辑按钮
  ///
  /// In zh, this message translates to:
  /// **'继续编辑'**
  String get keepEditing;

  /// 文件未找到错误
  ///
  /// In zh, this message translates to:
  /// **'文件未找到'**
  String get fileNotFound;

  /// 文件夹不存在错误
  ///
  /// In zh, this message translates to:
  /// **'文件夹不存在'**
  String get folderNotFound;

  /// 加载文件错误
  ///
  /// In zh, this message translates to:
  /// **'加载文件失败'**
  String get errorLoadingFile;

  /// 保存文件错误
  ///
  /// In zh, this message translates to:
  /// **'保存文件失败'**
  String get errorSavingFile;

  /// 权限请求标题
  ///
  /// In zh, this message translates to:
  /// **'需要权限'**
  String get permissionRequired;

  /// 存储权限说明
  ///
  /// In zh, this message translates to:
  /// **'需要存储权限才能访问文件'**
  String get storagePermissionRequired;

  /// 授予权限按钮
  ///
  /// In zh, this message translates to:
  /// **'授予权限'**
  String get grantPermission;

  /// 初始化提示
  ///
  /// In zh, this message translates to:
  /// **'初始化中...'**
  String get initializing;

  /// 更新可用提示
  ///
  /// In zh, this message translates to:
  /// **'有新版本可用'**
  String get updateAvailable;

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

  /// 调试模式设置
  ///
  /// In zh, this message translates to:
  /// **'调试模式'**
  String get debugMode;

  /// 调试日志
  ///
  /// In zh, this message translates to:
  /// **'调试日志'**
  String get debugLog;

  /// 清除日志按钮
  ///
  /// In zh, this message translates to:
  /// **'清除日志'**
  String get clearLog;

  /// 复制日志按钮
  ///
  /// In zh, this message translates to:
  /// **'复制日志'**
  String get copyLog;

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

  /// 标题
  ///
  /// In zh, this message translates to:
  /// **'标题'**
  String get heading;

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

  /// 更多
  ///
  /// In zh, this message translates to:
  /// **'更多'**
  String get more;

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

  /// 按钮风格设置
  ///
  /// In zh, this message translates to:
  /// **'按钮风格'**
  String get buttonStyle;

  /// 经典描边按钮风格
  ///
  /// In zh, this message translates to:
  /// **'经典描边'**
  String get buttonStyleClassic;

  /// 经典描边按钮风格描述
  ///
  /// In zh, this message translates to:
  /// **'保留当前的实线边框按钮样式'**
  String get buttonStyleClassicDesc;

  /// 简洁立体按钮风格
  ///
  /// In zh, this message translates to:
  /// **'简洁立体'**
  String get buttonStyleModern;

  /// 简洁立体按钮风格描述
  ///
  /// In zh, this message translates to:
  /// **'柔和阴影的立体按钮效果'**
  String get buttonStyleModernDesc;

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

  /// 粒子效果设置
  ///
  /// In zh, this message translates to:
  /// **'粒子效果'**
  String get particleEffect;

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

  /// 编辑器背景图片设置
  ///
  /// In zh, this message translates to:
  /// **'编辑器背景图片'**
  String get editorBackgroundImage;

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

  /// 粒子类型设置
  ///
  /// In zh, this message translates to:
  /// **'粒子类型'**
  String get particleType;

  /// 粒子速度设置
  ///
  /// In zh, this message translates to:
  /// **'粒子速度'**
  String get particleSpeed;

  /// 全局粒子效果开关
  ///
  /// In zh, this message translates to:
  /// **'全局粒子'**
  String get globalParticles;

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

  /// 樱花粒子类型
  ///
  /// In zh, this message translates to:
  /// **'樱花'**
  String get particleTypeSakura;

  /// 雪花粒子类型
  ///
  /// In zh, this message translates to:
  /// **'雪花'**
  String get particleTypeSnow;

  /// 落叶粒子类型
  ///
  /// In zh, this message translates to:
  /// **'落叶'**
  String get particleTypeLeaves;

  /// 星星粒子类型
  ///
  /// In zh, this message translates to:
  /// **'星星'**
  String get particleTypeStars;

  /// 界面字体设置
  ///
  /// In zh, this message translates to:
  /// **'界面字体'**
  String get uiFont;

  /// 系统字体选项
  ///
  /// In zh, this message translates to:
  /// **'系统字体'**
  String get systemFont;

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

  /// 按钮预览
  ///
  /// In zh, this message translates to:
  /// **'按钮预览'**
  String get buttonPreview;

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

  /// No description provided for @downloadingWithMirror.
  ///
  /// In zh, this message translates to:
  /// **'优先使用镜像加速下载中...'**
  String get downloadingWithMirror;

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

  /// 后台继续同步提示
  ///
  /// In zh, this message translates to:
  /// **'同步将在后台继续'**
  String get syncWillContinueInBackground;

  /// 存储设置页面标题
  ///
  /// In zh, this message translates to:
  /// **'存储设置'**
  String get storageSettings;

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

  /// 加载失败消息
  ///
  /// In zh, this message translates to:
  /// **'加载失败'**
  String get loadingFailed;

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

  /// 高级粒子设置标题
  ///
  /// In zh, this message translates to:
  /// **'高级设置'**
  String get advancedParticleSettings;

  /// 主页标题输入提示
  ///
  /// In zh, this message translates to:
  /// **'自定义主页图标旁显示的文字'**
  String get homeTitleHint;

  /// 主页标题标签
  ///
  /// In zh, this message translates to:
  /// **'主页标题'**
  String get homeTitleLabel;

  /// 主页标题默认值
  ///
  /// In zh, this message translates to:
  /// **'汐'**
  String get homeTitleDefault;

  /// 恢复默认按钮
  ///
  /// In zh, this message translates to:
  /// **'恢复默认'**
  String get restoreDefault;

  /// 全局粒子开关
  ///
  /// In zh, this message translates to:
  /// **'全局粒子'**
  String get globalParticlesEnabled;

  /// 全局粒子描述
  ///
  /// In zh, this message translates to:
  /// **'在应用全局显示粒子效果'**
  String get globalParticlesDesc;

  /// 编辑器粒子描述
  ///
  /// In zh, this message translates to:
  /// **'仅在编辑器中显示粒子效果'**
  String get editorParticlesDesc;

  /// 雨滴粒子类型
  ///
  /// In zh, this message translates to:
  /// **'雨滴'**
  String get particleTypeRain;

  /// 萤火虫粒子类型
  ///
  /// In zh, this message translates to:
  /// **'萤火虫'**
  String get particleTypeFirefly;

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

  /// 调试设置页面标题
  ///
  /// In zh, this message translates to:
  /// **'调试'**
  String get debugSettings;

  /// 调试开关部分标题
  ///
  /// In zh, this message translates to:
  /// **'调试开关'**
  String get debugSwitches;

  /// 启用调试模式开关标题
  ///
  /// In zh, this message translates to:
  /// **'启用调试模式'**
  String get enableDebugMode;

  /// 调试模式描述
  ///
  /// In zh, this message translates to:
  /// **'记录 Bridge 消息、命令执行和问题诊断数据'**
  String get debugModeDescription;

  /// 调试日志部分标题
  ///
  /// In zh, this message translates to:
  /// **'日志'**
  String get debugLogsSection;

  /// 日志条目总数
  ///
  /// In zh, this message translates to:
  /// **'共 {count} 条'**
  String totalLogsCount(int count);

  /// 日志已复制到剪贴板提示
  ///
  /// In zh, this message translates to:
  /// **'日志已复制到剪贴板'**
  String get logCopiedToClipboard;

  /// 无日志占位文本
  ///
  /// In zh, this message translates to:
  /// **'暂无日志。开启调试后进入编辑器操作，再回来查看。'**
  String get noLogsYet;

  /// 采集请求已发送消息
  ///
  /// In zh, this message translates to:
  /// **'已请求采集，请返回日志区查看 on_debug_report'**
  String get collectRequestSent;

  /// 无活跃编辑器错误消息
  ///
  /// In zh, this message translates to:
  /// **'当前没有活跃编辑器，请先打开一个 Markdown 文件'**
  String get noActiveEditor;

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

  /// 粒子数量设置
  ///
  /// In zh, this message translates to:
  /// **'粒子数量'**
  String get particleCount;

  /// 粒子大小设置
  ///
  /// In zh, this message translates to:
  /// **'粒子大小'**
  String get particleSize;

  /// 粒子透明度设置
  ///
  /// In zh, this message translates to:
  /// **'粒子透明度'**
  String get particleOpacity;

  /// 风向设置
  ///
  /// In zh, this message translates to:
  /// **'风向'**
  String get particleWind;

  /// 风向向左
  ///
  /// In zh, this message translates to:
  /// **'向左'**
  String get particleWindLeft;

  /// 风向向右
  ///
  /// In zh, this message translates to:
  /// **'向右'**
  String get particleWindRight;

  /// 无风
  ///
  /// In zh, this message translates to:
  /// **'无风'**
  String get particleWindNone;

  /// 粒子数量设置描述
  ///
  /// In zh, this message translates to:
  /// **'调整屏幕上粒子的数量'**
  String get particleCountDesc;

  /// 粒子大小设置描述
  ///
  /// In zh, this message translates to:
  /// **'调整粒子的显示大小'**
  String get particleSizeDesc;

  /// 粒子透明度设置描述
  ///
  /// In zh, this message translates to:
  /// **'调整粒子的透明度'**
  String get particleOpacityDesc;

  /// 风向设置描述
  ///
  /// In zh, this message translates to:
  /// **'调整粒子飘动的水平方向'**
  String get particleWindDesc;

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

  /// 字体颜色标签
  ///
  /// In zh, this message translates to:
  /// **'字体颜色'**
  String get uiFontColorLabel;

  /// 自适应渐变色开关
  ///
  /// In zh, this message translates to:
  /// **'自适应渐变色'**
  String get adaptiveGradient;

  /// 自适应渐变色开关描述
  ///
  /// In zh, this message translates to:
  /// **'根据自定义颜色自动计算渐变色'**
  String get adaptiveGradientDesc;

  /// 界面字体自适应渐变色描述
  ///
  /// In zh, this message translates to:
  /// **'根据字体颜色自动计算渐变效果'**
  String get uiFontAdaptiveGradientDesc;

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

  /// 编辑器文字颜色标签
  ///
  /// In zh, this message translates to:
  /// **'文字颜色'**
  String get editorFontColorLabel;

  /// 编辑器文字自适应渐变色描述
  ///
  /// In zh, this message translates to:
  /// **'根据文字颜色自动计算渐变效果'**
  String get editorFontAdaptiveGradientDesc;

  /// 颜色预览文字
  ///
  /// In zh, this message translates to:
  /// **'预览文字'**
  String get previewText;

  /// 主题设置标题
  ///
  /// In zh, this message translates to:
  /// **'主题设置'**
  String get themeSettings;

  /// 主题设置描述
  ///
  /// In zh, this message translates to:
  /// **'主题模式、语言、主题色、字体颜色、按钮样式'**
  String get themeSettingsDesc;

  /// 字体设置标题
  ///
  /// In zh, this message translates to:
  /// **'字体设置'**
  String get fontSettings;

  /// 字体设置描述
  ///
  /// In zh, this message translates to:
  /// **'界面字体、编辑器字体、代码字体、代码块主题'**
  String get fontSettingsDesc;

  /// 背景设置标题
  ///
  /// In zh, this message translates to:
  /// **'背景设置'**
  String get backgroundSettings;

  /// 背景设置描述
  ///
  /// In zh, this message translates to:
  /// **'背景图片、编辑器背景、粒子特效'**
  String get backgroundSettingsDesc;

  /// 其他外观设置标题
  ///
  /// In zh, this message translates to:
  /// **'其他外观'**
  String get otherAppearanceSettings;

  /// 其他外观设置描述
  ///
  /// In zh, this message translates to:
  /// **'应用图标、首页头像、首页标题、底部导航栏'**
  String get otherAppearanceSettingsDesc;

  /// 莫奈取色设置标题
  ///
  /// In zh, this message translates to:
  /// **'莫奈取色'**
  String get monetSettings;

  /// 启用莫奈取色开关
  ///
  /// In zh, this message translates to:
  /// **'启用莫奈取色'**
  String get monetEnabled;

  /// 启用莫奈取色描述
  ///
  /// In zh, this message translates to:
  /// **'使用 Material You 动态配色系统'**
  String get monetEnabledDesc;

  /// 从图片提取颜色
  ///
  /// In zh, this message translates to:
  /// **'从图片提取'**
  String get monetFromImage;

  /// 从颜色选择
  ///
  /// In zh, this message translates to:
  /// **'从颜色选择'**
  String get monetFromColor;

  /// 选择图片提示
  ///
  /// In zh, this message translates to:
  /// **'点击选择图片'**
  String get monetSelectImage;

  /// 源色选择标题
  ///
  /// In zh, this message translates to:
  /// **'源色选择'**
  String get monetSourceColor;

  /// 配色风格标题
  ///
  /// In zh, this message translates to:
  /// **'配色风格'**
  String get monetStyle;

  /// 高级选项标题
  ///
  /// In zh, this message translates to:
  /// **'高级选项'**
  String get monetAdvanced;

  /// 对比度设置
  ///
  /// In zh, this message translates to:
  /// **'对比度'**
  String get monetContrast;

  /// 方案名称标题
  ///
  /// In zh, this message translates to:
  /// **'方案名称'**
  String get monetSchemeName;

  /// 方案名称提示
  ///
  /// In zh, this message translates to:
  /// **'为配色方案命名'**
  String get monetSchemeNameHint;

  /// 配色预览标题
  ///
  /// In zh, this message translates to:
  /// **'配色预览'**
  String get monetPreview;

  /// 浅色方案标题
  ///
  /// In zh, this message translates to:
  /// **'浅色方案'**
  String get monetLightScheme;

  /// 深色方案标题
  ///
  /// In zh, this message translates to:
  /// **'深色方案'**
  String get monetDarkScheme;

  /// 已保存方案标题
  ///
  /// In zh, this message translates to:
  /// **'已保存方案'**
  String get monetSavedSchemes;

  /// 使用中标签
  ///
  /// In zh, this message translates to:
  /// **'使用中'**
  String get monetActive;

  /// 应用按钮
  ///
  /// In zh, this message translates to:
  /// **'应用'**
  String get monetApply;

  /// 方案名称必填提示
  ///
  /// In zh, this message translates to:
  /// **'请输入方案名称'**
  String get monetNameRequired;

  /// 保存成功提示
  ///
  /// In zh, this message translates to:
  /// **'配色方案已保存'**
  String get monetSaved;
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
