# AI题库

<p align="center">
  <img src="web/assets/app-logo.png" width="108" alt="AI题库应用图标" />
</p>

AI题库是一套把课件、笔记、PDF、Word、TXT 等学习资料转成练习题的工具。上传资料后，AI 可以生成单选题、多选题、判断题、填空题、主观题和混合练习，并记录练习历史、错题与学习统计。

当前项目正在从“本地 FastAPI 网站”演进为：

- 静态官网：`aichuti.ccwu.cc` 首页不依赖后端，适合部署到 Cloudflare Pages。
- Android APK：优先公开测试，手机端本地保存资料、API Key、练习记录和错题本。
- 桌面端：继续内测，目标是启动桌面程序时自动拉起内置 FastAPI 后端。
- FastAPI 后端：保留现有 API，供开发模式、桌面端和旧版网页功能页使用。

## 快速入口

| 项目 | 地址 |
| --- | --- |
| 官网 | [https://aichuti.ccwu.cc](https://aichuti.ccwu.cc) |
| GitHub 仓库 | [Garyff1/ai-question-bank](https://github.com/Garyff1/ai-question-bank) |
| Android v1.0.3 APK | [下载 APK](https://github.com/Garyff1/ai-question-bank/releases/download/android-v1.0.3/ai-question-bank-android-v1.0.3.apk) |
| Android v1.0.3 Release | [查看 Release](https://github.com/Garyff1/ai-question-bank/releases/tag/android-v1.0.3) |
| 部署说明 | [DEPLOYMENT.md](DEPLOYMENT.md) |

Android v1.0.3 APK 校验值：

```text
SHA-256: 80DBED5CCE135F8E9CAB17D197DC3E7BADCE882A716D87454D07C4F29EA47533
```

> 不要把 APK 或桌面版 ZIP 放进 `web/` 目录。Cloudflare Pages 适合托管静态官网，安装包请放到 GitHub Releases、Cloudflare R2、OSS 等下载源。

## 目录结构

```text
ai-question-bank/
├─ backend/                 # FastAPI 后端
│  ├─ app/
│  ├─ main.py               # 支持 HOST / PORT / DATABASE_URL 环境变量
│  ├─ backend.spec          # PyInstaller 配置
│  └─ requirements.txt
├─ web/                     # 静态官网 + v1/v2 功能页
│  ├─ index.html            # 纯静态官网首页
│  ├─ assets/
│  ├─ v1-classic/
│  └─ v2-desktop/
├─ android-app/             # Android APK 项目
├─ src-tauri/               # Tauri 桌面壳
├─ scripts/
└─ artifacts/               # 本地产物目录，不参与 Pages 部署
```

## 三种运行方式

### 1. 开发模式：手动启动 FastAPI

适合调试 API 或本地网页功能页。

```powershell
cd H:\ai-question-bank\backend
pip install -r requirements.txt
python main.py
```

默认地址：

- 后端：`http://localhost:8000`
- 健康检查：`http://localhost:8000/health`
- API 文档：`http://localhost:8000/docs`
- 官网预览：`http://localhost:8000/web/`
- 桌面功能页：`http://localhost:8000/web/v2-desktop/index.html`

可用环境变量：

```powershell
$env:HOST = "127.0.0.1"
$env:PORT = "8000"
$env:DATABASE_URL = "sqlite:///./ai_question_bank.db"
$env:AIQB_DESKTOP_MODE = "0"
python main.py
```

桌面模式会关闭 reload：

```powershell
$env:AIQB_DESKTOP_MODE = "1"
$env:PORT = "18765"
python main.py
```

### 2. Android APK：当前优先公开测试

Android 版不需要注册/登录云端账号，也不需要手机外的电脑或服务器挂后端。资料、API Key、练习记录和错题本都保存在当前手机本地。

安装方式：

1. 在安卓手机或平板上下载 [ai-question-bank-android-v1.0.3.apk](https://github.com/Garyff1/ai-question-bank/releases/download/android-v1.0.3/ai-question-bank-android-v1.0.3.apk)。
2. 打开 APK 安装包。
3. 如果系统提示“禁止安装未知来源应用”，按系统提示允许当前浏览器或文件管理器安装。
4. 首次使用时配置自己的大模型 API Key。
5. 当前为早期测试版，建议保留原安装包，后续版本可能需要手动下载新 APK 覆盖安装。

构建 APK：

```powershell
cd H:\ai-question-bank\android-app
H:\DevTools\flutter\bin\flutter.bat build apk --release --no-shrink
```

产物路径：

```text
H:\ai-question-bank\android-app\build\app\outputs\flutter-apk\app-release.apk
```

### 3. 桌面版：内测中

桌面版目标是用 Tauri 包一层桌面壳，并把 FastAPI 后端打包成 `backend.exe` 作为 sidecar 自动启动。用户打开桌面程序后，不需要手动运行 `python main.py`，也不需要手动启动 cloudflared。

当前桌面版仍在内测优化中，暂不公开下载。重点仍需继续打磨：

- 内置后端启动稳定性。
- 关闭窗口时可靠结束后端进程。
- Windows 安全提示与杀毒误报。
- 安装包体积与下载分发。
- 自动更新体验。

构建后端 sidecar：

```powershell
cd H:\ai-question-bank
npm install
npm run backend:build
```

构建桌面包：

```powershell
npm run desktop:build
```

本地桌面产物会放到：

```text
artifacts/ai-question-bank-desktop-windows.zip
```

## 静态官网部署

`web/index.html` 是纯静态官网首页，首屏不请求 `/api`。所以后端关闭时，官网仍然可以访问。

Cloudflare Pages 推荐配置：

```text
Framework preset: None
Build command: 留空
Build output directory: web
Production branch: codex/update-ai-question-bank-ui 或 main
```

域名切换要点：

- `aichuti.ccwu.cc` 应绑定到 Cloudflare Pages Custom domains。
- 不要继续让 `aichuti.ccwu.cc` 指向 Cloudflare Tunnel。
- DNS 通常应由 Pages 自动添加 CNAME，或手动让 CNAME 指向对应的 `<project>.pages.dev`。

更详细步骤见 [DEPLOYMENT.md](DEPLOYMENT.md)。

## API 服务商接入

AI题库不内置模型服务。用户需要在应用里配置自己的 API Key、Base URL 和模型名。当前推荐把预设服务商统一为：

```text
DeepSeek、Qwen、智谱、小米 MiMo、Kimi、自定义
```

| 服务商 | 推荐 Base URL | 推荐模型 | 接入说明 | 官方文档 |
| --- | --- | --- | --- | --- |
| DeepSeek | `https://api.deepseek.com` | `deepseek-v4-flash` | OpenAI-compatible。官方已提示 `deepseek-chat` 和 `deepseek-reasoner` 会在 2026-07-24 之后弃用，后续优先使用 v4 系列。 | [DeepSeek API Docs](https://api-docs.deepseek.com/quick_start/pricing) |
| Qwen / 阿里百炼 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` | OpenAI-compatible。阿里云文档也提供 workspace 级 Endpoint，新项目可按控制台提示替换为自己的 workspace URL。 | [DashScope OpenAI 兼容说明](https://www.alibabacloud.com/help/en/model-studio/compatibility-of-openai-with-dashscope) |
| 智谱 / Z.ai | `https://api.z.ai/api/paas/v4` | `glm-4.5-flash` | OpenAI-compatible。旧的 BigModel 地址可继续作为兼容路径参考，新文档主推 Z.ai API。 | [Z.ai Chat Completion](https://docs.z.ai/api-reference/llm/chat-completion) |
| 小米 MiMo | `https://api.xiaomimimo.com/v1` | `MiMo-VL-7B-RL` | 接口路径兼容 `/chat/completions`，但鉴权 Header 使用 `api-key: <MIMO_API_KEY>`，不是普通的 `Authorization: Bearer`。 | [MiMo First API Call](https://mimo.mi.com/docs/en-US/quick-start/summary/first-api-call) |
| Kimi / Moonshot | `https://api.moonshot.ai/v1` | `kimi-k2.6` | OpenAI-compatible。Moonshot 平台新版域名为 `api.moonshot.ai`，旧资料中常见的 `api.moonshot.cn` 不再作为 README 的推荐入口。 | [Kimi API Overview](https://platform.kimi.ai/docs/api/overview) |
| 自定义 | 用户填写 | 用户填写 | 适合任何兼容 OpenAI Chat Completions 的第三方网关、本地模型服务或代理服务。 | - |

注意：

- 不同服务商的模型名、计费和上下文长度会变化，建议以官方控制台显示为准。
- 如果用户使用代理网关或第三方中转，请确认它是否完整兼容 `/chat/completions`。
- API Key 属于敏感信息，不要提交到仓库、Issue、截图或聊天记录里。

## Android 反馈与优化路线图

下面是当前真机测试反馈，后续 APK 版本优先按这张表推进：

| 优先级 | 问题 | 优化方案 |
| --- | --- | --- |
| P0 | 导入资料时软件会卡住，资料越大卡顿越久，严重时可能自动退出。 | 文件解析移动到后台 isolate/异步任务；增加导入进度、文件大小提示、错误兜底和内存保护；大文件分段读取，避免阻塞主线程。 |
| P1 | 错题本“清空”按钮容易误触。 | 清空前弹出二次确认，明确提示“此操作不可恢复”。 |
| P1 | 资料窗口里的删除按钮容易误触。 | 删除资料前弹出二次确认，并显示资料名称。 |
| P1 | 错题本没有“错题训练”入口。 | 增加“开始错题训练”按钮，按当前错题集合生成专项练习。 |
| P1 | 错题没有按资料划分，多个资料的错题混在一起。 | 增加“按资料收纳”的错题分组，每份资料维护独立错题集合，同时保留全部错题视图。 |
| P2 | API 配置成功后的变化不明显。 | 成功后显示动态电池充电动画；下方提供“更换其他接口”按钮，点击后回到当前配置界面。 |
| P2 | 底部导航切换缺少触觉反馈。 | 在底部 Tab 切换时加入轻量震动反馈，提升互动感。 |

## 前端 API_BASE 规则

功能页会按顺序读取 API 地址：

1. `window.AIQB_API_BASE`
2. URL 参数：`?api_base=http%3A%2F%2F127.0.0.1%3A18765`
3. `localStorage.AIQB_API_BASE`
4. 空字符串，也就是同源相对路径

因此：

- 开发模式通过 `http://localhost:8000/web/v2-desktop/index.html` 访问时，使用同源 API。
- 桌面模式由 Tauri 注入随机本地端口。
- 静态官网首页不在首屏请求 API。

## 主要 API

- `GET /health`：桌面壳健康检查。
- `GET /api/status`：API 状态。
- `POST /api/auth/register`：注册。
- `POST /api/auth/login`：登录。
- `GET /api/materials`：资料列表。
- `POST /api/materials/upload`：上传资料。
- `POST /api/questions/generate`：生成题目。
- `POST /api/practice/submit`：提交答案。
- `POST /api/practice/complete`：完成练习。
- `GET /api/stats`：学习统计。

## 开发检查

后端：

```powershell
cd H:\ai-question-bank\backend
python main.py
```

Android：

```powershell
cd H:\ai-question-bank\android-app
H:\DevTools\flutter\bin\flutter.bat analyze
H:\DevTools\flutter\bin\flutter.bat test
```

Cloudflare Pages 部署前：

```powershell
cd H:\ai-question-bank
git status
```

确认 `web/` 里没有 APK、ZIP、EXE 等大文件后，再在 Cloudflare Pages 里 Retry deployment。
