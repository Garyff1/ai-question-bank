<p align="center">
  <img src="https://img.shields.io/badge/状态-活跃-brightgreen" alt="状态">
  <img src="https://img.shields.io/badge/后端-FastAPI-2563EB" alt="后端">
  <img src="https://img.shields.io/badge/前端-多版本-10B981" alt="前端">
  <img src="https://img.shields.io/badge/许可证-MIT-F59E0B" alt="许可证">
</p>

<h1 align="center">🧠 AI题库</h1>
<p align="center"><b>"躯壳与电池"</b> —— 软件是躯壳，接入你的 API Key 才是电池</p>
<p align="center">上传资料 → AI 自动出题 → 答题练习 → 错题巩固</p>

<p align="center">
  <img src="screenshot.png" alt="答题界面截图" width="280">
</p>

---

## 📦 快速上手（5 分钟跑起来）

本项目分两部分：**后端**（Python，处理数据和 AI 调用）和**前端**（网页，你看到的界面）。先启动后端，再用浏览器打开前端。

---

### 🔧 步骤一：启动后端

> 前提：电脑已安装 Python 3.11 或更高版本。如果没装过，去 [python.org](https://www.python.org/downloads/) 下载安装。

打开一个终端（PowerShell 或 CMD），依次执行：

```powershell
# 1. 下载项目
git clone https://github.com/Garyff1/ai-question-bank.git
cd ai-question-bank

# 2. 进入后端目录，安装依赖
cd backend
pip install -r requirements.txt

# 3. 启动后端
python main.py
```

看到以下输出表示启动成功：

```
INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
INFO:     Application startup complete.
```

---

### 💻 步骤二：电脑端打开前端

在后端启动状态下，浏览器打开：

```
http://localhost:8000/web/
```

> ⚠️ **不要**直接双击 `web/index.html` 文件打开——那样会以 `file://` 协议打开，跨域请求后端会被浏览器拦截。一定要通过 `http://localhost:8000/web/` 访问。

你会看到一个**前端选择器**页面。点击「经典版」卡片进入完整功能。

---

### 📱 步骤三：手机上使用（可选）

让手机和电脑连同一个 WiFi，手机浏览器打开：

```
http://你的电脑IP:8000/web/
```

**如何查看电脑 IP？**
1. Windows 按 `Win + R`，输入 `cmd`，回车
2. 在命令行输入 `ipconfig`，回车
3. 找到 `无线局域网适配器 WLAN` 下的 `IPv4 地址`（一般是 `192.168.x.xxx`）

例如电脑 IP 是 `192.168.1.105`，手机浏览器打开：

```
http://192.168.1.105:8000/web/
```

---

### 🚪 首次使用流程

```
打开 http://localhost:8000/web/
    │
    ├── 点击「经典版」进入
    │
    ├── 登录页 → 点击「注册」→ 填任意账号密码 → 注册成功
    │       或者用现有账号 → 点击「登录」
    │
    ├── 进入主页 → 看到空空的资料列表
    │
    ├── 🔋 先装电池！点右上角电池按钮 → 配置 API Key（见下方说明）
    │
    ├── 配置好 Key 后 → 点右上角 ＋ 按钮上传 PDF/DOCX/TXT
    │
    ├── 上传成功 → 资料卡片出现 → 点「出题」按钮
    │
    └── 选题型、选年龄段、选数量 → 点「生成题目」→ 开始答题！
```

---

## 🔋 API Key 配置详解（装电池）

AI 出题功能依赖大模型接口，需要你自己去服务商注册并获取 API Key。本项目就是一个"躯壳"，不内置任何 Key。

### 在软件内配置

登录后主页右上角有一个 **🔋 电池按钮**，点击进入配置页：

1. **选择服务商** — 点击对应卡片（如 DeepSeek）
2. **填写 API Key** — 从服务商官网获取的密钥，格式如 `sk-xxxxxxxxxx`
3. **API Base URL** — 选择服务商后自动填入，一般不需修改
4. **模型名称** — 自动填入，也可以手动改
5. **点击"测试连接"** — 验证 Key 是否可用
6. **点击"保存"** — 配置完成

> 🔒 每个账号的 API Key 独立存储，退出登录时自动清除。

### 推荐服务商（2025 年最新）

| 服务商 | 特点 | 注册 + 获取 Key | API Base URL | 模型名 |
|--------|------|:--:|-------------|--------|
| **DeepSeek** 🏆 | 国内可用，价格最低 | [platform.deepseek.com](https://platform.deepseek.com) 注册 → API Keys → 创建 | `https://api.deepseek.com/v1` | `deepseek-chat` |
| **硅基流动** 🆓 | 新用户有免费额度 | [siliconflow.cn](https://siliconflow.cn) 注册 → API 密钥 | `https://api.siliconflow.cn/v1` | `Qwen/Qwen3-8B` |
| **阿里百炼** | 阿里云生态 | [bailian.console.aliyun.com](https://bailian.console.aliyun.com) → 模型广场 → API Key | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` |
| **智谱开放平台** | GLM 系列模型 | [open.bigmodel.cn](https://open.bigmodel.cn) → API Keys | `https://open.bigmodel.cn/api/paas/v4` | `glm-4-flash` |

> 所有服务商均兼容 OpenAI 接口格式，本项目直接支持。只需 Key + URL + 模型名即可使用，无需额外适配。

### 排查 API 配置问题

| 现象 | 可能原因 | 解决 |
|------|----------|------|
| 测试连接失败 "401" | Key 填错或过期 | 去服务商后台重新生成 Key |
| 测试连接失败 "404" | URL 填错 | 核对上表中的 API Base URL，末尾不要多斜杠 |
| 测试连接成功但出题失败 | 模型名不对 | 核对模型名，不同服务商模型名不同 |
| 一直显示 "请先配置 API Key" | 未保存 | 测试连接成功后别忘了点"💾 保存" |

---

## ✨ 功能总览

| 功能 | 说明 |
|------|------|
| 🔋 **API 配置** | 内置 6 个服务商模板，填入 Key 即用，退出自动清除 |
| 📤 **资料上传** | 支持 PDF / DOCX / TXT（≤ 50MB），自动解析文本 |
| 🤖 **AI 出题** | 5 种题型：单选 · 多选 · 判断 · 填空 · 主观 |
| 🎯 **混合出题** | 一次选多个题型（如判断+填空），混合出题 |
| 🔄 **自动去重** | 每次出题自动避开已出过的题目 |
| ✍️ **答题练习** | 逐题作答 → ✅ / ❌ 印章反馈 → 解析展示 |
| 🔥 **连胜计数** | 连续答对火苗递增，答错归零 |
| 📋 **练习历史** | 自动记录，按"教材名 #序号"命名 |
| 📕 **错题本** | 按教材分组整理错题，点击「重练」专项训练 |
| 📊 **学习统计** | 累计做题、正确率环形图、练习次数 |
| 👶 **年龄段适配** | 可选小学到大学，AI 自动调整用词难度 |

---

## 🎨 多前端版本

所有前端**共用同一个后端 API**，启动后端后在浏览器挑版本即可。

### 当前可用

| 版本 | 目录 | 特点 |
|:----|------|------|
| 📱 **v1 · 经典版** | `web/v1-classic/` | 移动优先、全功能、印章动画、连胜、纸屑庆祝 |

### 开发中

| 版本 | 特点 | 状态 |
|:----|------|:----:|
| 🖥️ v2 · 桌面版 | PC 大屏优化、多栏布局、键盘快捷键 | 🚧 |
| 🎨 v3 · 极简版 | 轻量级、仅核心功能 | 🚧 |

> 💡 想贡献新前端？在 `web/` 下新建文件夹，写你的 `index.html`，然后编辑 `web/index.html` 加卡片入口即可。

---

## 📁 项目结构

```
ai-question-bank/
├── backend/                 # FastAPI 后端
│   ├── main.py              # 启动入口
│   ├── requirements.txt     # Python 依赖
│   ├── .env                 # 环境变量（后端全局配置）
│   ├── test_data.txt        # 测试用文本资料
│   └── app/
│       ├── app.py           # FastAPI 应用配置 + 静态文件托管
│       ├── config.py        # 参数管理（文件大小限制等）
│       ├── database.py      # SQLite 数据库连接
│       ├── models.py        # 数据库表模型
│       ├── routers/         # API 路由
│       │   ├── api_config.py   # POST /api/config/*   API Key 配置
│       │   ├── auth.py         # POST /api/auth/*     注册/登录
│       │   ├── materials.py    # POST /api/materials/*  资料上传
│       │   ├── questions.py    # POST /api/questions/*   AI 出题
│       │   ├── practice.py     # POST /api/practice/*   答题/错题
│       │   └── stats.py        # GET  /api/stats       学习统计
│       ├── services/        # 业务逻辑
│       │   ├── ai_service.py    # 调用大模型生成题目
│       │   └── file_service.py  # PDF/DOCX/TXT 文件解析
│       └── utils/
│           └── auth.py         # JWT Token + 密码加密
│
├── web/                     # 多前端集合
│   ├── index.html           # 前端选择器 ← 程序入口
│   ├── v1-classic/          # 经典版（全功能）
│   │   └── index.html
│   ├── 项目概况-给网页设计师.md
│   └── UI设计优化方案-趣味化升级.md
│
├── screenshot.png           # README 截图
└── README.md
```

---

## 🧪 后端 API 接口文档

启动后端后，访问 **http://localhost:8000/docs** 查看 Swagger 交互文档（可直接在网页上调用测试）。

### 认证

| 方法 | 路径 | 请求参数 | 说明 |
|------|------|----------|------|
| POST | `/api/auth/register` | `{"email":"...","password":"..."}` | 注册账号，返回 JWT Token |
| POST | `/api/auth/login` | `{"email":"...","password":"..."}` | 登录，返回 JWT Token |
| GET | `/api/auth/me` | Header: `Authorization: Bearer <token>` | 获取当前用户信息 |

### 资料管理

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/materials/upload` | 上传文件（multipart/form-data，字段名 `file`） |
| GET | `/api/materials` | 资料列表 |
| DELETE | `/api/materials/{id}` | 删除资料及关联题库 |

### AI 出题

| 方法 | 路径 | 请求参数 | 说明 |
|------|------|----------|------|
| POST | `/api/questions/generate` | `{"material_id":1, "question_type":"choice,fill", "question_count":5, "target_audience":"初中"}` | 生成题目。`question_type` 支持逗号分隔混合题型 |

**支持的题型**：`choice`（单选）、`multi_choice`（多选）、`true_false`（判断）、`fill`（填空）、`subjective`（主观）

### 答题练习

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/practice/submit` | 提交单题答案，返回对错 + 解析 |
| POST | `/api/practice/complete` | 完成一轮练习，保存历史记录 |
| GET | `/api/practice/history` | 练习历史（带教材名和序号） |
| GET | `/api/practice/wrong` | 错题本（按教材分组） |

### 统计与配置

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/stats` | 累计题数、正确率、练习次数 |
| POST | `/api/config/config` | 保存 API Key 配置 |
| POST | `/api/config/test` | 测试 API Key 连通性 |

---

## ❓ 常见问题

### 打开 http://localhost:8000/web/ 白屏或报错？

确认后端已启动（终端看到 `Uvicorn running on http://0.0.0.0:8000`）。如果端口被占用，编辑 `backend/main.py` 改端口。

### 手机连不上？

- 手机和电脑必须在**同一 WiFi**
- 检查电脑防火墙是否拦截了 8000 端口（临时关防火墙试试）
- 在手机浏览器先试 `http://电脑IP:8000`，看到 JSON 就说明网络通了

### 上传文件失败？

- 支持 PDF / DOCX / TXT，文件 ≤ 50MB
- 如果 PDF 解析乱码，可能是扫描版 PDF，建议先用 OCR 工具转文字

### 出题一直失败？

- 先到 API 配置页点「测试连接」确认 Key 可用
- 检查服务商账户余额是否充足
- 如果资料文本太短（< 100 字），AI 出题质量会下降

---

## 📄 许可证

MIT



---

## 📱 Android 单体版本（v2.9.8）

除上述 Web 后端版本外，本项目还提供一个 **Android 单体 App**——无需后端、无需登录，直接安装即用，所有 API Key 与资料均存在本地。

### 使用场景

- 想在手机上离线使用，不想搭后端
- 不愿注册账号，希望本地保存
- 给孩子/学生安装一个独立 App，避免误操作后端配置

### 下载与安装

直接下载 APK 安装包：

👉 **https://aichuti.ccwu.cc/download/android.apk**

> 链接固定不变，每次发布新版都会自动指向最新版。如浏览器缓存了旧版，请用无痕模式打开。

### 主要功能

- 多学科 AI 出题（数学/语文/英语/物理/化学等）
- 5 种题型：单选、多选、判断、填空、主观
- 富内容渲染：函数图、统计图、化学分子结构、物理示意图、英语听力 TTS
- 试卷生成（PDF 输出，含图表绘制）
- 错题本 + 知识点错误率 Top5
- 练习历史 + 本周练习趋势图
- 多种 API 服务商支持（DeepSeek、硅基、阿里、智谱等）

### 与 Web 版本的区别

| 维度 | Android 单体版 | Web 后端版 |
|------|----------------|------------|
| 部署 | 安装即用 | 需启动 Python 后端 |
| 数据存储 | 完全本地 | 后端 SQLite |
| 多用户 | 单用户 | 多用户登录 |
| 适合人群 | 个人/学生 | 团队/班级 |

### 当前版本

- **版本号**：v2.9.8+49
- **主要更新**：修复闯关宝箱动画越界和结算路由竞态导致的闪退；闯关不再混入听力小游戏；图表题与听力题统一控制在约 25%；错题抽卡在窄屏上保持居中；PDF 支持多种图表数据结构并避免输出 LaTeX 原始代码。
- **历史 Release**：https://github.com/Garyff1/ai-question-bank/releases

---

## 🛠️ GitHub 基础操作（给非程序员）

如果你不熟悉 Git/GitHub，下面是几个常用操作的速查。

### 1. 下载项目源码

```powershell
# 第一次下载
git clone https://github.com/Garyff1/ai-question-bank.git
cd ai-question-bank
```

### 2. 更新到最新版

```powershell
git pull
```

### 3. 查看当前版本

```powershell
git log -1 --oneline
```

### 4. 切换到某个历史版本

```powershell
# 查看所有历史
git log --oneline

# 切换到某个 commit
git checkout <commit-hash>
```

### 5. 下载某个 Release 的 APK

直接浏览器打开：

```
https://github.com/Garyff1/ai-question-bank/releases
```

找到对应版本，点击 `app-release.apk` 下载即可。

### 6. 提交问题反馈

如果发现 bug 或有功能建议：

1. 打开 https://github.com/Garyff1/ai-question-bank/issues
2. 点击 `New issue`
3. 描述清楚：使用版本、操作步骤、期望结果、实际结果

---

## 📄 许可证

MIT
