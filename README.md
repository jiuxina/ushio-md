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

---

## 📊 实现进度

### 已完成 ✅

- [x] 完整的登录/认证流程，集成 Supabase Auth
- [x] 5 Tab 主导航结构（首页 / 学业 / 办事 / 社区 / 我的）
- [x] 所有 Tab 页面完整 UI 实现
- [x] Supabase 服务层，支持维护模式检测
- [x] 8 个数据模型（CampusUser、Course、Grade、LeaveRequest、Announcement、Venue、VenueBooking、CommunityPost）
- [x] Auth Provider —— 会话管理与登录状态维持
- [x] Campus Data Provider —— 统一数据获取与错误处理
- [x] 维护模式提示 —— Supabase 未配置时自动降级展示
- [x] 主题系统（5 套浅色 + 6 套深色主题方案，12 种强调色）

### 待开发 ⬜

- [ ] 推送通知
- [ ] 附件文件上传
- [ ] 实时数据订阅（Supabase Realtime）
- [ ] 离线缓存

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
│   ├── campus_user.dart               # 校园用户模型
│   ├── community_post.dart            # 社区帖子模型
│   ├── course.dart                    # 课程模型
│   ├── grade.dart                     # 成绩模型
│   ├── leave_request.dart             # 请假申请模型
│   ├── venue.dart                     # 场馆模型
│   └── venue_booking.dart             # 场馆预约模型
├── providers/
│   ├── auth_provider.dart             # 认证状态管理
│   ├── campus_provider.dart           # 校园数据状态管理
│   └── settings_provider.dart         # 设置状态管理
├── screens/
│   ├── auth/
│   │   └── login_screen.dart          # 登录页
│   └── campus/
│       ├── academic/
│       │   └── academic_tab.dart      # 学业中心
│       ├── community/
│       │   └── community_tab.dart     # 社区与场馆
│       ├── home/
│       │   └── home_tab.dart          # 首页看板
│       ├── office/
│       │   └── office_tab.dart        # 智慧办事
│       └── profile/
│           └── profile_tab.dart       # 个人中心
├── services/
│   └── supabase_service.dart          # Supabase 服务层
└── widgets/
    └── ...                            # 通用 UI 组件
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
