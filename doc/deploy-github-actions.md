# 部署指南（GitHub Actions）

本文按官方文档 [Github Actions 部署](https://docs.skymail.ink/deployment/action.html) 编写，步骤、变量名、工作流都与上游一致。部署由仓库里的 `.github/workflows/deploy-fork.yml` 完成：它读取 GitHub 上的变量 → 替换 `mail-worker/wrangler-action.toml` 里的 `${...}` → `wrangler deploy` → 自动调 `/api/init` 初始化数据库。

**本仓库改了三处**：触发分支从 `main` 改成 `patched`；`wrangler-action.toml` 里**不声明任何路由**；`jwt_secret` 改为**加密 secret**（不再是明文变量）。（详见文末「与官方文档的差异」）其余全部沿用上游：变量名、部署命令、自动初始化数据库。

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
| `CUSTOM_DOMAIN` | ✅ | **这个 Worker 实际对外访问的域名**，如 `mail.example.com`（不是邮箱域名）。必须是控制台 `Domains & Routes` 里那条 Route / Custom Domain 用的主机名——工作流用它来调 `/api/init`，填错了会去打别的站点 |
| `DOMAIN` | ✅ | 邮箱域名，多域名用 JSON 数组：`["example.com","example2.com"]` |
| `ADMIN` | ✅ | 管理员邮箱，如 `admin@example.com` |
| `D1_DATABASE_ID` | ✅ | D1 数据库 ID（留空则按 `NAME` 自动创建） |
| `KV_NAMESPACE_ID` | ✅ | KV 命名空间 ID（留空则按 `NAME` 自动创建） |
| `JWT_SECRET` | ✅ | JWT 密钥，随便一串字符串，**不要带特殊字符**（`? % # / \` 会被校验拦下）。部署后由工作流写成**加密 secret**（`secret_text`），Dashboard 里看不到值 |
| `NAME` | ❌ | Worker 名称，默认 `cloud-mail` |

工作流还认这几个可选变量：`R2_BUCKET_NAME`、`PROJECT_LINK`、`AI_MODEL`、`ANALYSIS_CACHE`、`EMAIL`、`AI_BINDING`、`AI_FAILOVER`。不填就走默认值（`AI_MODEL` 默认 `@cf/meta/llama-3.1-8b-instruct-fast`，`AI_BINDING` 默认 `true`）。

> `AI_BINDING=false` 会让构建**始终**跳过 `[ai]`（Workers AI）绑定；`AI_FAILOVER=false` 则关闭「重试用尽后自动降级」。两者都为了绕过 CF 侧 `10021`；代价是 AI 邮件分析 / 验证码自动提取不可用。

`D1_DATABASE_ID` / `KV_NAMESPACE_ID` 从哪来：Cloudflare 控制台 **Storage & Databases** → D1 点进库看 **Database ID**；Workers KV 列表里看 **ID**。想让它自动建库就留空，工作流会用 `NAME` 查重、没有才创建。

**3. 从「界面部署」迁过来才需要的两件事**

如果这个 Worker 之前是控制台手动部署 / Cloudflare 自动构建，切换时处理这两件：

| 事项 | 怎么做 | 不做的后果 |
|---|---|---|
| 断开 Cloudflare 自动构建 | Worker → **Settings** → **Build** → 断开 Git 连接（显示为 Disconnect） | 一次 push 触发两套部署，互相覆盖，日志里看不出谁赢 |
| 删掉旧的 `JWT_SECRET`（大写） | `cd mail-worker && npx wrangler secret delete JWT_SECRET` | 绑定名区分大小写，删了不影响代码；留着会让人误以为它是生效的密钥（代码只读小写 `jwt_secret`），改它也不会生效 |

> 代码读的是小写 `c.env.jwt_secret`。如果只剩大写 `JWT_SECRET`，取到的是 `undefined`，HMAC 密钥会变成字符串 `"undefined"`，**任何人都能伪造 JWT**。现在工作流每次部署都会写入小写的加密 secret，所以不会出现这个状态，但大写那条残留仍建议删掉。

**关于域名**：本仓库**不在部署配置里声明路由**（见文末差异），域名→Worker 的路由照旧由控制台 `Settings → Domains & Routes` 里的那条 Zone Route 负责，DNS 记录也不用动。`CUSTOM_DOMAIN` 在这里只用于两件事：部署后自动访问 `https://<CUSTOM_DOMAIN>/api/init/<jwt_secret>` 初始化数据库，以及日志里显示地址。

> 顺带记住一个坑：上游默认用 `custom_domain = true`（Custom Domain），要求主机名上**不能有任何 A/CNAME**，否则报 `Hostname 'xxx' already has externally managed DNS records [code: 100117]`。本仓库干脆不在配置里声明路由，所以不会碰这个坑，也不会改动你控制台里已有的 Route 和 DNS。

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
🔐 写入 JWT 密钥（printf '%s' "$JWT_SECRET" | wrangler secret put jwt_secret，写成加密 secret）
♻️ 初始化数据库（自动 curl https://$CUSTOM_DOMAIN/api/init/$JWT_SECRET，校验返回 success）
🗑️ 删除运行记录
```

> 「初始化数据库」这一步是工作流自动做的，**不需要你手动访问 `/api/init`**。它会建表 / 补字段，不会覆盖已有数据。
> 它会先试 `https://$CUSTOM_DOMAIN/api/init/<jwt_secret>`，再试 Worker 的 workers.dev 地址；两个都没返回 `success` 时只在日志和 Summary 里给警告，**不会让部署变红**（代码和绑定已经上线了，这一步只是补表）。

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
| `📦 安装依赖` 报 `ERR_PNPM_OUTDATED_LOCKFILE` | `package.json` 的版本范围变了但 `pnpm-lock.yaml` 没跟着更新（上游发版常见） | `cd mail-worker && npx pnpm@11 install --lockfile-only` 后提交锁文件；应急可把 workflow 的 `pnpm install --frozen-lockfile` 改成 `pnpm install` |
| 部署报 `Hostname 'xxx' already has externally managed DNS records [code: 100117]` | 模板里又写回了 `[[routes]] custom_domain = true` | 删掉模板里的路由声明（本仓库默认不声明） |
| 部署后域名打不开，但 workers.dev 正常 | Zone Route 被删了（例如手动改过控制台） | 控制台 → Worker → Settings → Domains & Routes → 重新加 `你的域名/*` |
| 部署报 secret 同名冲突 | 控制台还留着 `jwt_secret` 或 `JWT_SECRET` secret | `npx wrangler secret delete <名字>` |
| 控制台 `Variables and Secrets` 里同时出现 `jwt_secret` 和 `JWT_SECRET`（大小写两个） | 绑定名**区分大小写**，是两个独立绑定。小写 `jwt_secret` 现在由工作流以**加密 secret** 写入（如果它显示为明文 var，说明还是旧版本部署留下的，下次部署会清掉）；大写 `JWT_SECRET` 是早期在控制台手工加的 secret，`wrangler deploy` 不会删它，所以一直残留，而且代码不读它 | 删掉大写的 `JWT_SECRET`（Dashboard 或 `npx wrangler secret delete JWT_SECRET`）。**不要动小写的 `jwt_secret`** —— 它是真正在用的那个 |
| 部署报 `binding ai of type ai failed to generate: internal error ... [code: 10021]` | Cloudflare 生成 Workers AI 绑定（`POST /workers/scripts/<名字>/versions`）时内部错误。这个错误是**间歇性**的：同一份配置可能这次成功、下次连试几次都失败，与仓库配置无关 | 工作流已内置 **4 次退避重试**（间隔 15s / 45s / 90s）。若仍然失败，会自动**去掉 `[ai]` 再部署一次**，保证代码上线，并在 Summary 里标注「本次跳过 Workers AI 绑定」（影响：AI 邮件分析、验证码自动提取，不影响收发信）。不想自动降级就把 `AI_FAILOVER` 设为 `false`；想彻底跳过 AI 绑定就把 `AI_BINDING` 设为 `false` |
| `♻️ 初始化数据库` 报「未成功」，响应是一段 HTML（带 `<!DOCTYPE html>`） | `CUSTOM_DOMAIN` 不是这个 Worker 的域名，请求打到了同一账号下别的站点，拿回来的是那边的前端页面 | 把 `CUSTOM_DOMAIN` 改成 Worker 真正的访问域名；或手动打开 `https://正确域名/api/init/你的jwt_secret`，看到 `success` 即可 |
| Run 的 Summary 显示「本次部署跳过了 Workers AI 绑定」 | 4 次重试都撞上 CF 的 `10021`，工作流自动降级部署了 | 再 Run 一次即可；绑定生成成功的话 `[ai]` 会自动加回，AI 功能随之恢复 |
| 初始化返回非 `success`（响应是纯文本/JSON） | Worker 里的 `jwt_secret` 与 `JWT_SECRET` 变量不一致（大写 secret 残留） | 删掉大写 secret，重跑 |
| 最后一步 `🗑️ 删除运行记录` 报 `Resource not accessible by integration` | 工作流没给 `GITHUB_TOKEN` 开 `actions: write` 权限，删不掉旧 run | 已在 job 上加 `permissions: { actions: write, contents: read }`，重新部署即好；这一步失败不影响线上 |
| 站点 502 / 白屏 | 前端 `[build]` 没构建成功 | 看「开始部署」日志里 pnpm 构建那一段 |
| 收不到邮件 | MX 未指向 Email Routing，或域名不在 `DOMAIN` | 检查 DNS 与 `DOMAIN` |

---

## 安全提醒

- `wrangler-action.toml` 是**模板**，里面只有 `${...}` 占位符，不要往里填真实值（工作流只在 CI 的工作副本里替换）。
- 真实 D1 / KV ID、`ADMIN`、`JWT_SECRET` 只放 GitHub Actions 的 Secrets / Variables，不要写进任何被跟踪的文件。
- 仓库是公开的：`JWT_SECRET` 请放 **Secret** 而不是 Variable（Variable 明文可见，日志里也不会打码）。
- 部署到 Worker 后 `jwt_secret` 是**加密 secret**，控制台读不回。**请自己另存一份**（密码管理器）；两处都只写不读，丢了只能换新值（代价仅是所有人重新登录，邮件与数据不受影响）。
- 部署后 `jwt_secret` 在 Worker 上是**明文 var**（`wrangler deploy` 从配置写入，控制台和 API 可读）。要加密存储就得改流程：把 `jwt_secret` 从 workflow 的替换里去掉，部署后单独 `npx wrangler secret put jwt_secret`，代价是每次构建要人盯。

---

## 与官方文档的差异

| 位置 | 官方 | 本仓库 | 原因 |
|---|---|---|---|
| workflow 触发分支 | `main` | `patched` | 本仓库的开发与部署分支是 `patched`；`main` 只用来跟上游对齐，不从它触发部署，避免把不带 fork 改动的上游代码发上线 |
| `jwt_secret` 的存储形态 | 明文变量（`[vars] jwt_secret = "${JWT_SECRET}"`） | 部署后 `wrangler secret put` 写成**加密 secret** | 明文 var 在 Dashboard 里可直接读值、`wrangler deploy` 的日志还会打印 `env.jwt_secret ("值")`，公开仓库的 Actions 日志等于公开（只能靠 GitHub 对 Secret 打码兜底）。改成 secret 后控制台与日志都看不到值；代价是**不可读回**，源值只存在于 GitHub 的 Secret 和你的备份里 |
| 路由声明 | `[[routes]]` + `custom_domain = true`（Custom Domain） | 完全不声明路由 | 声明路由会让每次部署都去改 Cloudflare 的 triggers：Custom Domain 要求主机名上没有 A/CNAME（撞 `100117`），对象写法的 route 又必须带 `zone_name`。不声明则部署只更新代码/绑定/变量，**路由和 DNS 一律不动**，正好满足「更新不影响已有配置」 |

其余全部一致：变量名、部署命令、自动初始化数据库、可选变量、可选绑定都沿用上游。
