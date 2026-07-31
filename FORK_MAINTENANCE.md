# Fork Maintenance Guide

这个 fork 用于个人维护一组**不打算上游 PR** 的私改。文档目标：未来从上游同步变更时，看一遍这份文档就能不踩坑地完成一轮发布。

---

## 关于执行环境

这份文档假定**在普通 terminal 环境**执行 git 操作——你自己的电脑 shell、Claude Code CLI 终端、CI 等。所有命令都是标准 `git` / `pnpm` / `bash`，不依赖任何特殊运行时。

如果是在 **Claude Code on the web 沙箱**里跑，沙箱有几条安全限制会让特定步骤失败（git worktree commit、tag ref push、jsdelivr 直连验证）。这些**只在沙箱里出现**，普通 terminal 环境完全不会遇到。沙箱限制集中在底部"## 仅 Claude Code on the web 沙箱的限制"章节，正常环境可以整段忽略。

**判断当前环境**：在 shell 里看 `/tmp/code-sign` 是否存在——存在就是沙箱，不存在就是普通环境。

---

## 仓库分支结构

| 分支                | 用途                                                     | 操作约束                                        |
| ------------------- | -------------------------------------------------------- | ----------------------------------------------- |
| `main`              | 镜像上游 `urzeye/ophel` 的 main，**不放任何私改**        | 只允许 fast-forward 上游                        |
| `personal`          | 长期承载所有私改 commit，并发布 userscript 产物          | rebase 上游时允许 `git push --force-with-lease` |
| `userscript-assets` | jsdelivr CDN 资源仓库（i18n JSON、全局 CSS、图标、音频） | 只增不改、**永远不要 rebase 或 force push**     |
| `fix/*` / `feat/*`  | 偶尔分阶段开发或需要分期 review 时的临时分支             | 完工后 cherry-pick 进 `personal` 即可丢弃       |

旧的 `fix/sidebar-auto-hide-residual-edge`、`claude/*` 分支保留为历史，未来不再写入。

---

## Userscript 安装链接（GreasyFork 个人分发）

```
https://github.com/pluiez/ophel/raw/personal/dist/ophel.user.js
```

或者用 tag（推荐稳定版）：

```
https://github.com/pluiez/ophel/raw/v1.0.44-personal-2/dist/ophel.user.js
```

`personal` 分支链接内容随每次 rebase 变化；tag 链接内容永远固定。

---

## 日常工作流：上游推了新 commit 时

```bash
# 一次性配置：把上游加为 remote（如果还没加）
git remote add upstream https://github.com/urzeye/ophel.git

# === 每次同步流程 ===

# 1. 抓上游最新
git fetch upstream

# 2. fast-forward 自己 fork 的 main
git checkout main
git merge --ff-only upstream/main
git push origin main

# 3. rebase personal 到新 main 上
git checkout personal
git rebase upstream/main
#    冲突主要发生在：
#    - 站点 adapter（上游修 DOM 选择器时）
#    - i18n 字典（上游加新字段时与你的字段相邻）
#    - CSS（上游改面板样式时与你的修改重叠）
#    解决冲突后：
#      git add <files> && git rebase --continue

# 4. 验证编译 + 重新构建 userscript
pnpm install   # 仅当 package.json 有更新
pnpm typecheck
pnpm build:userscript

# 5. 检查 build 出来的资源 hash 是否变化
ls build/userscript/userscript-assets/
#    对比 jsdelivr 上现有的（看 dist/ophel.user.js 头部 @resource URL）。
#    如果有任意一个文件 hash 不一样 → 必须执行 step 6
#    否则跳到 step 7

# 6. 同步 userscript-assets 分支（仅当 step 5 有 hash 变化）
git checkout userscript-assets
cp -a build/userscript/userscript-assets/. userscript-assets/
git add userscript-assets/
git commit -m "build: publish userscript assets for v<新版本>"
git push origin userscript-assets    # 普通 push，不要 force
git checkout personal

# 7. 提交新的 userscript 产物到 personal
cp build/userscript/ophel.user.js dist/ophel.user.js
git add -f dist/ophel.user.js
git commit -m "build: rebuild userscript artifact for v<上游 tag>-personal-<N>"

# 8. force-push personal（commit hash 因 rebase 改变了）
git push --force-with-lease origin personal

# 9. 打稳定回滚 tag
#    沙箱注：Claude Code on the web 在这一步会 HTTP 403（见底部 S2），
#    需要你从普通 terminal 完成 push origin v<...>。
git tag -a v<上游 tag>-personal-<N> -m "Personal fork release N atop upstream v<上游 tag>"
git push origin v<上游 tag>-personal-<N>
```

