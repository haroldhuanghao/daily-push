# 每日推送

每日推送是一个由 Vercel 托管的纯静态日报站点，正式域名为
[`daily.851473.xyz`](https://daily.851473.xyz)。

## 链接规则

- 每份日报都有永久链接：`/reports/YYYY-MM-DD/`
- 根路径 `/` 临时跳转到最新发布的日报
- 历史归档位于 `/archive/`
- 已发布日报不得被下一天的内容覆盖

例如，2026 年 8 月 4 日的永久链接是：

```text
https://daily.851473.xyz/reports/2026-08-04/
```

## 目录

```text
reports/
  YYYY-MM-DD/index.html   # 每天唯一的正式发布页
  index.json              # 归档数据，按日期倒序
  latest.json             # 最新日报信息
archive/index.html        # 历史归档页
templates/daily-report.html
scripts/new-report.ps1
scripts/register-report.ps1
scripts/validate-repo.ps1
scripts/send-wecom.ps1
vercel.json               # 根路径跳转
docs/editorial-spec.md    # 核电行业日报内容与交付规范
```

## 发布一份日报

所有日期按 `Asia/Shanghai`（UTC+8）计算。

```powershell
# 1. 从模板创建今天的日报（已存在时会拒绝覆盖）
./scripts/new-report.ps1

# 2. 编辑 reports/YYYY-MM-DD/index.html，生成 cover.png 和 wecom-summary.md
#    具体内容与格式要求见 docs/editorial-spec.md
# 3. 登记到归档
./scripts/register-report.ps1 -Date 2026-08-05 `
  -Title "每日推送 · 2026-08-05" `
  -Summary "今天的日报摘要"

# 4. 提交前校验
./scripts/validate-repo.ps1
```

提交并等待 Vercel 部署成功后，再推送企业微信群：

```powershell
$env:WECOM_WEBHOOK_URL = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=..."
./scripts/send-wecom.ps1 -Date 2026-08-05
```

Webhook 只放在本机环境变量或部署平台 Secret 中，不能写入 Git。脚本会先确认日报链接可访问，再发送群消息。

## 页面样式

日报模板采用桌面双栏、移动端单栏的卡片布局。页面结构、间距、字体和响应式规则保持统一，主题色可以通过模板顶部的 CSS 变量调整。每份日报内嵌自己的样式，因此后续模板升级不会改变历史页面外观。内容筛选、栏目和企业微信交付要求见 [编辑规范](docs/editorial-spec.md)。

具体约束见 `AGENTS.md`；`scripts/validate-repo.ps1` 会在发布前检查主题变量、语义化结构、移动端断点、表格容器、键盘焦点和外部样式依赖。
