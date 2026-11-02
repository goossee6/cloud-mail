# 部署指南（GitHub Actions）

本文按官方文档 [Github Actions 部署](https://docs.skymail.ink/deployment/action.html) 编写，步骤、变量名、工作流都与上游一致。部署由仓库里的 `.github/workflows/deploy-cloudflare.yml` 完成：它读取 GitHub 上的变量 → 替换 `mail-worker/wrangler-action.toml` 里的 `${...}` → `wrangler deploy` → 自动调 `/api/init` 初始化数据库。

**本仓库只改了一行**：触发分支从 `main` 改成 `patched`（见文末「与官方文档的差异」）。其余全部沿用上游：变量名、`wrangler-action.toml` 模板、部署命令、`CUSTOM_DOMAIN` 建 route、自动初始化数据库。

---

## 创建 API 令牌

1. 打开 [Cloudflare API 令牌](https://dash.cloudflare.com/profile/api-tokens) → **创建令牌** → 选 **Edit Cloudflare Workers** 模板。
2. 复制两样东西，下一步要填：
   - **Account ID**（账户 ID，右侧栏可见）
   - **API 令牌**（只显示一次）

模板权限已覆盖：Workers Scripts 编辑、Workers KV Storage 编辑、Workers R2 Storage 编辑、Workers Routes 编辑、Account Settings 读取。`D1_DATABASE_ID` / `KV_NAMESPACE_ID` 留空让工作流自动建库时，还要 D1 编辑权限——两个 ID 都填的话不需要。

---

## 准备环境

**1. Fork 仓库**

把 [github.com/goossee6/cloud-mail](https://github.com/goossee6/cloud-mail) fork 或克隆到自己的 GitHub 账号。

**2. 配置 Action Secret 或 Variables**

仓库 → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**（或 **Variables** 标签页，两个都支持，工作流里是 `secrets.X || vars.X`）。

| 变量名 | 必需 | 用途 |
|---|---|---|
| `CLOUDFLARE_API_TOKEN` | ✅ | Cloudflare API 令牌（建议放 Secret） |
| `CLOUDFLARE_ACCOUNT_ID` | ✅ | Cloudflare 账户 ID |
| `CUSTOM_DOMAIN` | ✅ | **访问网站的域名**，如 `mail.example.com`（不是邮箱域名） |
| `DOMAIN` | ✅ | 邮箱域名，多域名用 JSON 数组：`["example.com","example2.com"]` |
| `ADMIN` | ✅ | 管理员邮箱，如 `admin@example.com` |
| `D1_DATABASE_ID` | ✅ | D1 数据库 ID（留空则按 `NAME` 自动创建） |
| `KV_NAMESPACE_ID` | ✅ | KV 命名空间 ID（留空则按 `NAME` 自动创建） |
| `JWT_SECRET` | ✅ | JWT 密钥，随便一串字符串，**不要带特殊字符**（`? % # / \` 会被工作量校验拦下） |
| `NAME` | ❌ | Worker 名称，默认 `cloud-mail` |

工作流还认这几个可选变量：`R2_BUCKET_NAME`、`PROJECT_LINK`、`AI_MODEL`、`ANALYSIS_CACHE`、`EMAIL`。不填就走默认值（`AI_MODEL` 默认 `@cf/meta/llama-3.1-8b-instruct-fast`）。

`D1_DATABASE_ID` / `KV_NAMESPACE_ID` 从哪来：Cloudflare 控制台 **Storage & Databases** → D1 点进库看 **Database ID**；Workers KV 列表里看 **ID**。想让它自动建库就留空，工作流会用 `NAME` 查重、没有才创建。

**3. 从「界面部署」迁过来才需要的三件事**

如果这个 Worker 之前是控制台手动部署 / Cloudflare 自动构建，切换时大概率要处理这三件（也可以先跑一次看报错，再回头处理）：

| 事项 | 怎么做 | 不做的后果 |
|---|---|---|
| 删掉旧的 Zone Route | Worker → **Settings** → **Domains & Routes** → 删掉 `mail.example.com/*` 那条 route | `CUSTOM_DOMAIN` 会建同名 Custom Domain，同一个主机名不能既是 route 又是 custom domain，部署报错 |
| 断开 Cloudflare 自动构建 | Worker → **Settings** → **Build** → 断开 Git 连接（显示为 Disconnect） | 一次 push 触发两套部署，互相覆盖，日志里看不出谁赢 |
| 删掉冲突的旧 secret | `cd mail-worker && npx wrangler secret delete JWT_SECRET` | 工作流把 `jwt_secret` 当**明文 var** 部署，同名 secret 会让部署报错或读到旧值 |

> 大写 `JWT_SECRET` 这个 secret 本来就必须删：代码读的是小写 `c.env.jwt_secret`，大写会让 HMAC 密钥变成字符串 `"undefined"`，**任何人都能伪造 JWT**。

---

## 开始部署

**1. 首次运行先启用工作流**

fork 出来的仓库默认不跑 Actions：打开仓库 **Actions** 标签页，点 **I understand my workflows, go ahead and enable them**。

**2. 运行工作流**

两种方式二选一：

- **Actions** → 左侧 `🚀 Deploy cloud-mail to Cloudflare Workers` → **Run workflow** → 分支选 `patched` → Run
- 直接推代码：`git push origin patched`（改了 `mail-worker/**` 或 `mail-vue/**` 才会触发）

**3. 等待运行完成**

正常会依次走完：

```
🚚 检出代码仓库   ⚙ 设置 pnpm   ⚙ 设置 Node.js   📦 安装依赖
🛠️ 设置环境（校验 JWT_SECRET / DOMAIN / ADMIN，替换配置占位符）
⚡ 设置 KV 数据库   🐬 设置 D1 数据库
🚀 开始部署（pnpm wrangler deploy -c wrangler-action.toml）
♻️ 初始化数据库（自动 curl https://$CUSTOM_DOMAIN/api/init/$JWT_SECRET，校验返回 success）
🗑️ 删除运行记录
```

> 「初始化数据库」这一步是工作流自动做的，**不需要你手动访问 `/api/init`**。它会建表 / 补字段，不会覆盖已有数据。

---

## 设置邮件转发

1. 按 [界面部署 - 设置转发](https://docs.skymail.ink/deployment/dashboard.html) 在 **Email Routing** 里验证要转发到的邮箱。
2. 收信还要求邮箱域名的 **MX 记录指向 Cloudflare Email Routing**，且域名在 `DOMAIN` 列表里。

---

## 登录网站

浏览器打开 `https://CUSTOM_DOMAIN`，用 `ADMIN` 里配的那个邮箱**注册**账号，它会成为管理员。

---

## 项目更新

官方文档的说法，对应到本仓库：

| | 官方：GitHub Action 部署 | 官方：界面部署 |
|---|---|---|
| 同步代码后 | Action 自动重新部署 | Worker 自动更新，但**绑定的 D1 / KV 会掉，要重新绑** |
| 数据库结构 | Action 末尾自动跑 `/api/init` | 需手动执行 `/api/init`（只会更新不会覆盖已有数据） |

本仓库用的就是 Action 这条，所以更新只有一步：

```bash
git fetch upstream && git merge upstream/main     # 本地同步上游
git push origin patched                            # 推送即触发部署
```

推送后去 **Actions** 看这条 run 变绿即可，绑定不会掉，数据库也会自动升级。

---

## 常见故障

| 现象 | 原因 | 处理 |
|---|---|---|
| Actions 里没有 workflow / 不能运行 | fork 仓库的 Actions 未启用 | Actions 页点 enable |
| push 了但没触发 | 分支不是 `patched`，或改动不在 `mail-worker/**`、`mail-vue/**` 里 | 用 Run workflow 手动跑，或确认分支 |
| `⚙ 设置 pnpm` 失败，或 `📦 安装依赖` 报 `ERR_PNPM_OUTDATED_LOCKFILE` | workflow 里的 pnpm 版本与 `mail-worker/pnpm-lock.yaml`（`lockfileVersion 9.0`）不匹配 | 把 workflow 里 `version: 11` 改成 `version: 10` 重跑 |
| 部署报 custom domain / route 冲突 | 同一主机名上还留着旧 Zone Route | 删掉旧 route，见《准备环境》第三步 |
| 部署报 secret 同名冲突 | 控制台还留着 `jwt_secret` 或 `JWT_SECRET` secret | `npx wrangler secret delete <名字>` |
| `♻️ 初始化数据库` 失败：`Preview URL not available` | `CUSTOM_DOMAIN` 没配，且拿不到 workers.dev 地址 | 填上 `CUSTOM_DOMAIN` |
| 初始化返回非 `success` | Worker 里的 `jwt_secret` 与 `JWT_SECRET` 变量不一致（大写 secret 残留） | 删掉大写 secret，重跑 |
| 站点 502 / 白屏 | 前端 `[build]` 没构建成功 | 看「开始部署」日志里 pnpm 构建那一段 |
| 收不到邮件 | MX 未指向 Email Routing，或域名不在 `DOMAIN` | 检查 DNS 与 `DOMAIN` |

---

## 安全提醒

- `wrangler-action.toml` 是**模板**，里面只有 `${...}` 占位符，不要往里填真实值（工作流只在 CI 的工作副本里替换）。
- 真实 D1 / KV ID、`ADMIN`、`JWT_SECRET` 只放 GitHub Actions 的 Secrets / Variables，不要写进任何被跟踪的文件。
- 仓库是公开的：`JWT_SECRET` 请放 **Secret** 而不是 Variable（Variable 明文可见）。
- 部署后 `jwt_secret` 在 Worker 上是**明文 var**（`wrangler deploy` 从配置写入，控制台和 API 可读）。要加密存储就得改流程：把 `jwt_secret` 从 workflow 的替换里去掉，部署后单独 `npx wrangler secret put jwt_secret`，代价是每次构建要人盯。

---

## 与官方文档的差异

| 位置 | 官方 | 本仓库 | 原因 |
|---|---|---|---|
| workflow 触发分支 | `main` | `patched` | 本仓库的开发与部署分支是 `patched`；`main` 只用来跟上游对齐，不从它触发部署，避免把不带 fork 改动的上游代码发上线 |

其余全部一致：`CUSTOM_DOMAIN` 建 Custom Domain route、变量名、`wrangler-action.toml` 模板、部署命令、自动初始化数据库、可选变量都沿用上游。
