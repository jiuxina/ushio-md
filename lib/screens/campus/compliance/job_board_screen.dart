import 'package:flutter/material.dart';

import '../../../utils/constants.dart';

/// 校园招聘大厅
///
/// 展示岗位列表，支持搜索与筛选，点击查看详情与一键投递。
class JobBoardScreen extends StatefulWidget {
  const JobBoardScreen({super.key});

  @override
  State<JobBoardScreen> createState() => _JobBoardScreenState();
}

class _JobBoardScreenState extends State<JobBoardScreen> {
  final _searchController = TextEditingController();
  String _selectedFilter = '全部';

  static const _filters = ['全部', '实习', '兼职', '全职', '校招'];

  // 模拟数据
  static final _jobs = <_Job>[
    _Job(
      title: 'Flutter 开发实习生',
      company: '星河科技',
      companyInitial: '星',
      companyColor: AppConstants.primaryColor,
      salary: '3K-5K/月',
      type: '实习',
      tags: ['五险一金', '弹性工作', '应届可投'],
      description: '负责移动端 Flutter 应用的开发与维护，参与产品需求分析和技术方案设计。',
      requirements: ['计算机相关专业', '熟悉 Dart/Flutter', '良好的学习能力'],
    ),
    _Job(
      title: '校园大使',
      company: '未来教育',
      companyInitial: '未',
      companyColor: AppConstants.accentColor,
      salary: '2K-3K/月',
      type: '兼职',
      tags: ['双休', '时间灵活'],
      description: '负责校园品牌推广和活动组织，协助市场团队完成各类校园营销活动。',
      requirements: ['善于沟通', '有组织能力', '社交活跃'],
    ),
    _Job(
      title: '产品经理',
      company: '数联云',
      companyInitial: '数',
      companyColor: AppConstants.successColor,
      salary: '15K-25K/月',
      type: '全职',
      tags: ['五险一金', '双休', '年终奖'],
      description: '负责教育类产品的需求分析、产品设计和项目推进。',
      requirements: ['本科及以上学历', '2年以上产品经验', '逻辑思维强'],
    ),
    _Job(
      title: 'Java 后端工程师',
      company: '广西银行',
      companyInitial: '广',
      companyColor: AppConstants.warningColor,
      salary: '12K-20K/月',
      type: '校招',
      tags: ['五险一金', '双休', '国企', '应届可投'],
      description: '参与核心业务系统后端开发，负责系统架构设计与性能优化。',
      requirements: ['2025届毕业生', '计算机相关专业', '熟悉 Spring Boot'],
    ),
  ];

  List<_Job> get _filteredJobs {
    var list = _jobs;
    if (_selectedFilter != '全部') {
      list = list.where((j) => j.type == _selectedFilter).toList();
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list
          .where((j) =>
              j.title.toLowerCase().contains(query) ||
              j.company.toLowerCase().contains(query))
          .toList();
    }
    return list;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final jobs = _filteredJobs;

    return Scaffold(
      appBar: AppBar(title: const Text('校园招聘')),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: '搜索岗位或公司',
                prefixIcon: const Icon(Icons.search_rounded),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          // Filter chips
          SizedBox(
            height: 52,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final f = _filters[i];
                final selected = f == _selectedFilter;
                return FilterChip(
                  label: Text(f),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedFilter = f),
                  selectedColor:
                      AppConstants.primaryColor.withValues(alpha: 0.15),
                  checkmarkColor: AppConstants.primaryColor,
                  labelStyle: TextStyle(
                    color: selected
                        ? AppConstants.primaryColor
                        : Theme.of(context).colorScheme.onSurface,
                    fontWeight: selected ? FontWeight.w600 : null,
                  ),
                );
              },
            ),
          ),
          // Job list
          Expanded(
            child: jobs.isEmpty
                ? _buildEmpty(context)
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: jobs.length,
                    itemBuilder: (context, i) =>
                        _buildJobCard(context, jobs[i]),
                  ),
          ),
        ],
      ),
    );
  }

  // ==================== Empty State ====================

  Widget _buildEmpty(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.work_off_rounded, size: 64, color: cs.outline),
          const SizedBox(height: 16),
          Text('暂无招聘信息',
              style: theme.textTheme.bodyLarge?.copyWith(color: cs.outline)),
        ],
      ),
    );
  }

  // ==================== Job Card ====================

  Widget _buildJobCard(BuildContext context, _Job job) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showJobDetail(context, job),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Company logo
                CircleAvatar(
                  radius: 22,
                  backgroundColor: job.companyColor.withValues(alpha: 0.15),
                  child: Text(
                    job.companyInitial,
                    style: TextStyle(
                        color: job.companyColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18),
                  ),
                ),
                const SizedBox(width: 14),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(job.title,
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text(
                        '${job.company}  ·  ${job.salary}',
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: cs.outline),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: job.tags
                            .map((t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppConstants.primaryColor
                                        .withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(t,
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: AppConstants.primaryColor)),
                                ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                // Apply button
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('已投递「${job.title}」')),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('一键投递',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== Job Detail Bottom Sheet ====================

  void _showJobDetail(BuildContext context, _Job job) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  children: [
                    // Header
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor:
                              job.companyColor.withValues(alpha: 0.15),
                          child: Text(job.companyInitial,
                              style: TextStyle(
                                  color: job.companyColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(job.title,
                                  style: theme.textTheme.titleMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.bold)),
                              Text(job.company,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: cs.outline)),
                            ],
                          ),
                        ),
                        Text(job.salary,
                            style: theme.textTheme.titleMedium?.copyWith(
                                color: AppConstants.warningColor,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: job.tags
                          .map((t) => Chip(
                                label: Text(t,
                                    style: const TextStyle(fontSize: 11)),
                                visualDensity: VisualDensity.compact,
                                materialTapTargetSize:
                                    MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                    const Divider(height: 32),
                    // Description
                    Text('岗位描述',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(job.description,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 20),
                    // Requirements
                    Text('任职要求',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...job.requirements.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 16, color: AppConstants.successColor),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(r,
                                      style: theme.textTheme.bodyMedium)),
                            ],
                          ),
                        )),
                    const SizedBox(height: 20),
                    // Company info
                    Text('公司信息',
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text('${job.company} · 互联网/教育行业',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(color: cs.outline)),
                  ],
                ),
              ),
              // Bottom button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('已投递「${job.title}」')),
                      );
                    },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('投递简历'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== Data Model ====================

class _Job {
  final String title;
  final String company;
  final String companyInitial;
  final Color companyColor;
  final String salary;
  final String type;
  final List<String> tags;
  final String description;
  final List<String> requirements;

  const _Job({
    required this.title,
    required this.company,
    required this.companyInitial,
    required this.companyColor,
    required this.salary,
    required this.type,
    required this.tags,
    required this.description,
    required this.requirements,
  });
}
