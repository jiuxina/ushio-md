# 相思同行 - 广西民族大学智慧校园服务应用 🏫

<p align="center">
  <img src="app.png" width="180" alt="相思同行 Logo">
</p>
<p align="center">
  <b>广西民族大学智慧校园一站式服务平台</b><br>
  校园看板 · 学业中心 · 智慧办事 · 社区场馆 · 个人中心
</p>

<p align="center">
  <a href="https://github.com/jiuxina/ushio-md/stargazers">
    <img src="https://img.shields.io/github/stars/jiuxina/ushio-md?style=social" alt="GitHub stars">
  </a>
  <a href="https://github.com/jiuxina/ushio-md/blob/main/LICENSE">
    <img src="https://img.shields.io/github/license/jiuxina/ushio-md" alt="GitHub license">
  </a>
  <a href="https://flutter.dev">
    <img src="https://img.shields.io/badge/Flutter-跨平台-blue?logo=flutter" alt="Flutter">
  </a>
  <a href="https://supabase.com">
    <img src="https://img.shields.io/badge/Supabase-后端服务-3ECF8E?logo=supabase" alt="Supabase">
  </a>
</p>

---

## 目录

- [功能特性](#-功能特性)
- [实现进度](#-实现进度)
- [技术栈](#-技术栈)
- [数据库配置](#-数据库配置)
- [数据库结构](#-数据库结构)
- [项目结构](#-项目结构)
- [构建与运行](#-构建与运行)
- [贡献](#-贡献)
- [开源协议](#-开源协议)
- [致谢](#-致谢)

---

## ✨ 功能特性

### 🏠 首页看板

- 实时天气信息展示
- 校巴运行状态查询
- 下一节课提醒
- 校园卡余额显示
- 快捷服务宫格入口（图书馆、充值、报修、成绩等）
- 校园公告与通知轮播

### 📚 学业中心

- GPA 总览与学期走势
- 课程表（周视图，按星期/节次排列）
- 成绩列表与学分统计
- 证书办理服务入口
- 毕业进度追踪

### 📋 智慧办事

- 请假申请（支持选择假别、起止时间、去向、事由、附件上传）
- 审批时间线，实时查看请假状态
- 报修申请提交
- 各类办事申请进度跟踪

### 🤝 社区与场馆

- 校园动态信息流（帖子、图片、话题）
- 场馆在线预约（体育馆、自习室、会议室等）
- 心情打卡签到
- 心理健康资源入口

### 👤 我的

- 个人信息卡片（头像、姓名、学号、学院、专业）
- 数字校园码（扫码通行）
- 缴费与充值
- 系统设置（主题切换、通知管理）
- 隐私与安全
- 退出登录

### 👨‍🏫 教师与管理者视图 (Module 10)

- **身份动态切换** —— 我的页面一键切换教职工模式
- **辅导员移动驾驶舱** —— 高危学生预警雷达（红/黄/蓝三色分级）、批量审批中心（侧滑同意/驳回）、一键寻人、学生画像穿透
- **任课教师工具箱** —— 课堂点名（QR 码动态刷新 + 蓝牙感应雷达动画）、成绩录入面板（极速数字小键盘）
- **权限越权访问拦截** —— 403 无权限页面

### 🌏 民大东盟与民族特色专区 (Module 11)

- **多语种国际化 UI** —— 全局语言切换面板（中/泰/越/老/柬/英 6 种语言）、专业名词多语种对照词典
- **留学生跨境办事服务** —— 居留签证到期红色倒计时卡片、双语智能办事指南、语伴结对匹配滑动卡片
- **石榴籽民族文化空间** —— 民族节日打卡地图（三月三/歌圩节）、素拓分换算明细、民族服饰 AR 试穿体验界面

### 🤖 相思 AI 助理 (Module 12)

- **全局唤醒** —— 右下角悬浮拖拽球（呼吸灯动效）、语音输入态（拾音波浪线动画）
- **对话界面** —— 流式打字机输出效果、快捷 Prompt 建议筹码、多轮对话上下文折叠、点赞/点踩/重新生成
- **意图识别与卡片渲染** —— 文本转指令（对话流中直接渲染请假单表单卡片）、信息聚合卡（课表图文排版卡片）

### 📋 合规、增长与运营矩阵 (Module 13)

- **隐私与合规** —— 个人信息收集清单、第三方共享清单、账号注销全流程（15 天犹豫期）、青少年/防沉迷模式
- **新手引导与增长** —— 首次安装蒙版引导、老带新裂变海报生成器、签到体系（金币/积分掉落动效与存钱罐 UI）
- **商业化拓展** —— 开屏广告倒计时跳过组件、信息流原生广告位、校企直聘专栏（企业微主页与简历一键投递）

---

## 📊 实现进度

### 已完成 ✅

- [x] 完整的登录/认证流程，集成 Supabase Auth
- [x] 5 Tab 主导航结构（首页 / 学业 / 办事 / 社区 / 我的）
- [x] 所有 Tab 页面完整 UI 实现
- [x] Supabase 服务层，支持维护模式检测
- [x] 13 个数据模型（CampusUser、Course、Grade、LeaveRequest、Announcement、Venue、VenueBooking、CommunityPost、StudentAlert、AttendanceRecord、ChatMessage、LanguagePartner、CulturalEvent）
- [x] Auth Provider —— 会话管理与登录状态维持
- [x] Campus Data Provider —— 统一数据获取与错误处理
- [x] Teacher Provider —— 教师模式切换、审批、考勤管理
- [x] AI Provider —— 流式对话模拟、语音输入状态
- [x] 维护模式提示 —— Supabase 未配置时自动降级展示
- [x] 主题系统（5 套浅色 + 6 套深色主题方案，12 种强调色）
- [x] **模块 10**：教师与管理者视图（辅导员驾驶舱、批量审批、QR 点名、成绩录入、403 页面）
- [x] **模块 11**：民大东盟与民族特色专区（多语种面板、签证倒计时、语伴匹配、民族文化空间）
- [x] **模块 12**：相思 AI 助理（悬浮拖拽球、流式对话 UI、语音波浪线、意图卡片渲染）
- [x] **模块 13**：合规与运营矩阵（隐私中心、账号注销、青少年模式、新手引导、签到体系、裂变海报、校企直聘）

### 待开发 ⬜

- [ ] 推送通知
- [ ] 附件文件上传
- [ ] 实时数据订阅（Supabase Realtime）
- [ ] 离线缓存
- [ ] AI 大模型接入（当前为模拟响应，后续接入 LLM API）
- [ ] AR 民族服饰试穿（需要 AR 引擎集成）
- [ ] 蓝牙近场考勤（需要蓝牙 BLE 插件）

---

## 🛠 技术栈

| 技术 | 用途 |
| --- | --- |
| **Flutter** | 跨平台 UI 框架（Android / iOS / Web / Desktop） |
| **Provider** | 状态管理 |
| **Supabase** | 后端服务（认证、数据库、存储） |
| **Material 3** | UI 设计规范 |

---

## ⚙ 数据库配置

本项目使用 [Supabase](https://supabase.com) 作为后端服务。请按以下步骤配置：

### 1. 创建 Supabase 项目

1. 前往 [supabase.com](https://supabase.com) 注册并创建一个新项目
2. 在项目 **Settings → API** 页面获取：
   - **Project URL**（例如 `https://xxxxx.supabase.co`）
   - **anon public key**（匿名公钥）

### 2. 修改配置文件

配置文件位于：

```
lib/config/supabase_config.dart
```

将文件中的占位符替换为你的真实值：

```dart
class SupabaseConfig {
  static const String supabaseUrl = 'https://YOUR_PROJECT.supabase.co';
  static const String supabaseAnonKey = 'YOUR_ANON_KEY';
}
```

### 3. 创建数据库表

在 Supabase 控制台的 **SQL Editor** 中执行下方 [数据库结构](#-数据库结构) 部分的建表 SQL。

### 4. 未配置时的行为

如果未替换占位符，应用将自动进入 **维护模式**：

- 所有页面显示维护提示横幅
- UI 仍可正常浏览，但数据请求将被拦截
- 不会产生错误崩溃

---

## 🗄 数据库结构

以下为完整的建表 SQL，可直接在 Supabase SQL Editor 中执行：

```sql
-- profiles 表（扩展 Supabase auth.users）
CREATE TABLE profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id),
  student_id TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  avatar TEXT,
  college TEXT,
  major TEXT,
  grade TEXT,
  role TEXT DEFAULT '本科生',
  phone TEXT,
  email TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- courses 课程表
CREATE TABLE courses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  name TEXT NOT NULL,
  teacher TEXT,
  location TEXT,
  day_of_week INTEGER,
  start_period INTEGER,
  end_period INTEGER,
  start_week INTEGER,
  end_week INTEGER,
  semester TEXT,
  credit NUMERIC(3,1),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- grades 成绩表
CREATE TABLE grades (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id UUID REFERENCES courses(id),
  course_name TEXT NOT NULL,
  score NUMERIC(5,2),
  credit NUMERIC(3,1),
  grade_point NUMERIC(3,2),
  semester TEXT,
  rank TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- announcements 公告表
CREATE TABLE announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  content TEXT,
  department TEXT,
  category TEXT,
  is_important BOOLEAN DEFAULT false,
  published_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- leave_requests 请假申请表
CREATE TABLE leave_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  type TEXT NOT NULL,
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ NOT NULL,
  reason TEXT,
  destination TEXT,
  attachments JSONB DEFAULT '[]',
  status TEXT DEFAULT 'pending',
  reviewer_comment TEXT,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- venues 场馆表
CREATE TABLE venues (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  type TEXT,
  location TEXT,
  capacity INTEGER DEFAULT 0,
  is_available BOOLEAN DEFAULT true,
  image_url TEXT,
  description TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- venue_bookings 场馆预约表
CREATE TABLE venue_bookings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  venue_id UUID REFERENCES venues(id),
  date DATE NOT NULL,
  time_slot TEXT NOT NULL,
  status TEXT DEFAULT 'pending',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- community_posts 社区帖子表
CREATE TABLE community_posts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  user_name TEXT,
  user_avatar TEXT,
  content TEXT NOT NULL,
  images JSONB DEFAULT '[]',
  topic TEXT,
  like_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ===================== Module 10: 教师与管理者 =====================

-- student_alerts 高危学生预警表
CREATE TABLE student_alerts (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  student_id TEXT NOT NULL,
  student_name TEXT NOT NULL,
  college TEXT,
  alert_level TEXT NOT NULL CHECK (alert_level IN ('red', 'yellow', 'blue')),
  reason TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- attendance_records 考勤记录表
CREATE TABLE attendance_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  course_id TEXT NOT NULL,
  course_name TEXT,
  student_id TEXT NOT NULL,
  student_name TEXT,
  status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'late')),
  checked_at TIMESTAMPTZ DEFAULT now()
);

-- ===================== Module 11: 东盟与民族特色 =====================

-- language_partners 语伴匹配表
CREATE TABLE language_partners (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  user_name TEXT NOT NULL,
  user_avatar TEXT,
  native_language TEXT NOT NULL,
  learning_language TEXT NOT NULL,
  college TEXT,
  bio TEXT,
  interests JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- partner_matches 语伴匹配记录表
CREATE TABLE partner_matches (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  from_user_id UUID REFERENCES profiles(id),
  to_user_id UUID REFERENCES profiles(id),
  match_type TEXT DEFAULT 'like',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- cultural_events 民族文化活动表
CREATE TABLE cultural_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  description TEXT,
  event_type TEXT CHECK (event_type IN ('festival', 'performance', 'workshop')),
  ethnic_group TEXT,
  start_date DATE,
  end_date DATE,
  location TEXT,
  image_url TEXT,
  sutuo_credits NUMERIC(5,2) DEFAULT 0,
  participant_count INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- visa_info 留学生签证信息表
CREATE TABLE visa_info (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  visa_type TEXT,
  issue_date DATE,
  expiry_date DATE NOT NULL,
  status TEXT DEFAULT 'active',
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ===================== Module 12: AI 助理 =====================

-- ai_chat_messages AI 对话消息表
CREATE TABLE ai_chat_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  role TEXT NOT NULL CHECK (role IN ('user', 'assistant', 'system')),
  content TEXT NOT NULL,
  card_type TEXT,
  liked BOOLEAN,
  timestamp TIMESTAMPTZ DEFAULT now()
);

-- ===================== Module 13: 合规与运营 =====================

-- checkin_records 签到记录表
CREATE TABLE checkin_records (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  checkin_date DATE NOT NULL,
  streak_count INTEGER DEFAULT 1,
  points_earned INTEGER DEFAULT 0,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- job_listings 校企直聘岗位表
CREATE TABLE job_listings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title TEXT NOT NULL,
  company TEXT NOT NULL,
  company_logo TEXT,
  salary_range TEXT,
  job_type TEXT CHECK (job_type IN ('intern', 'part_time', 'full_time', 'campus')),
  location TEXT,
  description TEXT,
  requirements TEXT,
  tags JSONB DEFAULT '[]',
  contact_email TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- account_deletion_requests 账号注销申请表
CREATE TABLE account_deletion_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES profiles(id),
  reason TEXT,
  status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'withdrawn')),
  requested_at TIMESTAMPTZ DEFAULT now(),
  expires_at TIMESTAMPTZ,
  completed_at TIMESTAMPTZ
);
```

---

## 📁 项目结构

```
lib/
├── config/
│   └── supabase_config.dart          # Supabase 连接配置
├── main.dart                          # 应用入口
├── models/
│   ├── announcement.dart              # 公告模型
│   ├── attendance_record.dart         # 考勤记录模型 (Module 10)
│   ├── campus_user.dart               # 校园用户模型
│   ├── chat_message.dart              # AI 对话消息模型 (Module 12)
│   ├── community_post.dart            # 社区帖子模型
│   ├── course.dart                    # 课程模型
│   ├── cultural_event.dart            # 民族文化活动模型 (Module 11)
│   ├── grade.dart                     # 成绩模型
│   ├── language_partner.dart          # 语伴匹配模型 (Module 11)
│   ├── leave_request.dart             # 请假申请模型
│   ├── student_alert.dart             # 高危学生预警模型 (Module 10)
│   ├── venue.dart                     # 场馆模型
│   └── venue_booking.dart             # 场馆预约模型
├── providers/
│   ├── ai_provider.dart               # AI 助理状态管理 (Module 12)
│   ├── auth_provider.dart             # 认证状态管理
│   ├── campus_provider.dart           # 校园数据状态管理
│   ├── settings_provider.dart         # 设置状态管理
│   └── teacher_provider.dart          # 教师模式状态管理 (Module 10)
├── screens/
│   ├── auth/
│   │   └── login_screen.dart          # 登录页
│   ├── campus/
│   │   ├── academic/
│   │   │   └── academic_tab.dart      # 学业中心
│   │   ├── ai/                        # Module 12
│   │   │   └── ai_chat_screen.dart    # AI 对话界面
│   │   ├── asean/                     # Module 11
│   │   │   ├── asean_hub_screen.dart  # 东盟与民族特色专区
│   │   │   └── language_partner_screen.dart  # 语伴匹配
│   │   ├── community/
│   │   │   └── community_tab.dart     # 社区与场馆
│   │   ├── compliance/                # Module 13
│   │   │   ├── account_deletion_screen.dart  # 账号注销
│   │   │   ├── checkin_screen.dart     # 每日签到
│   │   │   ├── job_board_screen.dart   # 校企直聘
│   │   │   ├── onboarding_screen.dart  # 新手引导
│   │   │   ├── privacy_center_screen.dart  # 隐私中心
│   │   │   ├── referral_screen.dart   # 裂变海报
│   │   │   └── youth_mode_screen.dart  # 青少年模式
│   │   ├── home/
│   │   │   └── home_tab.dart          # 首页看板
│   │   ├── office/
│   │   │   └── office_tab.dart        # 智慧办事
│   │   ├── profile/
│   │   │   └── profile_tab.dart       # 个人中心
│   │   └── teacher/                   # Module 10
│   │       ├── attendance_screen.dart  # 课堂考勤
│   │       ├── grade_entry_screen.dart  # 成绩录入
│   │       ├── permission_denied_screen.dart  # 403 页面
│   │       └── teacher_dashboard.dart  # 辅导员驾驶舱
│   ├── main_screen.dart               # 5 Tab 主容器
│   └── settings/
│       └── appearance_settings_screen.dart  # 外观设置
├── services/
│   └── supabase_service.dart          # Supabase 服务层
└── widgets/
    ├── ai_floating_button.dart        # AI 悬浮球 (Module 12)
    ├── app_background.dart            # 渐变背景
    ├── glass_card.dart                # 玻璃态卡片
    ├── splash_ad_widget.dart          # 开屏广告组件 (Module 13)
    └── ...                            # 其他通用 UI 组件
```

---

## 🚀 构建与运行

### 环境要求

- Flutter SDK ≥ 3.x
- Dart SDK ≥ 3.x
- Android Studio / VS Code

### 运行步骤

```bash
# 安装依赖
flutter pub get

# 运行应用（调试模式）
flutter run

# 构建 APK
flutter build apk --release
```

---

## 🤝 贡献

发现 bug、想加新功能、优化体验，或者单纯想打个招呼，都欢迎提交 Issue 或 Pull Request！

---

## 📄 开源协议

[MIT License](https://github.com/jiuxina/ushio-md/blob/main/LICENSE)

---

## 💡 致谢

本项目基于 **汐 (Ushio-MD)** 的 UI 框架进行开发，感谢原作者 [jiuxina](https://github.com/jiuxina) 提供的优秀基础架构。

校园应用 UI 架构设计参考：[CAMPUS_UI_MERMAID.md](CAMPUS_UI_MERMAID.md)

Made with ❤️ for 广西民族大学
