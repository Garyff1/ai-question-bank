# AI题库官网部署说明

本文档用于把 `aichuti.ccwu.cc` 从本机 Cloudflare Tunnel 切换到 Cloudflare Pages 静态托管。

## 目标架构

```text
aichuti.ccwu.cc
  -> Cloudflare Pages
  -> web/index.html
```

切换后，官网首页不再依赖 FastAPI 后端。即使本机后端、桌面端后端或 cloudflared 关闭，官网首页也应正常访问。

功能页 `web/v1-classic/` 和 `web/v2-desktop/` 仍然需要后端 API。正式用户建议下载桌面版使用，因为桌面版会自动启动内置 FastAPI 后端。

## Cloudflare Pages 项目配置

进入 Cloudflare Dashboard：

1. 打开 `Workers & Pages`。
2. 新建 Pages 项目。
3. 连接 GitHub 仓库：`Garyff1/ai-question-bank`。
4. 选择分支：
   - 临时预览：`codex/update-ai-question-bank-ui`
   - 正式上线：合并后选择 `main`
5. 构建配置：

```text
Framework preset: None
Build command: 留空
Build output directory: web
```

本项目的官网首页是纯静态 HTML/CSS/JS，不需要构建命令。

## 自定义域名切换

`aichuti.ccwu.cc` 不能继续指向 Cloudflare Tunnel。切换到 Pages 时，请在 Pages 项目的 `Custom domains` 中添加：

```text
aichuti.ccwu.cc
```

Cloudflare 会自动提示需要的 DNS 记录。通常是：

```text
Type: CNAME
Name: aichuti
Target: <你的-pages-项目名>.pages.dev
Proxy status: Proxied
```

注意：

- 不要只在 DNS 页面手动添加 CNAME；还需要在 Pages 项目的 `Custom domains` 页面完成绑定。
- 如果已有同名 Tunnel 记录，请删除或替换它。
- 绑定后等待 Cloudflare 签发 SSL 证书，通常几分钟到几十分钟。

## 大文件下载处理

Cloudflare Pages 单个静态资源限制为 25 MiB。桌面版 zip 和 Android APK 都超过这个限制，因此不能放在 `web/` 目录内随 Pages 部署。

当前处理：

- `web/downloads/*.zip` 不进入 Pages。
- `web/downloads/*.apk` 不进入 Pages。
- 首页按钮临时显示“即将开放下载”。

后续推荐任选一种方式发布安装包：

1. GitHub Releases：适合开源项目，维护简单。
2. Cloudflare R2：适合和 Cloudflare Pages 放在同一体系。
3. 阿里云 OSS / 腾讯云 COS：适合国内访问优化。

拿到安装包外链后，再把 `web/index.html` 中的“即将开放下载”按钮改成真实下载链接。

## 部署前检查

在项目根目录运行：

```powershell
Get-ChildItem web -Recurse -File | Sort-Object Length -Descending | Select-Object -First 20 FullName,Length
rg -n "fetch\\(|/api/" web/index.html
```

要求：

- `web/` 内没有超过 25 MiB 的文件。
- `web/index.html` 首屏不主动请求 `/api`。
- 如果出现 `/api/` 字样，只能是展示文字或功能页链接，不能是首页加载时的请求。

## Cloudflare 参考文档

- Pages 自定义域名：https://developers.cloudflare.com/pages/configuration/custom-domains/
- Pages 平台限制：https://developers.cloudflare.com/pages/platform/limits/
- Tunnel 常见错误：https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/troubleshoot-tunnels/common-errors/
