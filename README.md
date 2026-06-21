<p align="center">
  <img src="https://img.shields.io/badge/状态-活跃-brightgreen" alt="状态">
  <img src="https://img.shields.io/badge/后端-FastAPI-2563EB" alt="后端">
  <img src="https://img.shields.io/badge/前端-多版本-10B981" alt="前端">
  <img src="https://img.shields.io/badge/许可证-MIT-F59E0B" alt="许可证">
</p>

<h1 align="center">🧠 AI题库</h1>
<p align="center"><b>"躯壳与电池"</b> —— 接入你自己的 API Key 才能驱动使用</p>
<p align="center">上传资料 → AI 自动出题 → 答题练习 → 错题巩固</p>

<p align="center">
  <img src="screenshot.png" alt="答题界面截图" width="280">
</p>

---

## 📦 快速上手

**第一步**：启动后端
```bash
git clone https://github.com/Garyff1/ai-question-bank.git
cd ai-question-bank/backend
pip install -r requirements.txt
python main.py
```

**第二步**：打开前端

| 使用场景 | 方式 |
|----------|------|
| 💻 **本机使用** | 浏览器打开 `web/index.html` 挑选前端版本 |
| 📱 **手机使用** | 手机和电脑**同一 WiFi** → 手机浏览器访问 `http://电脑IP:8000/web/` |

> ⏳ 后端启动后访问 http://localhost:8000 可确认运行状态
>
> 📱 第一次使用需先注册账号，然后点右上角 🔋 配置你的 API Key
>
> 💡 查看电脑 IP：Windows 按 `Win+R` → 输入 `cmd` → 输入 `ipconfig` → 找 IPv4 地址（如 `192.168.1.105`）
>
> 📱 手机浏览器访问：`http://192.168.1.105:8000/web/`

---

## 🎨 多前端版本

所有前端**共用同一个后端 API**，启动后端后任选一个即可使用。

```
web/                         ← 浏览器打开这个入口
├── index.html               ← 🚪 前端选择器（推荐从这里进入）
└── v1-classic/              ← 📱 经典版（当前的主力版本）
    └── index.html           ← 也可以直接打开
```

### 当前版本

|  | 版本 | 特点 | 打开方式 |
|:-:|:----|:-----|:---------|
| 📱 | **v1 · 经典版** | 移动优先、5种题型、混合出题、错题重练、学习统计、API配置、印章动画、连胜🔥、纸屑🎉 | `web/index.html` → 点卡片 |

### 计划中

| 版本 | 特点 | 状态 |
|:----|:-----|:----:|
| 🖥️ v2 · 桌面版 | PC 大屏优化、多栏布局、键盘快捷键 | 🚧 开发中 |
| 🎨 v3 · 极简版 | 轻量级、仅核心功能、低配友好 | 🚧 开发中 |

> 💡 想贡献新前端？在 `web/` 下新建文件夹，写你的 `index.html`，然后更新 `web/index.html` 加一张卡片即可。

---

## ✨ 功能总览

| 功能 | 说明 |
|------|------|
| 🔋 **API 配置** | 内置6个服务商模板，填入 Key 即用，退出自动清除 |
| 📤 **资料上传** | 支持 PDF / DOCX / TXT（≤50MB），自动解析文本 |
| 🤖 **AI 出题** | 5种题型：单选 · 多选 · 判断 · 填空 · 主观 |
| 🎯 **混合出题** | 一次选多个题型混合出题，并行调用 AI |
| 🔄 **自动去重** | 每次出题自动避开该教材已出过的题目 |
| ✍️ **答题练习** | 逐题作答 → 印章反馈 → 解析展示 |
| 🔥 **连胜计数** | 连续答对火苗递增，答错归零 |
| 📋 **练习历史** | 自动记录，按教材 + 序号命名 |
| 📕 **错题本** | 按教材分组，支持重练 |
| 📊 **学习统计** | 环形图 + 数字滚动递增 |
| 👶 **年龄段适配** | 小学→高中→大学，AI 自动调整难度 |

---

## 🔋 配置 API（装电池）

第一次使用需要配置 API Key，就像玩具需要装电池一样：

```
web/v1-classic/index.html   →   登录   →   点右上角 🔋   →   选服务商   →   填 Key   →   测试连接   →   保存
```

| 推荐服务商 | 注册地址 | API Base URL | 模型 |
|-----------|---------|-------------|------|
| **DeepSeek** 🏆 | [platform.deepseek.com](https://platform.deepseek.com) | `https://api.deepseek.com/v1` | `deepseek-chat` |
| **SiliconFlow** 🆓 | [cloud.siliconflow.cn](https://cloud.siliconflow.cn) | `https://api.siliconflow.cn/v1` | `Qwen/Qwen2.5-7B-Instruct` |
| **通义千问** | [阿里云模型服务](https://help.aliyun.com/zh/model-studio) | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-turbo` |
| **OpenAI** | [platform.openai.com](https://platform.openai.com) | `https://api.openai.com/v1` | `gpt-3.5-turbo` |

---

## 📁 项目结构

```
ai-question-bank/
├── backend/               # FastAPI 后端（通用）
│   ├── main.py
│   ├── app/
│   │   ├── routers/       # 认证 · 资料 · 出题 · 答题 · 统计 · 配置
│   │   ├── services/      # AI 调用 · 文件解析
│   │   ├── models.py      # 数据库模型
│   │   ├── config.py      # 配置管理
│   │   └── database.py    # 数据库连接
│   └── requirements.txt
│
├── web/                   # 🎯 多前端集合
│   ├── index.html         # 🚪 入口：选择器页面
│   ├── v1-classic/        # 📱 经典版（完整功能）
│   │   └── index.html
│   ├── 项目概况-给网页设计师.md
│   └── UI设计优化方案-趣味化升级.md
│
└── README.md
```

---

## 🧪 后端 API 一览

| 方法 | 路径 | 说明 |
|------|------|------|
| POST | `/api/auth/register` | 注册 |
| POST | `/api/auth/login` | 登录 |
| POST | `/api/materials/upload` | 上传资料 |
| GET | `/api/materials` | 资料列表 |
| POST | `/api/questions/generate` | AI 出题（支持混合题型 `"choice,fill"`） |
| POST | `/api/practice/submit` | 提交答案 |
| POST | `/api/practice/complete` | 完成练习 |
| GET | `/api/practice/history` | 练习历史 |
| GET | `/api/practice/wrong` | 错题本 |
| GET | `/api/stats` | 学习统计 |
| POST | `/api/config/config` | 保存 API 配置 |
| POST | `/api/config/test` | 测试 API 连接 |

API 文档（启动后端后）：http://localhost:8000/docs

---

## 📄 许可证

MIT
