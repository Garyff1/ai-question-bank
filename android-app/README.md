# AI题库 · Android 单体版

这是 AI题库的 Android APK 版本。它独立于 `web/` 和 `backend/`，不改变原来的 FastAPI + Web 使用方式。

## 产品定位

- 无云端账号、无注册、无登录。
- 不需要手机之外的电脑或服务器挂后端。
- 资料、API Key、练习历史、错题本都保存在当前手机本地。
- App 直接请求用户配置的大模型 API 来生成题目。

## 当前公开测试版本

- 版本：Android v1.0.2
- 状态：早期测试版
- APK：[下载地址](https://github.com/Garyff1/ai-question-bank/releases/download/android-v1.0.2/ai-question-bank-android-v1.0.2.apk)
- Release：[AI题库 Android v1.0.2](https://github.com/Garyff1/ai-question-bank/releases/tag/android-v1.0.2)
- SHA-256：`9C459AC45A5626DDE206A84D4E56DB107F9ECDCE4DCCC4CD1C9E6C5624DB501C`

## 已实现功能

- 本地资料库：导入 PDF、DOCX、TXT、Markdown、CSV、JSON，或直接粘贴学习资料。
- AI 出题：支持单选题、多选题、判断题、填空题、主观题，可多选混合出题。
- API 配置：预设 DeepSeek、Qwen、智谱、小米 MiMo、Kimi、自定义。
- 本地答题：自动判分、显示解析、完成后记录成绩。
- 错题本：答错题目自动收录在本机。
- 学习统计：累计做题、正确率、错题数量、历史记录。

## API 服务商预设

| 服务商 | Base URL | 默认模型 | 说明 |
| --- | --- | --- | --- |
| DeepSeek | `https://api.deepseek.com` | `deepseek-v4-flash` | OpenAI-compatible。旧 `deepseek-chat` 将不再作为默认推荐。 |
| Qwen / 阿里百炼 | `https://dashscope.aliyuncs.com/compatible-mode/v1` | `qwen-plus` | OpenAI-compatible；也可按阿里云控制台替换为 workspace Endpoint。 |
| 智谱 / Z.ai | `https://api.z.ai/api/paas/v4` | `glm-4.5-flash` | OpenAI-compatible。 |
| 小米 MiMo | `https://api.xiaomimimo.com/v1` | `MiMo-VL-7B-RL` | Chat Completions 路径兼容，但 Header 使用 `api-key`。 |
| Kimi / Moonshot | `https://api.moonshot.ai/v1` | `kimi-k2.6` | OpenAI-compatible。 |
| 自定义 | 用户填写 | 用户填写 | 适合兼容 OpenAI Chat Completions 的第三方网关或本地服务。 |

## 当前资料格式

已支持直接导入并解析：

- `.pdf`
- `.docx`
- `.txt`
- `.md`
- `.csv`
- `.json`

说明：

- 扫描版 PDF 或图片型 PDF 暂时无法直接提取文字，后续可继续接入 OCR。
- 老式 `.doc` 文件请先另存为 `.docx` 后再导入。
- 大文件导入仍需继续优化，目前可能出现明显卡顿。

## 已记录的优化项

| 优先级 | 反馈 | 计划 |
| --- | --- | --- |
| P0 | 导入资料时卡顿，资料大时可能自动退出。 | 改成后台解析、进度提示、分段读取和内存保护。 |
| P1 | 错题本清空容易误触。 | 增加二次确认。 |
| P1 | 资料删除容易误触。 | 增加二次确认并显示资料名称。 |
| P1 | 错题本缺少错题训练。 | 增加“开始错题训练”按钮。 |
| P1 | 错题没有按资料分组。 | 按资料建立独立错题收纳，同时保留全部错题入口。 |
| P2 | API 配置成功反馈不明显。 | 增加动态电池动画和“更换其他接口”按钮。 |
| P2 | 底部导航切换缺少触觉反馈。 | 增加轻量震动反馈。 |

## 构建 APK

```powershell
cd H:\ai-question-bank\android-app
H:\DevTools\flutter\bin\flutter.bat build apk --release --no-shrink
```

产物路径：

```text
H:\ai-question-bank\android-app\build\app\outputs\flutter-apk\app-release.apk
```

调试包：

```powershell
H:\DevTools\flutter\bin\flutter.bat build apk --debug
```

## 开发检查

```powershell
H:\DevTools\flutter\bin\flutter.bat analyze
H:\DevTools\flutter\bin\flutter.bat test
```
