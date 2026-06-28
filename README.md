# AI题库

AI题库把课件、笔记、PDF、Word 或 TXT 资料转换成可练习的题目，支持选择题、判断题、填空题、主观题和混合出题。

当前架构已经拆成两层：

- `web/`：纯静态官网与前端页面，可直接部署到静态托管平台。
- `backend/`：FastAPI API 服务，开发模式可单独运行，桌面版会被 Tauri 自动作为 sidecar 启动。

## 架构目标

1. 官网 `web/index.html` 不在首屏请求 `/api`，后端关闭时首页仍可访问。
2. 桌面版内置 `backend.exe`，启动桌面程序时自动启动 FastAPI 后端。
3. 桌面版动态分配本地端口，并通过 `API_BASE` 注入前端。
4. SQLite 数据库在桌面模式下写入用户数据目录，不写入安装目录。
5. 关闭桌面程序时自动关闭后端进程。

## 目录结构

```text
ai-question-bank/
├─ backend/                 # FastAPI 后端
│  ├─ app/
│  ├─ main.py               # 环境变量驱动的启动入口
│  ├─ backend.spec          # PyInstaller 配置
│  └─ requirements.txt
├─ web/                     # 静态官网 + v1/v2 功能页
│  ├─ index.html            # 静态官网首页
│  ├─ v1-classic/
│  ├─ v2-desktop/
│  ├─ assets/
│  └─ downloads/
├─ src-tauri/               # Tauri 桌面壳
├─ scripts/
│  └─ build-backend.ps1     # 构建 backend.exe 并复制为 Tauri sidecar
├─ android-app/             # Android App 项目
└─ package.json             # 桌面构建脚本
```

## 运行方式一：开发模式

适合改 API 或调试前端。

```powershell
cd H:\ai-question-bank\backend
pip install -r requirements.txt
python main.py
```

默认启动：

- 后端地址：`http://localhost:8000`
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

桌面模式下会自动关闭 reload：

```powershell
$env:AIQB_DESKTOP_MODE = "1"
$env:PORT = "18765"
python main.py
```

## 运行方式二：桌面版

桌面版使用 Tauri。用户打开程序后，不需要手动运行 `python main.py`，也不需要手动启动 cloudflared。

### 首次准备

Windows 本地构建需要：

- Python 3.11+
- Node.js 20+
- Rust / Cargo
- Microsoft Edge WebView2 Runtime

安装 Python 依赖：

```powershell
cd H:\ai-question-bank\backend
pip install -r requirements.txt
```

回到项目根目录安装 Tauri CLI：

```powershell
cd H:\ai-question-bank
npm install
```

### 构建 backend.exe

```powershell
cd H:\ai-question-bank
npm run backend:build
```

这个脚本会：

1. 使用 PyInstaller 构建 `backend\dist\backend.exe`。
2. 复制成 Tauri sidecar 需要的文件名。默认 Windows GNU 构建会生成：

```text
src-tauri\binaries\backend-x86_64-pc-windows-gnu.exe
```

### 构建桌面版 zip 包

```powershell
cd H:\ai-question-bank
npm run desktop:build
```

当前脚本会使用 `x86_64-pc-windows-gnu` 目标构建 Tauri，这样在没有管理员权限安装 Visual Studio C++ Build Tools 的机器上也可以完成构建。构建成功后会生成：

```text
web/downloads/ai-question-bank-desktop-windows.zip
```

如果你已经安装了 Visual Studio C++ Build Tools，也可以自行改用 MSVC target。MSI 安装包属于可选项：

```powershell
npm run desktop:bundle:msi
```

桌面程序启动流程：

1. Tauri 随机分配一个 `127.0.0.1` 本地端口。
2. 作为 sidecar 启动 `backend.exe`。
3. 设置 `HOST`、`PORT`、`AIQB_DESKTOP_DATABASE_URL`、`AIQB_DESKTOP_MODE=1`。
4. 轮询 `/health`，确认后端可用。
5. 打开 `web/v2-desktop/index.html`，并注入 `api_base`。
6. 用户关闭窗口时自动关闭后端进程。

## 运行方式三：官网静态部署

`web/index.html` 是纯静态官网首页，不依赖 FastAPI。可以部署到 Cloudflare Pages、GitHub Pages、Netlify、Vercel 或任意静态服务器。

静态官网只负责：

- 展示产品介绍。
- 提供“下载桌面版”入口。
- 提供“查看 GitHub”入口。
- 提供“观看演示”入口。

注意：官网里的 `v1-classic` 和 `v2-desktop` 功能页仍然需要后端 API。正式用户建议下载桌面版使用，因为桌面版会自动启动内置后端。

## API_BASE 规则

前端功能页会按顺序读取 API 地址：

1. `window.AIQB_API_BASE`
2. URL 参数：`?api_base=http%3A%2F%2F127.0.0.1%3A18765`
3. `localStorage.AIQB_API_BASE`
4. 空字符串，也就是同源相对路径

因此：

- 开发模式通过 `http://localhost:8000/web/v2-desktop/index.html` 访问时，使用同源 API。
- 桌面模式由 Tauri 注入随机端口。
- 静态官网不会在首页请求 API。

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

## GitHub 与发布

项目地址：

[https://github.com/Garyff1/ai-question-bank](https://github.com/Garyff1/ai-question-bank)

静态官网发布时，将 `web/` 目录作为站点根目录即可。桌面安装包构建完成后，可放入：

```text
web/downloads/ai-question-bank-desktop-windows.zip
```

这样官网的“下载桌面版”按钮就能直接下载最新桌面版本。
