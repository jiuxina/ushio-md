// ============================================================================
// 莫奈取色设置页面
//
// 提供从图片提取颜色并生成 Material You 配色方案的功能
// 包含：图片选择、配色风格选择、高级选项、预览和管理
// ============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';

import '../../../providers/settings_provider.dart';
import '../../../models/monet_config.dart';
import '../../../utils/monet_palette.dart';
import '../../../utils/app_style.dart';
import '../../../l10n/app_localizations.dart';
import '../../../widgets/app_background.dart';

/// 莫奈取色设置页面
class MonetSettingsScreen extends StatefulWidget {
  const MonetSettingsScreen({super.key});

  @override
  State<MonetSettingsScreen> createState() => _MonetSettingsScreenState();
}

class _MonetSettingsScreenState extends State<MonetSettingsScreen> {
  // 提取的颜色列表
  List<Color> _extractedColors = [];
  
  // 选中的源色索引
  int _selectedSourceColorIndex = 0;
  
  // 当前配色风格
  MonetStyleVariant _selectedVariant = MonetStyleVariant.tonalSpot;
  
  // 对比度调整
  double _contrastLevel = 0.0;
  
  // 预览配色方案
  MonetScheme? _previewScheme;
  
  // 加载状态
  bool _isLoading = false;
  
  // 图片路径
  String? _selectedImagePath;
  
  // 方案名称控制器
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  AppStyleTheme get appStyle => Theme.of(context).extension<AppStyleTheme>()!;

  /// 选择图片并提取颜色
  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final path = result.files.first.path;
      if (path == null) return;

      setState(() {
        _isLoading = true;
        _selectedImagePath = path;
      });

      // 提取颜色
      final colors = await MonetPalette.extractColorsFromImage(path);
      
