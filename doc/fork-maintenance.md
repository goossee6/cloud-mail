# fork 维护手册

本仓库是 [cloud-mail](https://github.com/maillab/cloud-mail) 的 fork，在 `patched` 分支上维护自有功能（通知系统、数据迁移、部署流程）。

目标：**上游更新时尽量不冲突，冲突时能 30 秒内解决完**。

## 一、四条规则

1. **能新增文件，就不改上游文件。** 自有功能一律放在 `mail-worker/src/plugins/`、`mail-vue/src/views/sys-setting/fork/`、`mail-vue/src/i18n/fork/` 这类独立目录里。
2. **必须改上游文件时，只加 1～2 行，并打标记。** 用 `// fork:` 注释标出，冲突时按标记找位置。
3. **配置不进仓库。** 真实 ID、域名、密钥只放 GitHub Variables/Secrets 和本地 `mail-worker/wrangler.local.toml`（已 gitignore）。
4. **锁文件不手改。** 冲突时取上游那份，再重新生成。

## 二、耦合点清单

上游近半年改动次数（`git log --since="6 months ago" upstream/main -- <file>`）：

| 文件 | 本仓库改动 | 上游改动次数 | 冲突风险 | 处理方式 |
|---|---|---|---|---|
| `mail-worker/src/email/email.js` | +2 行（1 import + 1 调用） | 8 | 低 | 打 `// fork:` 标记 |
| `mail-worker/src/hono/webs.js` | +1 行（注册插件入口） | 0 | 极低 | 同上 |
| `mail-vue/src/views/sys-setting/index.vue` | +2 行（import + 组件标签） | 32 | 极低 | 同上 |
| `mail-vue/src/i18n/{zh,en}.js` | 0 | 31 / 36 | 无 | 文案在 `src/i18n/fork/`，运行时 merge |
| `mail-worker/wrangler.toml` | 0 | 14 | 无 | 保持上游原样，本地配置放 `wrangler.local.toml` |
| `mail-worker/wrangler-action.toml` | 7 行 | 0（上游不维护 CI 模板） | 无 | 自有文件 |
| `.github/workflows/deploy-fork.yml` | 独立文件 | — | 无 | 上游的 `deploy-cloudflare.yml` 已删除 |
| `mail-worker/pnpm-lock.yaml` | 生成物 | 频繁 | 每次升级包必冲突 | 取上游 + 重新生成 |
| `README.md` / `README-en.md` | fork 说明章节 | 9 | 中 | 冲突时保留 fork 章节 |

**零冲突的 fork 代码**（全部是新增文件）：

```
mail-worker/src/plugins/                 # 1040 行：通知系统 + 迁移 + 守卫
  guard.js                               #   /notify/*、/migration/* 权限校验
  index.js                               #   插件注册入口（webs.js 一行 import 到这里）
  notification/                          #   notify_rule 表、7 个 provider、API
  migration/                             #   孤儿邮件迁移
mail-worker/vitest.unit.config.js
mail-vue/src/plugins/{notify,migration}.js
mail-vue/src/i18n/fork/                  # fork 自有文案，运行时 mergeLocaleMessage
mail-vue/src/views/sys-setting/fork/NotifySettings.vue
mail-worker/wrangler.example.toml
doc/deploy-github-actions.md
doc/fork-maintenance.md
scripts/sync-upstream.sh
```

## 三、与上游的差异（合并时要保留）

| 项 | 上游 | 本仓库 | 原因 |
|---|---|---|---|
| 部署工作流 | `deploy-cloudflare.yml`，监听 `main` | `deploy-fork.yml`，监听 `patched` | 上游文件已删，避免一次 push 触发两套部署 |
| 路由声明 | `[[routes]] custom_domain = true` | 不声明 | Custom Domain 要求主机名无 A/CNAME，撞 `100117`；路由由控制台管理 |
| `jwt_secret` | 明文 `[vars]` | 部署后 `wrangler secret put` 写成加密 secret | 明文在控制台可读、构建日志会打印 |
| 部署重试 | 无 | 10021 退避重试 4 次，仍失败则跳过 `[ai]` 降级 | CF 侧间歇性故障 |
| `wrangler.toml` | 模板 | 与上游完全一致 | 本地真实配置在 `wrangler.local.toml` |

## 四、同步上游

```bash
# 一键：fetch → 检查触碰点 → merge → 冲突分流 → 重新生成锁文件 → 验证
bash scripts/sync-upstream.sh
```

手动流程等价于：

```bash
git fetch upstream

# 1. 看上游改了哪些「我们也在改」的文件
git diff --name-only upstream/main..HEAD -- \
  mail-worker/src/email/email.js mail-worker/src/hono/webs.js \
  mail-vue/src/views/sys-setting/index.vue \
  mail-worker/wrangler.toml README.md

# 2. 合并（不要 rebase，历史上游不要重写）
git merge --no-ff upstream/main

# 3. 冲突分流
git checkout --theirs mail-worker/pnpm-lock.yaml    # 锁文件取上游
git checkout --theirs mail-worker/wrangler.toml     # 配置取上游
git checkout --theirs mail-vue/src/i18n/zh.js mail-vue/src/i18n/en.js
git rm .github/workflows/deploy-cloudflare.yml      # 上游新增/改动了这个文件时，保持删除
# 其余冲突逐个人工处理，用 `grep -n "fork:" <file>` 定位

# 4. 重新生成锁文件
cd mail-worker && npx pnpm@11 install --lockfile-only && npx pnpm@11 install --frozen-lockfile

# 5. 验证
npx vitest run --config vitest.unit.config.js   # 单测
cd ../mail-vue && npx vite build                # 前端
cd ../mail-worker && npx wrangler deploy --dry-run -c <替换过占位符的配置>
```

## 五、新增功能怎么做

以「再加一个通知渠道」为例：

1. **后端**：在 `mail-worker/src/plugins/notification/providers/` 加一个文件，导出带 `name` / `schema()` / `send()` 的类，在 `providers/index.js` 的数组里加一行。
2. **权限**：新路由若不在 `/notify/*` 下，在 `plugins/guard.js` 里加一行 `app.use('/你的前缀/*', requireAdminOrSettingPerm)`。
3. **前端**：UI 放进 `sys-setting/fork/` 下的组件；接口封装放 `mail-vue/src/plugins/`。
4. **文案**：只改 `mail-vue/src/i18n/fork/notify.zh.js` 与 `notify.en.js`，**不要动** `src/i18n/zh.js`、`en.js`。
5. **表结构**：插件自己 `CREATE TABLE IF NOT EXISTS`（懒建表），不要改上游 `src/init/init.js`。
6. **上游核心文件**：能不碰就不碰；必须碰时只加 1～2 行并写 `// fork:` 注释。

## 六、本地配置

`mail-worker/wrangler.toml` 保持上游模板不变（绑定全注释）。真实配置放同目录的 `wrangler.local.toml`（已 gitignore），从 `wrangler.example.toml` 复制后填。

```bash
cd mail-worker
pnpm run deploy:local      # wrangler deploy -c wrangler.local.toml
```

线上部署走 GitHub Actions（`.github/workflows/deploy-fork.yml`），配置来源是 GitHub 的 Variables/Secrets，详见 [deploy-github-actions.md](deploy-github-actions.md)。

> 不要用 `pnpm run deploy`（默认读 `wrangler.toml`）：模板里没有任何绑定，会把线上 D1/KV 绑定清空。

## 七、检查是否开始漂移

```bash
# 我们改过的上游文件，上游是否又动了
git log --oneline upstream/main --since="1 month ago" -- \
  mail-worker/src/email/email.js mail-vue/src/views/sys-setting/index.vue

# fork 代码里是否出现了对上游内部实现的新依赖（应为 0 或极少）
grep -rn "from '\.\./\.\./service" mail-worker/src/plugins/ | wc -l
```