> 提示：`pnpm sync:upstream` 会 fetch + 显示 main/personal 与上游的关系，但**不会**自动 rebase（rebase 涉及冲突解决，必须人工把关）。它的作用只是省去手动跑 fetch + log 的步骤。

---

## 私改 commits 清单（按 rebase 后期望的顺序）

| 顺序 | 类型          | 主题                                                                  | 触及的核心文件                                                                                                                                                                                                                                                               |
| ---- | ------------- | --------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1    | fix(prompts)  | remove enter-key hijacking on chat input                              | `src/contents/main.ts` 等                                                                                                                                                                                                                                                    |
| 2    | fix(options)  | drop empty prompts tab from features page                             | `src/tabs/options/pages/FeaturesPage.tsx`                                                                                                                                                                                                                                    |
| 3    | feat(sidebar) | hide auto-snapped panel fully off-screen with configurable peek width | `src/style.css`, `src/utils/storage.ts`, `src/components/MainPanel.tsx`, `src/tabs/options/pages/GeneralPage.tsx`, `src/locales/{zh-CN,en}/index.ts`, `src/components/App.tsx`                                                                                               |
| 4    | build         | point userscript asset CDN at fork                                    | `src/platform/userscript/resource-manifest.ts`（一行）                                                                                                                                                                                                                       |
| 5    | feat(claude)  | add one-click Usage panel to quick buttons                            | `src/adapters/base.ts`, `src/adapters/claude.ts`, `src/components/icons/UsageIcon.tsx`, `src/components/icons/index.ts`, `src/constants/ui.ts`, `src/components/QuickButtons.tsx`, `src/stores/settings-store.ts`, `src/utils/storage.ts`, `src/locales/{zh-CN,en}/index.ts` |
| 6    | fix(claude)   | restrict activation to /new and /chat/\* paths                        | `src/adapters/claude.ts`, `vite.userscript.config.ts`                                                                                                                                                                                                                        |

每次 rebase 后 commit hash 会变，但 subject 应保持稳定。新增私改 → 在这个表追加一行，并在 personal 分支上加 commit。

---

## 已知坑：不要再踩一次

### 1. @resource hash 变化必须同步 userscript-assets 分支

userscript 从 jsdelivr 加载 i18n、CSS、图标等资源，URL 写死指向 `pluiez/ophel@userscript-assets/userscript-assets/<file.<contentHash>.<ext>>`。

**触发条件**：任何对以下文件的改动都会让 vite-plugin-monkey 重新计算 content hash：

- `src/locales/<lang>/index.ts` → `ophel.locale.<lang>.<hash>.json`
- `src/style.css` → `ophel.user.<hash>.css`
- `src/utils/themes/**` → 间接影响 `ophel.user.css`
- 资源文件本身（`assets/icon.png`、音效文件等）

**症状**（资源没同步时）：

- i18n JSON 404 → 面板上所有可见文字变成原始 i18n key（"panelTitle" 而非 "Ophel"）
- CSS 404 → 面板没尺寸约束、占满屏幕、挤占主聊天区
- icon 没了样式支撑 → 退化为 Unicode 占位字符（☆、口、⊙）

**修复**：执行日常流程的 step 5 + step 6。

### 2. `dist/` 在 .gitignore 里，commit 需要 `-f`

`dist/ophel.user.js` 是构建产物，`.gitignore` 排除了整个 `dist/`。每次 add 都需要 `git add -f dist/ophel.user.js`。**不要修改 .gitignore**（其他构建场景仍依赖排除规则）。

### 3. lint-staged 在 dist 上跑 prettier 的 `[FAILED]` 提示无害

每次 commit dist 时 lint-staged 会显示：

```
[FAILED] dist
[FAILED] hint: Use -f if you really want to add them.
```

这是 prettier 改了 minified 文件后试图 re-stage 但被 .gitignore 拦截，**实际写入 commit 的还是 `git add -f` 时的原始 build 输出**。已用 hash 比对验证多次。无需理会。

