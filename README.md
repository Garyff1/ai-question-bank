# AI题库

AI题库是一款 **Local-first、BYOK（Bring Your Own Key）** 的 AI 学习与智能组卷工具。它把教材、课件、笔记或扫描资料转化为练习、错题巩固、闯关挑战和可打印试卷。

> “软件是躯壳，用户自己的 API Key 是电池。”

## 当前产品路线

- Android 端只保留用户自己的 API Key 模式。
- API Key 使用 Android Keystore 对应的安全存储保存在本机。
- Android 端直接请求用户选择的第三方模型服务商。
- AI题库不托管用户 Key、不出售 Token、不提供模型充值，也不代收模型调用费用。
- 资料、错题、练习记录、XP 与本机 API 调用记录默认保存在设备本地。
- 旧“官方 AI、报价、订单、支付与退款”方案自 RC005 起停止开发，仅保留在 Git 历史和已标记废弃的历史文档中。

使用生成、重新生成或 AI 优化功能时，请求内容会发送给用户选择的模型服务商。模型价格、额度、数据处理与服务质量以对应服务商的规则为准。

## 主要功能

- 文件、粘贴文本、相机与相册 OCR 导入资料。
- 单选、多选、判断、填空、主观及混合题型。
- 图表题、听力题、数学公式和多学科富内容。
- 普通练习、错题本、知识点诊断、错题抽卡。
- 五关章节地图、连击、知识护盾和 Boss 闯关。
- 试卷编辑、题目排序、学生版/教师版、PDF 与听力 MP3。
- 中文/英文、浅色/深色/跟随系统、减少动态效果。
- AI Cost Guard：防重复请求、有限重试、真实取消、本地熔断与脱敏调用记录。

## Android 快速开始

1. 安装测试 APK。
2. 打开“我的 → API 配置”。
3. 选择服务商，填写自己的 API Key。
4. 核对 Base URL 和模型名，测试连接后保存。
5. 导入资料并生成题目。

### 当前服务商模板

模型会随服务商更新，表格是 RC005 的默认值；用户始终可以手动修改模型名。

| 服务商 | Base URL | RC005 默认模型 | 官方文档/控制台 |
| --- | --- | --- | --- |
| DeepSeek | `https://api.deepseek.com` | `deepseek-v4-flash` | [控制台](https://platform.deepseek.com) / [更新记录](https://api-docs.deepseek.com/updates/) |
| Qwen / 阿里百炼 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` | [控制台](https://bailian.console.aliyun.com) / [文档](https://help.aliyun.com/zh/model-studio/model-calling-in-sub-workspace) |
| 智谱 GLM | `https://open.bigmodel.cn/api/paas/v4` | `glm-5.2` | [控制台](https://open.bigmodel.cn) / [文档](https://docs.bigmodel.cn/cn/guide/develop/openai/introduction) |
| 硅基流动 | `https://api.siliconflow.cn/v1` | `Pro/zai-org/GLM-4.7` | [控制台](https://cloud.siliconflow.cn) / [文档](https://docs.siliconflow.cn/en/api-reference/chat-completions/chat-completions) |
| 小米 MiMo | `https://api.xiaomimimo.com/v1` | `mimo-v2.5-pro` | [控制台](https://platform.xiaomimimo.com) / [文档](https://mimo.mi.com/docs/en-US/quick-start/summary/first-api-call) |
| Kimi | `https://api.moonshot.cn/v1` | `kimi-k3` | [控制台](https://platform.kimi.com) / [文档](https://platform.kimi.com/docs/api/overview) |
| 自定义 | 用户填写 | 用户填写 | 任意 OpenAI Chat Completions 兼容接口 |

不同服务商对参数支持不完全一致。RC005 会为 MiMo、Kimi 使用其当前文档兼容的请求参数，并限制自动重试，避免参数错误形成重复消耗。

## API 使用保护

所有 Android AI 请求必须经过统一的 AI Cost Guard：

- 同一时间只允许一个活动任务。
- 快速重复点击不会创建重复任务。
- 每个任务都有本地 Task ID、请求计数和脱敏凭证。
- 401、403、余额不足、模型不存在和 429 不进行无限重试。
- 临时网络错误或服务商 5xx 最多自动重试一次。
- 用户取消后停止后续重试；迟到结果不会覆盖已经离开的页面。
- 请求链达到安全上限或一分钟内异常创建大量任务时触发本地熔断。
- 本地记录不保存 API Key、Authorization、完整 Prompt 或完整资料。

“API 使用记录”只说明 AI题库在本机发起的请求，不等于服务商账单；最终用量和费用以服务商控制台为准。

## 数据与安全边界

- API Key 不进入普通 SharedPreferences、备份、试卷、诊断报告和日志。
- 旧明文 Key 只有在安全写入并回读成功后才会移除。
- RC005 首次启动会清理已废弃的官方服务 Token，但绝不会清空用户自己的 API Key。
- 敏感配置页禁止系统截图，应用退到后台后重新隐藏 Key。
- 默认关闭 Android 自动备份。
- 第三方模型调用会把本次请求内容发给所选服务商；正式使用前请阅读对应服务商隐私政策。

## 项目结构

```text
android-app/     Flutter Android 应用（Local-first BYOK）
backend/         FastAPI 网页/桌面端后端；不再提供官方 AI 商业接口
web/             静态官网与历史网页功能页
src-tauri/       Windows 桌面壳
docs/            v3 规划、测试、迁移与安全记录
artifacts/       本地构建产物（不作为 Pages 大文件部署目录）
```

## Android 开发与验证

```powershell
cd android-app
flutter pub get
flutter analyze --no-pub --no-fatal-infos
flutter test --no-pub --concurrency=1
flutter build apk --release --no-pub
```

## 后端开发

FastAPI 继续服务网页经典版、桌面端及既有普通 API。RC005 已移除隔离的官方 AI、报价、订单、支付和退款模块。

```powershell
cd backend
pip install -r requirements.txt
python main.py
```

运行测试：

```powershell
python -m pytest -q
```

## 静态官网

`web/` 可部署到 Cloudflare Pages。官网静态首页不依赖本机 FastAPI；Android APK 等大文件应使用 GitHub Releases、R2 或其他对象存储，不要直接作为 Pages 静态资源上传。

详见 [DEPLOYMENT.md](DEPLOYMENT.md)。

## 质量与发布状态

- 当前公开稳定版仍由项目发布页与官网标明；RC005 是预发布测试分支。
- 未经确认不合并 `main`、不覆盖官网稳定 APK。
- Phase 2 的真机 OCR/TTS/旧 MP3 测试及 RC004 动效真机回归仍需在发布前关闭。
- `syncfusion_flutter_pdf` 许可是公开/商业发布 P0 阻断项，详见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。
- 中国大陆生成式 AI 应用登记、公示和上架要求需要在正式公开发布前单独核验。

## 反馈安全提示

提交 GitHub Issue、邮件、截图或诊断信息时，**不要发送完整 API Key、Authorization Header、密码、JWT 或完整私人资料**。

API 异常消耗请使用仓库的“API 异常调用”Issue 模板，并附上应用生成的脱敏任务记录。

## 第三方软件

主要依赖、许可证和风险说明见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。本文件及项目文档不构成法律意见。
