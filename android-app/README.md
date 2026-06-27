# AI题库 · 安卓单体版

这是基于主项目新增的 Android APK 版本，目录独立于现有 `web/` 和 `backend/`，不会改变原来的 FastAPI + Web 使用方式。

## 产品定位

- 无登录、无注册、无云端账号。
- 不需要手机之外的电脑或服务器挂后端。
- 资料、API Key、练习历史、错题本都保存在当前手机本地。
- App 直接请求用户配置的大模型 API 来生成题目。

## 已实现功能

- 本地资料库：导入 PDF、DOCX 或文本文件，或粘贴学习资料。
- AI 出题：支持单选题、多选题、判断题、填空题、主观题，可多选混合出题。
- API 配置：内置 DeepSeek、SiliconFlow、OpenAI、通义千问、智谱清言、自定义。
- 本地答题：自动判分、显示解析、完成后记录成绩。
- 错题本：答错题目自动收录在本机。
- 学习统计：累计做题、正确率、错题数量、历史记录。

## 当前资料格式

当前 APK 已支持直接导入并解析常见学习资料：

- `.pdf`
- `.docx`
- `.txt`
- `.md`
- `.csv`
- `.json`

说明：扫描版 PDF 或图片型 PDF 暂时无法直接提取文字，后续可继续接入 OCR；老式 `.doc` 文件请先另存为 `.docx` 后再导入。

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
