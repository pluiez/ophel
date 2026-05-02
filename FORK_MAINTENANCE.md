# Fork Maintenance Guide

这个 fork 用于个人维护一组**不打算上游 PR** 的私改。文档目标：未来从上游同步变更时，看一遍这份文档就能不踩坑地完成一轮发布。

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
https://github.com/pluiez/ophel/raw/v1.0.44-personal-1/dist/ophel.user.js
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
git tag -a v<上游 tag>-personal-<N> -m "Personal fork release N atop upstream v<上游 tag>"
git push origin v<上游 tag>-personal-<N>
```

> 提示：`pnpm sync:upstream` 会 fetch + 显示 main/personal 与上游的关系，但**不会**自动 rebase（rebase 涉及冲突解决，必须人工把关）。它的作用只是省去手动跑 fetch + log 的步骤。

---

## 私改 commits 清单（按 rebase 后期望的顺序）

| 顺序 | 类型          | 主题                                                                  | 触及的核心文件                                                                                                                                                                 |
| ---- | ------------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1    | fix(prompts)  | remove enter-key hijacking on chat input                              | `src/contents/main.ts` 等                                                                                                                                                      |
| 2    | fix(options)  | drop empty prompts tab from features page                             | `src/tabs/options/pages/FeaturesPage.tsx`                                                                                                                                      |
| 3    | feat(sidebar) | hide auto-snapped panel fully off-screen with configurable peek width | `src/style.css`, `src/utils/storage.ts`, `src/components/MainPanel.tsx`, `src/tabs/options/pages/GeneralPage.tsx`, `src/locales/{zh-CN,en}/index.ts`, `src/components/App.tsx` |
| 4    | build         | point userscript asset CDN at fork                                    | `src/platform/userscript/resource-manifest.ts`（一行）                                                                                                                         |

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

### 2. 不要在 git worktree 里执行 commit

环境的签名服务（`/tmp/code-sign`）在 worktree 里会 hard-fail：

```
signing operation failed: signing server returned status 400: missing source
```

不论 commit 大小、不论是否 orphan、不论 parent 是真实 commit 还是空——只要在 worktree 里就失败。

**变通**：直接在主仓库切分支操作。如果担心污染工作树，用 `git stash push -m "wip" -- <files>` 暂存当前改动，切到目标分支处理，再切回来 `git stash pop`。

### 3. `dist/` 在 .gitignore 里，commit 需要 `-f`

`dist/ophel.user.js` 是构建产物，`.gitignore` 排除了整个 `dist/`。每次 add 都需要 `git add -f dist/ophel.user.js`。**不要修改 .gitignore**（其他构建场景仍依赖排除规则）。

### 4. lint-staged 在 dist 上跑 prettier 的 `[FAILED]` 提示无害

每次 commit dist 时 lint-staged 会显示：

```
[FAILED] dist
[FAILED] hint: Use -f if you really want to add them.
```

这是 prettier 改了 minified 文件后试图 re-stage 但被 .gitignore 拦截，**实际写入 commit 的还是 `git add -f` 时的原始 build 输出**。已用 hash 比对验证多次。无需理会。

### 5. 跨语言 i18n 字段不强制要求齐全

新增 i18n key 时只补 `zh-CN/index.ts` 和 `en/index.ts` 即可。其他 8 种语言通过 `t()` 的英文回退兜底，不会引发 runtime 错误。如果哪天某个其他语言出现裸 i18n key，再单独补。

### 6. Tampermonkey 不会因为 `@version` 没变就跳过更新

userscript 的 `@version` 字段沿用上游版本号，每次发布都不递增。Tampermonkey 在用户手动从 URL 安装时通常会强制覆盖，但**如果调试时不确定装的是哪一版**：

- 在 Tampermonkey 编辑器里搜 `panel-snap-peek` 或其他 trim 标记字符串，能搜到 → 是当前版本
- 搜不到 → 装的是更早的版本，需要手动卸载再重装

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