### 4. 跨语言 i18n 字段不强制要求齐全

新增 i18n key 时只补 `zh-CN/index.ts` 和 `en/index.ts` 即可。其他 8 种语言通过 `t()` 的英文回退兜底，不会引发 runtime 错误。如果哪天某个其他语言出现裸 i18n key，再单独补。

### 5. Tampermonkey 不会因为 `@version` 没变就跳过更新

userscript 的 `@version` 字段沿用上游版本号，每次发布都不递增。Tampermonkey 在用户手动从 URL 安装时通常会强制覆盖，但**如果调试时不确定装的是哪一版**：

- 在 Tampermonkey 编辑器里搜 `panel-snap-peek` 或其他 trim 标记字符串，能搜到 → 是当前版本
- 搜不到 → 装的是更早的版本，需要手动卸载再重装

---

## 仅 Claude Code on the web 沙箱的限制

下面这些**只在 Claude Code 网页版的沙箱**里会出现。普通 terminal 环境（你自己的电脑、Claude Code CLI、CI）**不会遇到**，可以整段忽略。仅当你让 Claude Code on the web 的 agent 替你执行同步流程时，需要知道这些 corner case。

### S1. git worktree 里 commit 失败：signing server "missing source"

沙箱的 git 签名服务（`/tmp/code-sign`）在 worktree 里 hard-fail：

```
signing operation failed: signing server returned status 400: missing source
```

不论 commit 大小、是否 orphan、parent 是否真实——只要在 worktree 里就 fail。

**沙箱内的变通**：在主仓库 `git checkout` 切分支处理，需要保护工作树时用 `git stash push -m "wip" -- <files>` 收起当前改动。

**普通 terminal 环境**：worktree 是首选方式（不污染主工作树），可以正常用 `git worktree add` 干活，**不要照搬这个变通**。

### S2. tag ref push 返回 HTTP 403

沙箱的 git proxy 拒绝 `refs/tags/*` 写操作：

```
error: RPC failed; HTTP 403 curl 22 The requested URL returned error: 403
send-pack: unexpected disconnect while reading sideband packet
fatal: the remote end hung up unexpectedly
```

`refs/heads/*`（branch ref）push 正常，**只有 tag ref 被拦**。MCP github 工具也没有 create-tag/release 写接口可以绕过。

**变通**：让 Claude 完成所有源码改动 + branch push，最后由你从普通 terminal 跑一行：

```bash
git fetch origin
git checkout personal
git tag -a v<...>-personal-<N> <commit-sha> -m "..."
git push origin v<...>-personal-<N>
```

或者直接在 GitHub Web 界面 Releases 页面 "Draft a new release" 时输入 tag 名让 GitHub 创建。

### S3. 沙箱无法直接 curl 验证 jsdelivr / GitHub raw 之外的外部 URL

沙箱网络对很多 host 是 hard-block：

```
HTTP/2 403
x-deny-reason: host_not_allowed
```

具体已知会被拦的：`cdn.jsdelivr.net`、`raw.githubusercontent.com` 之类的纯 CDN/raw 域。`github.com` 的 git push/pull 通过专用 proxy 是工作的。

**影响**：沙箱里没法替你验证 "userscript-assets 推上去后 jsdelivr 镜像是否就绪"。

**变通**：从你自己的浏览器直接访问对应 jsdelivr URL，或者在普通 terminal 跑 `curl -I "https://cdn.jsdelivr.net/gh/pluiez/ophel@userscript-assets/userscript-assets/<file>"` 确认 200。

---

## 紧急回滚

如果某次发布出问题、需要回到上一个稳定版：

```bash
# 找上一个 tag
git tag -l 'v*-personal-*' --sort=-version:refname | head -3

# 把 dist 链接换成那个 tag 的（或者 force-reset personal 到该 tag）
git checkout personal
git reset --hard v<上游 tag>-personal-<N-1>
git push --force-with-lease origin personal
```

或者最简单：让用户在 Tampermonkey 装旧 tag 的 URL，等修好新版再发。

---

## 文档维护责任

**这份文档每次 rebase 完毕后都要确认与现实一致**。不一致的地方比一份过期文档更危险。重点检查：

- 私改 commits 清单（数量 + subject 顺序）
- 上游 tag / personal 编号是否走在最新
- 已知坑章节是否需要追加新坑
