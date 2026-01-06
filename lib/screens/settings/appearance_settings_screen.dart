// ============================================================================
// 外观设置页面
// 
// 设置主题模式、主题色、字体、背景等外观相关选项
// ============================================================================

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/settings_provider.dart';
import '../../utils/constants.dart';
import '../../services/font_service.dart';
import '../../widgets/app_background.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  State<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  List<CustomFontInfo> _customFonts = [];
  bool _loadingFonts = true;

  @override
  void initState() {
    super.initState();
    _loadCustomFonts();
  }

  Future<void> _loadCustomFonts() async {
    final fonts = await FontService.getInstalledCustomFonts();
    if (mounted) {
      setState(() {
        _customFonts = fonts;
        _loadingFonts = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('外观设置'),
        centerTitle: true,
      ),
      body: AppBackground(
        child: Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _buildSection('主题模式', Icons.brightness_6, [
                  _buildThemeModeSelector(settings),
                ]),
                
                const SizedBox(height: 16),
                
                _buildSection('主题色', Icons.color_lens, [
                  _buildThemeColorSelector(settings),
                ]),
                
                // 浅色主题方案（仅在浅色模式下显示）
                if (settings.themeMode == ThemeMode.light) ...[
                  const SizedBox(height: 16),
                  _buildSection('浅色主题', Icons.light_mode, [
                    _buildLightThemeSelector(settings),
                  ]),
                ],
                
                // 夜间主题方案（仅在深色模式下显示）
                if (settings.themeMode == ThemeMode.dark) ...[
                  const SizedBox(height: 16),
                  _buildSection('夜间主题', Icons.dark_mode, [
                    _buildDarkThemeSelector(settings),
                  ]),
                ],
                
                const SizedBox(height: 16),
                
                _buildSection('字体', Icons.font_download, [
                  _buildFontSelector(settings),
                ]),
                
                const SizedBox(height: 16),
                
                _buildSection('背景', Icons.image, [
                  _buildBackgroundSettings(settings),
                ]),
                
                const SizedBox(height: 16),
                
                _buildSection('粒子效果', Icons.auto_awesome, [
                  _buildParticleSettings(settings),
                ]),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildThemeModeSelector(SettingsProvider settings) {
    return Row(
      children: [
        Expanded(
          child: _buildThemeModeOption(
            settings,
            ThemeMode.system,
            Icons.brightness_auto,
            '跟随系统',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildThemeModeOption(
            settings,
            ThemeMode.light,
            Icons.light_mode,
            '浅色',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildThemeModeOption(
            settings,
            ThemeMode.dark,
            Icons.dark_mode,
            '深色',
          ),
        ),
      ],
    );
  }

  Widget _buildThemeModeOption(
    SettingsProvider settings,
    ThemeMode mode,
    IconData icon,
    String label,
  ) {
    final isSelected = settings.themeMode == mode;
    return GestureDetector(
      onTap: () => settings.setThemeMode(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeColorSelector(SettingsProvider settings) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: SettingsProvider.themeColors.asMap().entries.map((entry) {
        final index = entry.key;
        final color = entry.value;
        final isSelected = settings.primaryColorIndex == index;
        return GestureDetector(
          onTap: () => settings.setPrimaryColorIndex(index),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 20)
                : null,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLightThemeSelector(SettingsProvider settings) {
    return Column(
      children: List.generate(AppConstants.lightThemeSchemes.length, (index) {
        final scheme = AppConstants.lightThemeSchemes[index];
        final isSelected = settings.lightThemeIndex == index;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => settings.setLightThemeIndex(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scheme.textSecondary.withValues(alpha: 0.3)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      scheme.name,
                      style: TextStyle(color: scheme.text),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, 
                         color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildDarkThemeSelector(SettingsProvider settings) {
    return Column(
      children: List.generate(AppConstants.darkThemeSchemes.length, (index) {
        final scheme = AppConstants.darkThemeSchemes[index];
        final isSelected = settings.darkThemeIndex == index;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => settings.setDarkThemeIndex(index),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      scheme.name,
                      style: TextStyle(color: scheme.text),
                    ),
                  ),
                  if (isSelected)
                    Icon(Icons.check_circle, 
                         color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildFontSelector(SettingsProvider settings) {
    // 构建字体选项列表
    final fontItems = <DropdownMenuItem<String>>[];
    final seenFamilies = <String>{};

    // 1. 添加预设字体
    for (var font in AppConstants.availableFonts) {
      if (seenFamilies.add(font.fontFamily)) {
        fontItems.add(DropdownMenuItem(
          value: font.fontFamily,
          child: Text(font.name),
        ));
      }
    }

    // 2. 添加自定义字体
    for (final font in _customFonts) {
      // 自定义字体加载时使用的是 font.name 作为 family name
      if (seenFamilies.add(font.name)) {
        fontItems.add(DropdownMenuItem(
          value: font.name,
          child: Text(font.name),
        ));
      }
    }
    
    // 确保当前选中的字体在列表中，如果不在（可能被删除），则回退到 System
    String getValidFontFamily(String current) {
      return seenFamilies.contains(current) ? current : 'System';
    }

    return Column(
      children: [
        // UI 字体
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('界面字体'),
            DropdownButton<String>(
              value: getValidFontFamily(settings.uiFontFamily),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: fontItems,
              onChanged: (value) {
                if (value != null) settings.setUiFontFamily(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 编辑器字体
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('编辑器字体'),
            DropdownButton<String>(
              value: getValidFontFamily(settings.editorFontFamily),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: fontItems,
              onChanged: (value) {
                if (value != null) settings.setEditorFontFamily(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        // 代码字体
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('代码字体'),
            DropdownButton<String>(
              value: getValidFontFamily(settings.codeFontFamily),
              underline: const SizedBox(),
              borderRadius: BorderRadius.circular(12),
              items: fontItems,
              onChanged: (value) {
                if (value != null) settings.setCodeFontFamily(value);
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        // 安装自定义字体按钮
        OutlinedButton.icon(
          onPressed: _loadingFonts ? null : () async {
            final fontName = await FontService.installFontFromFile(context);
            if (fontName != null) {
              await _loadCustomFonts();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('字体 "$fontName" 安装成功'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('安装自定义字体'),
        ),
      ],
    );
  }

  Widget _buildBackgroundSettings(SettingsProvider settings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 选择背景图片
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('背景图片'),
            TextButton.icon(
              onPressed: () => _pickBackgroundImage(settings),
              icon: const Icon(Icons.image, size: 18),
              label: const Text('选择'),
            ),
          ],
        ),
        if (settings.backgroundImagePath != null) ...[
          const SizedBox(height: 8),
          // 背景预览
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(settings.backgroundImagePath!),
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  height: 100,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Center(child: Text('图片加载失败')),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // 背景效果选择
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('模糊效果'),
              Switch(
                value: settings.backgroundEffect == 'blur',
                onChanged: (value) {
                  settings.setBackgroundEffect(value ? 'blur' : 'none');
                },
              ),
            ],
          ),
          // 模糊强度滑块
          if (settings.backgroundEffect == 'blur') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('模糊强度'),
                Expanded(
                  child: Slider(
                    value: settings.backgroundBlur,
                    min: 0,
                    max: 100,
                    divisions: 100,
                    label: settings.backgroundBlur.round().toString(),
                    onChanged: (value) => settings.setBackgroundBlur(value),
                  ),
                ),
                Text('${settings.backgroundBlur.round()}'),
              ],
            ),
          ],
          const SizedBox(height: 8),
          // 移除背景按钮
          TextButton.icon(
            onPressed: () => settings.setBackgroundImage(null),
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
            label: const Text('移除背景', style: TextStyle(color: Colors.red)),
          ),
        ],
      ],
    );
  }

  /// 构建粒子效果设置
  Widget _buildParticleSettings(SettingsProvider settings) {
    // 粒子效果类型定义
    const particleTypes = [
      {'id': 'sakura', 'name': '樱花', 'icon': '🌸'},
      {'id': 'rain', 'name': '下雨', 'icon': '🌧️'},
      {'id': 'firefly', 'name': '萤火虫', 'icon': '✨'},
      {'id': 'snow', 'name': '雪花', 'icon': '❄️'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 启用开关
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('启用粒子效果'),
            Switch(
              value: settings.particleEnabled,
              onChanged: (v) => settings.setParticleEnabled(v),
            ),
          ],
        ),
        
        // 以下选项仅在启用时显示
        if (settings.particleEnabled) ...[
          const SizedBox(height: 16),
          
          // 效果类型选择器
          Text(
            '效果类型',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: 8),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.5,
            children: particleTypes.map((type) {
              final isSelected = settings.particleType == type['id'];
              return GestureDetector(
                onTap: () => settings.setParticleType(type['id']!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1)
                        : Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).dividerColor,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        type['icon']!,
                        style: const TextStyle(fontSize: 18),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        type['name']!,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 16),
          
          // 速率滑块
          Row(
            children: [
              const Text('粒子速率'),
              Expanded(
                child: Slider(
                  value: settings.particleSpeed,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  label: '${settings.particleSpeed.toStringAsFixed(1)}x',
                  onChanged: (value) => settings.setParticleSpeed(value),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${settings.particleSpeed.toStringAsFixed(1)}x',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 8),
          
          // 全局显示开关
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('全局显示'),
                    Text(
                      settings.particleGlobal 
                          ? '所有界面都显示粒子效果' 
                          : '编辑器内容区域不显示粒子效果',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.particleGlobal,
                onChanged: (v) => settings.setParticleGlobal(v),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pickBackgroundImage(SettingsProvider settings) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        settings.setBackgroundImage(path);
      }
    }
  }
}