      if (mounted) {
        setState(() {
          _extractedColors = colors;
          _selectedSourceColorIndex = 0;
          _isLoading = false;
        });
        _updatePreview();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('提取颜色失败: $e')),
        );
      }
    }
  }

  /// 从预设颜色选择
  void _selectPresetColor(Color color) {
    setState(() {
      _extractedColors = [color];
      _selectedSourceColorIndex = 0;
      _selectedImagePath = null;
    });
    _updatePreview();
  }

  /// 更新预览
  void _updatePreview() {
    if (_extractedColors.isEmpty) return;

    final sourceColor = _extractedColors[_selectedSourceColorIndex];
    final scheme = MonetPalette.generateScheme(
      sourceColor,
      variant: _selectedVariant,
      contrastLevel: _contrastLevel,
    );

    setState(() {
      _previewScheme = scheme;
    });
  }

  /// 保存配色方案
  Future<void> _saveScheme() async {
    if (_previewScheme == null) return;

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.monetNameRequired)),
      );
      return;
    }

    final config = MonetConfig(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      sourceImagePath: _selectedImagePath,
      sourceColor: _previewScheme!.sourceColor,
      styleVariant: _selectedVariant,
      contrastLevel: _contrastLevel,
      scheme: _previewScheme!,
    );

    final settings = context.read<SettingsProvider>();
    await settings.addMonetConfig(config);
    await settings.setActiveMonetConfig(config.id);
    await settings.setMonetEnabled(true);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.monetSaved)),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();

    return AppBackground(
      wrapWithSafeArea: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          title: Text(l10n.monetSettings),
          centerTitle: true,
          actions: [
            if (_previewScheme != null)
              TextButton(
                onPressed: _saveScheme,
                child: Text(l10n.save),
              ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // 启用莫奈取色开关
                  _buildEnableSwitch(settings, l10n),
                  
                  const SizedBox(height: 16),

                  // 图片选择区域
                  _buildImagePickerSection(l10n),

                  const SizedBox(height: 16),

                  // 预设颜色区域
                  _buildPresetColorsSection(l10n),

                  if (_extractedColors.isNotEmpty) ...[
                    const SizedBox(height: 16),

                    // 源色选择
                    _buildSourceColorSelector(l10n),

                    const SizedBox(height: 16),

                    // 配色风格选择
                    _buildStyleVariantSelector(l10n),

                    const SizedBox(height: 16),

                    // 高级选项
                    _buildAdvancedOptions(l10n),

                    const SizedBox(height: 16),

                    // 方案名称
                    _buildNameInput(l10n),
                  ],

                  if (_previewScheme != null) ...[
                    const SizedBox(height: 24),

                    // 配色预览
                    _buildColorSchemePreview(l10n),
                  ],

                  // 已保存的方案
                  if (settings.savedMonetConfigs.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildSavedSchemesSection(settings, l10n),
                  ],
                ],
              ),
      ),
    );
  }

  /// 构建启用开关
  Widget _buildEnableSwitch(SettingsProvider settings, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.monetEnabled,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.monetEnabledDesc,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(
            value: settings.monetEnabled,
            onChanged: (value) => settings.setMonetEnabled(value),
          ),
        ],
      ),
    );
  }

  /// 构建图片选择区域
  Widget _buildImagePickerSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.image_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.monetFromImage,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 图片预览或选择按钮
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline,
                  width: 1,
                ),
              ),
              child: _selectedImagePath != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_selectedImagePath!),
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_photo_alternate_outlined,
                          size: 48,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.monetSelectImage,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建预设颜色区域
  Widget _buildPresetColorsSection(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.palette_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.monetFromColor,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: SettingsProvider.themeColors.map((color) {
              return GestureDetector(
                onTap: () => _selectPresetColor(color),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建源色选择器
  Widget _buildSourceColorSelector(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.colorize,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.monetSourceColor,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _extractedColors.length,
              itemBuilder: (context, index) {
                final color = _extractedColors[index];
                final isSelected = index == _selectedSourceColorIndex;
                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedSourceColorIndex = index);
                    _updatePreview();
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outline,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: isSelected
                        ? Icon(
                            Icons.check,
                            color: color.computeLuminance() > 0.5
                                ? Colors.black
                                : Colors.white,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// 构建配色风格选择器
  Widget _buildStyleVariantSelector(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.style,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.monetStyle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MonetStyleVariantUtils.allVariants.map((variant) {
              final isSelected = variant == _selectedVariant;
              return GestureDetector(
                onTap: () {
                  setState(() => _selectedVariant = variant);
                  _updatePreview();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        variant.getIcon(),
                        size: 16,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        variant.getDisplayName(),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  /// 构建高级选项
  Widget _buildAdvancedOptions(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.tune,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.monetAdvanced,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 对比度调整
          Row(
            children: [
              Text(l10n.monetContrast),
              Expanded(
                child: Slider(
                  value: _contrastLevel,
                  min: -1.0,
                  max: 1.0,
                  divisions: 20,
                  label: _contrastLevel.toStringAsFixed(1),
                  onChanged: (value) {
                    setState(() => _contrastLevel = value);
                    _updatePreview();
                  },
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  _contrastLevel.toStringAsFixed(1),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建名称输入
  Widget _buildNameInput(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.label_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.monetSchemeName,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              hintText: l10n.monetSchemeNameHint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建配色预览
  Widget _buildColorSchemePreview(AppLocalizations l10n) {
    if (_previewScheme == null) return const SizedBox.shrink();

    final lightScheme = _previewScheme!.lightScheme;
    final darkScheme = _previewScheme!.darkScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.preview,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.monetPreview,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 浅色方案预览
          Text(
            l10n.monetLightScheme,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          _buildSchemePreview(lightScheme),
          
          const SizedBox(height: 16),
          
          // 深色方案预览
          Text(
            l10n.monetDarkScheme,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(height: 8),
          _buildSchemePreview(darkScheme),
        ],
      ),
    );
  }

  /// 构建单个配色方案预览
  Widget _buildSchemePreview(MonetColorScheme scheme) {
    final colors = [
      ('P', scheme.primary),
      ('PC', scheme.primaryContainer),
      ('S', scheme.secondary),
      ('SC', scheme.secondaryContainer),
      ('T', scheme.tertiary),
      ('TC', scheme.tertiaryContainer),
      ('Bg', scheme.background),
      ('Sf', scheme.surface),
    ];

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outline),
      ),
      child: Row(
        children: colors.map((item) {
          final (label, color) = item;
          return Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  /// 构建已保存方案区域
  Widget _buildSavedSchemesSection(SettingsProvider settings, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: appStyle.surfaceDecoration(
        borderRadius: BorderRadius.circular(16),
        color: appStyle.cardSurfaceColor(Theme.of(context).colorScheme),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.bookmark_outline,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    l10n.monetSavedSchemes,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Text(
                '${settings.savedMonetConfigs.length}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...settings.savedMonetConfigs.map((config) {
            final isActive = config.id == settings.activeMonetConfig?.id;
            return _buildSavedSchemeItem(config, isActive, settings, l10n);
          }),
        ],
      ),
    );
  }

  /// 构建已保存方案项
  Widget _buildSavedSchemeItem(
    MonetConfig config,
    bool isActive,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    final scheme = config.scheme.lightScheme;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          width: isActive ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      config.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      config.styleVariant.getDisplayName(),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    l10n.monetActive,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          
          // 颜色预览条
          Row(
            children: [
              _buildColorChip(scheme.primary),
              const SizedBox(width: 4),
              _buildColorChip(scheme.secondary),
              const SizedBox(width: 4),
              _buildColorChip(scheme.tertiary),
              const SizedBox(width: 4),
              _buildColorChip(scheme.primaryContainer),
              const SizedBox(width: 4),
              _buildColorChip(scheme.secondaryContainer),
            ],
          ),
          const SizedBox(height: 12),
          
          // 操作按钮
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!isActive)
                TextButton(
                  onPressed: () async {
                    await settings.setActiveMonetConfig(config.id);
                    await settings.setMonetEnabled(true);
                  },
                  child: Text(l10n.monetApply),
                ),
              TextButton(
                onPressed: () => settings.removeMonetConfig(config.id),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(l10n.delete),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorChip(Color color) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline,
          width: 0.5,
        ),
      ),
    );
  }
}
