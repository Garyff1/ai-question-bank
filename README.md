# AI题库 🧠📚

> **"躯壳与电池"** —— AI题库本身只是一个空的躯壳，接入你自己的大模型 API Key 才能驱动使用。

一个**本地部署的 AI 智能出题与练习系统**。上传学习资料（PDF/Word/TXT），AI 基于资料内容自动生成选择题和填空题，逐题作答并查看解析，系统自动记录学习数据。

## ✨ 功能亮点

| 功能 | 说明 |
|------|------|
| 🔋 **API 配置** | 自由选择服务商（DeepSeek/OpenAI/SiliconFlow等），填入自己的 Key |
| 📤 **资料上传** | 支持 PDF / DOCX / TXT 格式（≤50MB），AI 自动提取文本 |
| 🤖 **AI 出题** | 5种题型：单选/多选/判断/填空/主观，支持混合出题，自动去重 |
| 🎯 **年龄段适配** | 出题时选择目标群体（小学/初中/高中/大学），AI 调整语言难度 |
| ✍️ **答题练习** | 逐题作答，提交后印章反馈 + 解析展示，🔥连胜计数器 |
| 📋 **练习历史** | 每次练习自动记录，按教材分组带序号 |
| 📕 **错题本** | 按教材分类整理错题，可针对性重练 |
| 📊 **学习统计** | 累计做题、正确率、练习次数等数据可视化 |
| 🎨 **趣味交互** | 印章反馈动画、纸屑庆祝、环形分数图 |

## 🚀 快速开始

### 1. 启动后端
```bash
cd backend
pip install -r requirements.txt
python main.py
```
后端运行在 http://localhost:8000，API 文档 http://localhost:8000/docs

### 2. 选择前端打开
用浏览器打开 `web/index.html`，**挑选你喜欢的前端版本**。

**默认账号**: `admin / 123456`

> ⚠️ 首次使用需先点右上角 🔋 填入你的 API Key

## 🔋 配置 API（装电池）

| 服务商 | API Base URL | 模型 |
|--------|-------------|------|
| DeepSeek | `https://api.deepseek.com/v1` | `deepseek-chat` |
| SiliconFlow | `https://api.siliconflow.cn/v1` | `Qwen/Qwen2.5-7B-Instruct` |
| 通义千问 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-turbo` |
| OpenAI | `https://api.openai.com/v1` | `gpt-3.5-turbo` |

## 🎨 多前端选择

本项目提供多个前端版本，可根据喜好选择使用：

```
web/
├── index.html               ← 前端选择器（从这里进入）
├── v1-classic/              ← 📱 经典版（移动优先，全功能）
│   └── index.html
├── 项目概况-给网页设计师.md   ← 📐 产品设计文档
└── UI设计优化方案-趣味化升级.md ← 🎨 趣味化设计规范
```

| 版本 | 特点 | 状态 |
|:----|:-----|:----:|
| **v1 · 经典版** | 移动优先，5种题型，混合出题，错题重练，学习统计 | ✅ 可用 |
| v2 · 桌面版 | PC 大屏优化，多栏布局，快捷键操作 | 🚧 开发中 |
| v3 · 极简版 | 轻量级，仅核心功能 | 🚧 开发中 |

所有前端共用同一个后端 API。

## 📁 项目结构

```
ai-question-bank/
├── backend/           # FastAPI 后端
│   ├── main.py        # 入口
│   ├── app/
│   │   ├── routers/   # API 路由（认证/资料/出题/答题/统计/配置）
│   │   ├── services/  # AI 调用 + 文件解析
│   │   ├── models.py  # 数据库模型
│   │   ├── config.py  # 配置管理
│   │   └── database.py
│   ├── requirements.txt
│   └── .env
├── web/               # 多前端集合
│   ├── index.html     # 前端选择器
│   ├── v1-classic/    # 经典版前端
│   │   └── index.html
│   └── *.md           # 设计文档
└── README.md
```

## 🛠️ 想贡献新前端？

欢迎提交新的前端版本！只需：

1. 在 `web/` 下创建新文件夹（如 `v2-desktop/`）
2. 确保所有 API 调用与后端兼容
3. 更新 `web/index.html` 添加卡片入口

## 📄 许可证

MIT
