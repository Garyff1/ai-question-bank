# AI题库第三方软件与许可证说明

更新日期：2026-07-14
适用范围：Android v3.0.0 Phase 2 Dev002

本文件用于说明 AI题库直接使用的主要第三方软件。应用内“设置 → 开源许可”会展示 Flutter 在构建时收集的完整许可证原文；本文件侧重列出直接依赖、用途和需要关注的商业许可边界。各软件仍以其随包许可证原文为准。

| 项目 | 当前版本 | 用途 | 许可证 | 项目地址 | 是否修改源码 |
|---|---:|---|---|---|---|
| Flutter | 当前构建工具链 | 跨平台应用框架 | BSD-3-Clause | https://flutter.dev | 否 |
| http | 1.6.0 | API 请求 | BSD-3-Clause | https://pub.dev/packages/http | 否 |
| shared_preferences | 2.5.5 | 本地非敏感设置与业务数据 | BSD-3-Clause | https://pub.dev/packages/shared_preferences | 否 |
| file_picker | 11.0.2 | 资料文件选择 | MIT | https://pub.dev/packages/file_picker | 否 |
| url_launcher | 6.3.2 | 打开网页和外部链接 | BSD-3-Clause | https://pub.dev/packages/url_launcher | 否 |
| archive | 4.0.9 | ZIP 打包 | MIT | https://pub.dev/packages/archive | 否 |
| xml | 6.6.1 | 文档内容解析 | MIT | https://pub.dev/packages/xml | 否 |
| flutter_svg | 2.3.0 | SVG 图形渲染 | MIT | https://pub.dev/packages/flutter_svg | 否 |
| smart_content_viewer | 1.0.1 | 数学与多学科富内容渲染 | MIT | https://pub.dev/packages/smart_content_viewer | 否 |
| audioplayers | 6.7.1 | 现有音频播放能力 | MIT | https://pub.dev/packages/audioplayers | 否 |
| flutter_edge_tts | 0.0.2 | 旧版试卷 MP3 导出兼容 | MIT | https://pub.dev/packages/flutter_edge_tts | 否 |
| flutter_tts | 4.2.5 | v3 系统 TTS 播放、暂停、重播与语速控制 | MIT | https://pub.dev/packages/flutter_tts | 否 |
| image_picker | 1.2.3 | 拍照和从相册选择扫描页 | BSD-3-Clause | https://pub.dev/packages/image_picker | 否 |
| image_cropper | 12.2.1 | OCR 前裁剪与旋转 | BSD-3-Clause | https://pub.dev/packages/image_cropper | 否 |
| google_mlkit_text_recognition | 0.15.1 | Android/iOS 本地文字识别桥接 | MIT | https://pub.dev/packages/google_mlkit_text_recognition | 否 |
| Google ML Kit Text Recognition | Android 16.0.1（中文模块） | 设备端中英文识别引擎 | Google ML Kit 条款 | https://developers.google.com/ml-kit | 否 |
| fl_chart | 0.69.2 | 折线图、柱状图和饼图本地绘制 | MIT | https://pub.dev/packages/fl_chart | 否 |
| path_provider | 2.1.6 | 用户数据和临时文件目录 | BSD-3-Clause | https://pub.dev/packages/path_provider | 否 |
| intl | 0.20.2 | 国际化与格式化 | BSD-3-Clause | https://pub.dev/packages/intl | 否 |
| syncfusion_flutter_pdf | 33.2.13 | 试卷与答案 PDF 生成 | Syncfusion Community / Commercial License | https://pub.dev/packages/syncfusion_flutter_pdf | 否 |

## Syncfusion 许可风险说明

`syncfusion_flutter_pdf` 不是 MIT/BSD 类开源包。Syncfusion 明确要求使用者持有商业许可证，或经申请并满足条件的 Community License。Community License 当前公开条件包括：年总收入低于 100 万美元、开发者不超过 5 人、员工不超过 10 人，且外部融资历史不超过 300 万美元；开源项目使用前也要求联系 Syncfusion 注册。

因此在发布商业化的官方 AI 服务前必须完成以下任一项：

1. 取得并留档有效的 Syncfusion Community License；或
2. 购买适用的商业许可证；或
3. 评估并迁移到许可证兼容的 PDF 方案。

在上述核验完成前，不应把“仓库使用 MIT 许可证”理解为自动覆盖 Syncfusion 组件。

## OCR 与系统能力说明

- `google_mlkit_text_recognition` Flutter 桥接包采用 MIT 许可证，但底层 Google ML Kit 服务仍受 Google 相应条款约束。
- `flutter_tts` 调用设备系统语音；不同设备、语音引擎和系统版本的可用语言及暂停能力可能不同。
- 本清单不是法律意见。项目进入收费或大规模分发前，应再次核验当时的依赖版本和许可证文本。
