# 日报仓库协作规则

本仓库用于让 AI 创建、留存并发布每日中文日报。所有日期均按 `Asia/Shanghai`（UTC+8）计算。

日报的编辑规范见 [`docs/editorial-spec.md`](docs/editorial-spec.md)。它定义了本仓库唯一适用的行业范围、信息准入、去重追踪、栏目结构、封面和企业微信摘要要求。与一般写作偏好冲突时，以该规范为准。

## 每次创建日报必须遵守

1. 正式日报只能放在 `reports/YYYY-MM-DD/index.html`，URL 为 `/reports/YYYY-MM-DD/`。
2. 使用 `scripts/new-report.ps1 -Date YYYY-MM-DD` 从模板创建；目标已存在时不得覆盖。
3. 完成正文后运行 `scripts/register-report.ps1`，同步 `reports/index.json`、`reports/latest.json` 和 `vercel.json`。
4. 运行 `scripts/validate-repo.ps1`，修复所有错误后再提交。
5. 等 Vercel 部署完成并确认永久链接返回成功后，才能运行 `scripts/send-wecom.ps1` 推送企业微信群。
6. 企业微信 Webhook、Vercel Token 和其他密钥只能来自环境变量，严禁写入代码、日报或 Git。
7. 每期必须同时交付：`index.html`、`cover.png`（1200×628）和 `wecom-summary.md`。封面或摘要尚未就绪时，不得登记或推送。
8. 新建页面必须基于 `templates/daily-report.html`；仅允许替换模板占位内容和添加符合该模板组件规范的正文，不能删减必需栏目。

## HTML 与视觉规范

日报可以按主题调整主色，但页面结构和阅读体验必须保持一致：

- 每份日报必须是自包含的静态 HTML，不引入外部字体、CSS 框架或运行时脚本；样式写在本页 `<style>` 中，确保历史页面外观不会随模板升级而改变。
- 在 `:root` 中定义并使用 `--accent`、`--accent-strong`、`--accent-soft`、`--page`、`--surface`、`--text`、`--muted`、`--border`、`--shadow`、`--radius-card` 和 `--space-card`。更换主题时只调整颜色变量，不随意改变卡片尺寸体系。
- 页面以一个 Hero、摘要卡片、正文卡片和页脚为基础；长报告可增加侧边目录、数据表格、标签、提示卡和行动卡。嵌套卡片最多两层，避免把每句话都做成卡片。
- 正文区域桌面最大宽度约 `1120px`。桌面可使用正文加目录的双栏结构，`900px` 以下必须取消侧栏，`640px` 以下必须改为单栏并减小卡片内边距。
- 卡片使用高对比表面色、`1px` 边框、`14–18px` 圆角和轻量阴影；卡片间距保持 `12–24px`，不得使用厚重阴影、玻璃拟态或大面积高饱和背景。
- 正文字号不得小于 `14px`，行高保持 `1.65–1.75`；主标题使用 `clamp()`，长标题不得溢出。页面只使用一个主题主色，风险和提醒色只表达状态。
- 所有链接必须有清晰的 hover 和 `:focus-visible` 状态。图片必须带有准确 `alt`；不得只用颜色表达信息。
- 表格必须放在带 `overflow-x:auto` 的 `.table-wrap` 中。页面本身不得产生横向滚动，不使用固定内容高度。
- 使用语义化的 `main`、`section`、`article`、标题层级和来源链接。禁止零散的 `style="..."` 属性，统一通过类名和设计变量控制。
- 优先复用 `templates/daily-report.html` 中的组件类，不为单篇日报发明一套互不兼容的视觉语言。

## 内容与留存

- 已发布日期目录视为不可变历史；除非用户明确要求勘误，不得修改或删除。
- 不得用根目录 `index.html` 存放某一天的日报，也不得复制出多个正式 HTML 版本。
- 临时草稿、版本对比稿和 QA 产物必须放在 `_drafts/`，不能放在 `reports/` 或被部署。
- 页面使用 UTF-8、简体中文，并设置准确的 `title`、description、Open Graph 标题和永久 URL。
- 新闻事实应保留可核验的来源链接，不得伪造来源；不确定内容应明确标注。
- 可以在日期目录中附带 Markdown 来源稿或附件，但 `index.html` 是唯一正式页面。
- 群里始终发送日期永久链接，不发送根路径 `/`，这样历史消息不会跳到新日报。
- 历史日报在发布时执行的规范为准；更新模板或校验规则不能倒逼改写已发布内容。
