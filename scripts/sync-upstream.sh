#!/usr/bin/env bash
#
# 同步上游 cloud-mail 到当前 fork 分支
#
#   bash scripts/sync-upstream.sh            # fetch + 检查 + merge + 分流冲突 + 重新生成锁文件
#   bash scripts/sync-upstream.sh --check    # 只看上游动了哪些「我们也改过的文件」，不做任何写入
#   bash scripts/sync-upstream.sh --verify   # 合并后再跑单测 / 前端构建 / dry-run
#
set -uo pipefail

REMOTE="upstream"
BRANCH="main"
VERIFY=0
CHECK_ONLY=0

for arg in "$@"; do
	case "$arg" in
		--check) CHECK_ONLY=1 ;;
		--verify) VERIFY=1 ;;
		*) echo "未知参数: $arg"; exit 1 ;;
	esac
done

cd "$(dirname "$0")/.." || exit 1

# 我们自己也改过的上游文件（见 doc/fork-maintenance.md）
TOUCHPOINTS=(
	"mail-worker/src/email/email.js"
	"mail-worker/src/hono/webs.js"
	"mail-vue/src/views/sys-setting/index.vue"
	"mail-vue/src/i18n/zh.js"
	"mail-vue/src/i18n/en.js"
	"mail-worker/wrangler.toml"
	"mail-worker/pnpm-lock.yaml"
	"README.md"
	"README-en.md"
)

# 冲突时直接取上游版本的文件
THEIRS=(
	"mail-worker/pnpm-lock.yaml"
	"mail-worker/wrangler.toml"
	"mail-vue/src/i18n/zh.js"
	"mail-vue/src/i18n/en.js"
)

info() { printf '\033[36m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
err()  { printf '\033[31m%s\033[0m\n' "$*"; }

info "==> 拉取 $REMOTE ..."
git fetch "$REMOTE" || {
	err "fetch 失败。常见原因："
	echo "    · SSH 22 端口不可用 → GIT_SSH_COMMAND='ssh -p 443 -o HostName=ssh.github.com' bash scripts/sync-upstream.sh"
	echo "    · remote 未配置 → git remote add upstream https://github.com/maillab/cloud-mail.git"
	exit 1
}

BEHIND=$(git rev-list --count "HEAD..$REMOTE/$BRANCH")
info "==> 上游领先 $BEHIND 个提交"

info "==> 上游近期改动的「共享文件」："
FOUND=0
for f in "${TOUCHPOINTS[@]}"; do
	N=$(git log --oneline "HEAD..$REMOTE/$BRANCH" -- "$f" | wc -l | tr -d ' ')
	if [ "$N" != "0" ]; then
		printf '    %-46s %s 个提交\n' "$f" "$N"
		FOUND=1
	fi
done
[ "$FOUND" = "0" ] && echo "    （无，合并应当零冲突）"

if [ "$CHECK_ONLY" = "1" ]; then
	exit 0
fi

if [ "$BEHIND" = "0" ]; then
	info "==> 已是最新，无需合并"
	exit 0
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
	err "工作区有未提交改动，先提交或 stash 再同步"
	exit 1
fi

info "==> 合并 $REMOTE/$BRANCH ..."
if git merge --no-ff "$REMOTE/$BRANCH" -m "合入上游 $REMOTE/$BRANCH"; then
	info "==> 合并完成，无冲突"
else
	warn "==> 有冲突，按规则分流："
	for f in "${THEIRS[@]}"; do
		if git diff --name-only --diff-filter=U | grep -qx "$f"; then
			git checkout --theirs -- "$f"
			git add "$f"
			echo "    取上游版本: $f"
		fi
	done

	# 上游会持续改自己的部署工作流，本仓库用的是 deploy-fork.yml
	if git diff --name-only --diff-filter=U | grep -qx ".github/workflows/deploy-cloudflare.yml"; then
		git rm -q ".github/workflows/deploy-cloudflare.yml" 2>/dev/null || rm -f ".github/workflows/deploy-cloudflare.yml"
		git add -A ".github/workflows/deploy-cloudflare.yml" 2>/dev/null
		echo "    保持删除: .github/workflows/deploy-cloudflare.yml"
	fi

	REMAIN=$(git diff --name-only --diff-filter=U)
	if [ -n "$REMAIN" ]; then
		err "==> 仍有冲突需要人工处理："
		echo "$REMAIN" | sed 's/^/    /'
		echo
		echo "    提示：用 grep -n \"fork:\" <文件> 找本仓库标记；处理完执行 git add <文件> && git commit"
		exit 1
	fi
	git commit -q -m "合入上游 $REMOTE/$BRANCH" && info "==> 冲突已按规则解决并提交"
fi

info "==> 重新生成 pnpm-lock.yaml ..."
( cd mail-worker && npx --yes pnpm@11 install --lockfile-only >/dev/null 2>&1 \
	&& npx --yes pnpm@11 install --frozen-lockfile >/dev/null 2>&1 \
	&& echo "    ✅ 锁文件已更新，frozen-lockfile 校验通过" ) \
	|| warn "    ⚠️ 锁文件更新失败，手动执行：cd mail-worker && pnpm install --lockfile-only"

if [ "$VERIFY" = "1" ]; then
	info "==> 单测 ..."
	( cd mail-worker && npx vitest run --config vitest.unit.config.js ) || warn "    单测失败"
	info "==> 前端构建 ..."
	( cd mail-vue && npx vite build --outDir .build-check --emptyOutDir >/dev/null 2>&1 \
		&& rm -rf .build-check && echo "    ✅ 构建通过" ) || warn "    构建失败"
fi

info "==> 完成。建议先本地起服务验证，再推送："
echo "    git push origin patched"
