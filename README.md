# AI题库 🧠📚

> **"躯壳与电池"** —— AI题库本身只是一个空的躯壳，接入你自己的大模型 API Key 才能驱动使用。

一个**本地部署的 AI 智能出题与练习系统**。上传学习资料（PDF/Word/TXT），AI 基于资料内容自动生成选择题和填空题，逐题作答并查看解析，系统自动记录学习数据。

## ✨ 功能亮点

| 功能 | 说明 |
|------|------|
| 🔋 **API 配置** | 自由选择服务商（DeepSeek/OpenAI/SiliconFlow等），填入自己的 Key |
| 📤 **资料上传** | 支持 PDF / DOCX / TXT 格式，AI 自动提取文本 |
| 🤖 **AI 出题** | 基于资料内容生成选择题或填空题，带详细解析 |
| 🎯 **年龄段适配** | 出题时选择目标群体（小学/初中/高中/大学），AI 调整语言难度 |
| ✍️ **答题练习** | 逐题作答，提交后印章反馈 + 解析展示 |
| 📋 **练习历史** | 每次练习自动记录，按教材分组带序号 |
| 📕 **错题本** | 按教材分类整理错题，可针对性重练 |
| 📊 **学习统计** | 累计做题、正确率、练习次数等数据可视化 |
| 🎨 **趣味交互** | 印章反馈动画、连胜计数器、纸屑庆祝、环形统计图 |

## 🚀 快速开始

### 1. 启动后端
```bash
cd backend
pip install -r requirements.txt
python main.py
```
后端运行在 http://localhost:8000，API 文档 http://localhost:8000/docs

### 2. 打开前端
用浏览器打开 `web/index.html`

**默认账号**: `admin / 123456`

> ⚠️ 首次使用需先点右上角 🔋 填入你的 API Key

## 🔋 配置 API（装电池）

推荐服务商（免费/低价）：
- **DeepSeek**: `https://api.deepseek.com/v1` → `deepseek-chat`
- **SiliconFlow**: `https://api.siliconflow.cn/v1` → `Qwen/Qwen2.5-7B-Instruct`（有免费额度）
- **通义千问**: `https://dashscope.aliyuncs.com/compatible-mode/v1` → `qwen-turbo`

## 📁 项目结构

```
ai-question-bank/
├── backend/           # FastAPI 后端
│   ├── main.py        # 入口
│   ├── app/
│   │   ├── routers/   # API 路由
│   │   ├── services/  # AI + 文件解析
│   │   ├── models.py  # 数据库模型
│   │   └── ...
│   ├── requirements.txt
│   └── .env
├── web/               # 前端页面
│   ├── index.html     # 主页面
│   ├── 项目概况-给网页设计师.md
│   └── UI设计需求文档.md
└── README.md
```

## 📄 许可证

MIT
