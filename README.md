# AI题库

<p align="center">
  <img src="web/assets/app-logo.png" width="108" alt="AI题库应用图标" />
</p>

AI题库是一套把课件、笔记、PDF、Word 等学习资料转成练习题的工具。上传资料后，AI 可以生成单选题、多选题、判断题、填空题、主观题和混合练习，并记录练习历史、错题与学习统计。当前 Android 版本支持富内容渲染（数学公式、函数图、统计图、物理图、化学结构、英语听力等）。

## 快速入口

| 项目 | 地址 |
| --- | --- |
| 官网 | [https://aichuti.ccwu.cc](https://aichuti.ccwu.cc) |
| GitHub 仓库 | [Garyff1/ai-question-bank](https://github.com/Garyff1/ai-question-bank) |
| **Android APK 下载（固定链接）** | [https://aichuti.ccwu.cc/download/android.apk](https://aichuti.ccwu.cc/download/android.apk) |
| 最新 Release | [查看所有 Release](https://github.com/Garyff1/ai-question-bank/releases) |
| 部署说明 | [DEPLOYMENT.md](DEPLOYMENT.md) |

> 固定下载链接 `https://aichuti.ccwu.cc/download/android.apk` 始终指向最新版本的 APK。Cloudflare CDN 缓存可能导致下载到旧版本，建议用无痕模式或清除浏览器缓存。

## 当前版本：v2.7.2

### 主要功能

- **资料导入**：支持 PDF、Word（.docx / .doc）；其他格式可使用「粘贴文本」导入
- **题型**：单选题、多选题、判断题、填空题、主观题，混合出题
- **富内容渲染（v2.5+）**：
  - 数学公式（LaTeX：`$...$` / `$$...$$`）
  - 函数图像（`[graph: f(x)=...]`）
  - 统计图（柱状/折线/饼图/直方图）
  - 物理示意图（受力、电路、光路等 8 种）
  - 化学结构（分子、Lewis、苯环等 7 种）
  - SVG 矢量图
  - 英语听力（在线 TTS 合成播放）
- **自动兜底（v2.6.3+）**：即使 AI 模型不返回 `rich_content`，App 也会根据题干内容自动检测数学符号、化学式、物理关键词等，生成基础富内容块，确保题目始终能显示图形
- **图表乱码修复（v2.7.0）**：化学只生成 smart_content_viewer 支持的 8 种分子，物理图按关键词选择合理的 diagram_type 与 params
- **图表过度生成收紧（v2.7.1 新增）**：化学删除"无明确分子式→默认 H2O"逻辑；物理图仅在题干含"如图/下图/示意图"等指示词时生成，避免图表文本与题干重复
- **音频题启用开关（v2.7.0）**：出题窗口与试卷出题面板均新增绿色"启用音频题（英语听力）"开关
- **听力题生成增强（v2.7.1 新增）**：prompt 从"建议"改为"**必须**"，新增 `_ensureListeningFallback` 兜底机制（英语资料自动改造第 1 题为听力题）
- **出题筛选**：题型多选、目标群体、题量 1-20、启用图表开关
- **试卷生成**：按中考/高考/期中/期末/周测模板生成，含题量模板与自定义
- **试卷按章节/知识点出题（v2.7.1 新增）**：PaperPage 新增章节范围、各题型知识点输入框，持久化到 SharedPreferences
- **试卷 PDF 图表呈现（v2.7.1 新增）**：PDF 生成添加 rich_content 文本描述（公式、函数图、统计图、物理图、化学结构、听力原文）
- **听力音频 mp3 下载（v2.7.1 新增）**：试卷列表与预览页新增"下载听力音频"按钮，单条保存为 .mp3，多条打包为 .zip
- **错题本**：按资料分组、30 天自动清理、批量删除、检索；错题卡片渲染 rich_content 图表
- **错题窗口切换卡顿优化（v2.7.1 新增）**：`_WrongQuestionCard` 加 `RepaintBoundary` 隔离重绘
- **练习历史**：详情页含动画饼图（正确率）和直方图（题型分布、知识点错误）
- **收纳折叠（v2.7.0）**：我的窗口历史记录折叠为最近 5 次，错题窗口折叠为最近 3 份资料×3 道题，试卷窗口折叠为最近 5 份资料
- **错题收纳标题横排修复（v2.7.1 新增）**：`_SectionHeader` 改为 Column 布局，标题不再竖排
- **开屏动画（v2.7.1 新增）**：渐变背景 + Logo 弹性缩放 + 标题滑入 + 副标题打字机效果
- **「我的」页面**：经验值、签到、清理菜单（批量删除/一键清空）、检索、关于 AI 题库介绍
- **多学科库**：smart_content_viewer、flutter_edge_tts、flutter_svg、audioplayers

### 版本历史

| 版本 | 主要内容 |
| --- | --- |
| v2.7.2 | 听力题生成增强（2道+完整段落）、错题窗口切换零延迟（IndexedStack）、试卷出题细化（每题知识点+解答题小问难度）、开屏动画最小展示2.5秒、听力音频mp3下载重写（中文引导+题号+3遍+下一题提示） |
| v2.7.1 | 错题收纳标题横排、听力题生成增强、图表过度生成收紧、错题窗口卡顿优化、试卷按章节/知识点出题、开屏动画、试卷 PDF 图表呈现、听力音频 mp3 下载 |
| v2.7.0 | 图表乱码修复、试卷出题加图表开关、音频题启用开关（出题+试卷）、错题窗口呈现图表、收纳折叠、关于介绍更新 |
| v2.6.3 | 彻底修复图表不显示：自动兜底检测、maxTokens 提升、超时延长、状态指示器优化 |
| v2.6.2 | 修复图表生成问题：默认开启、强制迁移偏好 key、添加可见状态指示器 |
| v2.6.0 | 出题筛选加启用图表开关、删除错题速览、清理功能升级、导入资料格式说明 |
| v2.5.0 | 多学科富内容渲染集成（rich_content.dart） |
| v2.4.0 | 错题 30 天清理、清理功能、检索、启动加载页 |
| v2.3.0 | 修复试卷出题 bug、激励动画页、自定义长按删除、默认题量模板 |

## 目录结构

```text
ai-question-bank/
├─ android-app/             # Flutter Android APK 项目（当前主力）
│  ├─ lib/
│  │  ├─ main.dart          # 应用主入口（业务逻辑、UI、AI Service）
│  │  └─ rich_content.dart  # 富内容渲染组件（7种类型块）
│  ├─ pubspec.yaml          # 版本号、依赖
│  └─ android/              # Gradle 配置（含阿里云镜像）
├─ web/                     # 静态官网
├─ backend/                 # FastAPI 后端（开发模式）
├─ src-tauri/               # Tauri 桌面壳（内测）
└─ artifacts/               # 本地产物目录
```

## Android 安装与构建

### 安装

1. 在安卓手机或平板上访问 [https://aichuti.ccwu.cc/download/android.apk](https://aichuti.ccwu.cc/download/android.apk)
2. 下载 APK 安装包
3. 如果系统提示"禁止安装未知来源应用"，按系统提示允许当前浏览器或文件管理器安装
4. 首次使用时配置自己的大模型 API Key
5. 建议保留原安装包，后续版本可手动下载新 APK 覆盖安装

### 构建 APK

```powershell
# 环境变量（如已迁移 .gradle 到 H:\DevCache）
$env:GRADLE_USER_HOME = 'H:\DevCache\.gradle'
$env:JAVA_TOOL_OPTIONS = '-Dhttps.protocols=TLSv1.2'
$env:PUB_CACHE = 'D:\DevCache\Pub'

cd android-app
flutter build apk --release
```

产物路径：

```text
android-app\build\app\outputs\flutter-apk\app-release.apk
```

### 发布新版本

```powershell
# 1. 升版本号（pubspec.yaml: version: X.Y.Z+N）
# 2. 构建 APK
# 3. 复制到 artifacts 并改名
Copy-Item 'android-app\build\app\outputs\flutter-apk\app-release.apk' `
  'artifacts\ai-question-bank-android-vX.Y.Z.apk' -Force

# 4. 创建 GitHub Release
gh release create android-vX.Y.Z `
  'artifacts\ai-question-bank-android-vX.Y.Z.apk' `
  --title "Android vX.Y.Z" `
  --notes-file 'artifacts\_release_notes.md' `
  --repo Garyff1/ai-question-bank

# 5. 上传到固定下载链接（Cloudflare Pages /functions/download）
# 固定链接 https://aichuti.ccwu.cc/download/android.apk 会指向新 Release 资源
```

## API 服务商接入

AI题库不内置模型服务。用户需要在应用里配置自己的 API Key、Base URL 和模型名。当前推荐预设服务商：

| 服务商 | 推荐 Base URL | 推荐模型 | 接入说明 |
| --- | --- | --- | --- |
| DeepSeek | `https://api.deepseek.com` | `deepseek-v4-flash` | OpenAI-compatible。官方已提示 `deepseek-chat` 和 `deepseek-reasoner` 会在 2026-07-24 后弃用 |
| Qwen / 阿里百炼 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` | OpenAI-compatible |
| 智谱 / Z.ai | `https://api.z.ai/api/paas/v4` | `glm-4.5-flash` | OpenAI-compatible |
| 小米 MiMo | `https://api.xiaomimimo.com/v1` | `MiMo-VL-7B-RL` | 鉴权 Header 使用 `api-key` |
| Kimi / Moonshot | `https://api.moonshot.ai/v1` | `kimi-k2.6` | OpenAI-compatible |
| 自定义 | 用户填写 | 用户填写 | 适合任何兼容 OpenAI Chat Completions 的网关 |

注意：

- 不同服务商的模型名、计费和上下文长度会变化，建议以官方控制台显示为准
- 部分小模型可能不支持复杂的 `rich_content` 字段输出，导致题目无图表。建议使用 `qwen-plus`、`deepseek-v4-flash`、`glm-4.5-flash` 等主流模型
- API Key 属于敏感信息，不要提交到仓库、Issue、截图或聊天记录里

## 富内容渲染（rich_content）

### 工作原理

1. AI 收到 prompt 时，根据题目需要返回 `rich_content` 数组
2. 每个元素形如 `{"type": "...", "data": {...}}`
3. App 端 `RichContentBlock` 组件根据 `type` 分发到对应渲染器

### 支持的 type

| type | 说明 | data 字段 |
| --- | --- | --- |
| `math` | 数学公式/函数图 | `content`：LaTeX 或 `[graph:]` 标签 |
| `chart` | 统计图 | `chart_type`、`data`、`title` |
| `physics` | 物理示意图 | `diagram_type`、`params` |
| `chemistry` | 化学结构 | `diagram_type`、`params` |
| `svg` | SVG 矢量图 | `svg` |
| `listening` | 英语听力 | `audio_text`、`voice`（可选） |

### 启用开关

出题筛选页第 03 步「设置练习参数」下方有蓝色卡片开关：

- **开启**（默认）：AI 会按需生成 rich_content
- **关闭**：纯文字题目模式，prompt 不要求 rich_content，生成更快

偏好持久化到 SharedPreferences（key: `enable_rich_v2`）。

### 自动兜底（v2.6.3 新增）

很多 AI 模型在严格 JSON 输出时会省略 `rich_content` 字段，导致题目无图。v2.6.3 起新增自动兜底机制：

- AI 未返回 `rich_content` 时，`AiQuestion.fromJson` 会调用 `_detectRichContentFallback(question, explanation)`
- 检测题干和解析内容中的：
  - 函数表达式（`f(x)=`、`y=`、`sin/cos/tan/log/ln`）→ 生成 math 函数图
  - 数学符号（`^`、`√`、`≈`、`≤`、`π`、`∑`、`∫`）或方程关键词 → 生成 math 公式
  - 化学式（`H2O`、`CO2`、`NaCl` 等元素+数字模式）→ 生成 chemistry 分子图
  - 物理关键词（力、速度、加速度、电路、电压、电流等）→ 生成 physics 图
  - 统计关键词（分布、占比、柱状、折线、饼图）→ 生成 chart 统计图

### 调试

- 题目卡片题干上方有状态指示器：绿色表示已返回/兜底生成 rich_content，橙色表示纯文字题
- `AiQuestion.fromJson` 添加了 `debugPrint`，运行时可在 logcat 过滤 `RichContent` 查看解析结果
- 若用户使用的 AI 模型支持复杂 JSON 输出（如 qwen-plus、deepseek-v4-flash、glm-4.5-flash），AI 会主动返回更精确的 rich_content

## 后端与桌面版

### 开发模式：手动启动 FastAPI

```powershell
cd backend
pip install -r requirements.txt
python main.py
```

默认地址：

- 后端：`http://localhost:8000`
- 健康检查：`http://localhost:8000/health`
- API 文档：`http://localhost:8000/docs`
- 官网预览：`http://localhost:8000/web/`

### 桌面版（内测中）

桌面版用 Tauri 包一层桌面壳，并把 FastAPI 后端打包成 `backend.exe` 作为 sidecar 自动启动。当前仍在内测优化中，暂不公开下载。

## 静态官网部署

`web/index.html` 是纯静态官网首页，首屏不请求 `/api`。后端关闭时官网仍可访问。

Cloudflare Pages 推荐配置：

```text
Framework preset: None
Build command: 留空
Build output directory: web
Production branch: main
```

更详细步骤见 [DEPLOYMENT.md](DEPLOYMENT.md)。

## 主要 API

后端 API（开发模式使用）：

- `GET /health`：健康检查
- `GET /api/status`：API 状态
- `POST /api/materials/upload`：上传资料
- `POST /api/questions/generate`：生成题目
- `POST /api/practice/submit`：提交答案
- `POST /api/practice/complete`：完成练习
- `GET /api/stats`：学习统计

## 开发检查

Android：

```powershell
cd android-app
flutter analyze
flutter test
```

Cloudflare Pages 部署前：

```powershell
git status
```

确认 `web/` 里没有 APK、ZIP、EXE 等大文件后，再在 Cloudflare Pages 里 Retry deployment。

## 反馈

发现问题或建议，请到 [GitHub Issues](https://github.com/Garyff1/ai-question-bank/issues) 反馈。
