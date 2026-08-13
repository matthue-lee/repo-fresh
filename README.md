# repo-fresh

Keep a set of git repos quietly up to date. **repo-fresh** fast-forwards a list
of repositories to their upstreams on a schedule, so you never open a project to
find your local branch is 40 commits behind.

- Read-only-safe: it only ever runs `git fetch` + `git merge --ff-only`. It
  never commits, resets, switches branches, or forces — and it **skips** any repo
  that has uncommitted changes or can't cleanly fast-forward.
- Runs as a lightweight per-user background job. **No sudo**, no app, no menu-bar
  icon, no network beyond git itself.
- Great for git **worktrees** checked out on deployed branches, mirrors you read
  but don't edit, or any clone you want current without thinking about it.

## Install (macOS)

**Homebrew — easiest:**

```bash
brew install matthue-lee/tap/repo-fresh
```

Then track some repos and start the daily sweep:

```bash
repo-fresh add ~/code/my-project
repo-fresh add ~/code/some-worktree
brew services start repo-fresh     # activate: runs daily at 07:00
repo-fresh run                     # or fast-forward everything right now
repo-fresh status                  # tracked repos + last-run summary
```

The Homebrew install runs on a fixed **daily 07:00** schedule. Want a different
hour or an interval? Use the from-source install below **instead of** Homebrew —
pick one method, not both (two schedulers would double up).

<details>
<summary><strong>From source</strong> (no Homebrew, or you want to choose the schedule)</summary>

```bash
git clone https://github.com/matthue-lee/repo-fresh.git
cd repo-fresh
./install.sh
```

`install.sh` asks how often to run — a **daily hour** or an **interval in
minutes** — and sets up the LaunchAgent itself (no `brew services` needed):

```bash
# non-interactive equivalents
SCHEDULE=daily    HOUR=7      ./install.sh
SCHEDULE=interval MINUTES=60  ./install.sh
```

> If the installer warns that `~/.local/bin` isn't on your `PATH`, add
> `export PATH="$HOME/.local/bin:$PATH"` to your `~/.zshrc` and restart the shell.

</details>

## Commands

| Command | What it does |
|---|---|
| `repo-fresh add <path>`    | Add a git repo/worktree to the list (validated). |
| `repo-fresh remove <path>` | Stop tracking a repo. |
| `repo-fresh list`          | Show each repo's branch and how far ahead/behind it is. |
| `repo-fresh status`        | Schedule + repo list + the most recent run. |
| `repo-fresh run`           | Fast-forward everything now (also written to the log). |

## How it works

`install.sh` sets up a per-user **LaunchAgent**
(`~/Library/LaunchAgents/com.local.repo-fresh.plist`) that, on your chosen
schedule, runs the worker script. For each repo in your list the worker:

1. skips it if the working tree is dirty (leaves your changes untouched);
2. skips it if the branch has no upstream;
3. runs `git fetch`, then `git merge --ff-only @{u}`;
4. logs the result — `up to date`, `updated abc123 -> def456`, or
   `not fast-forwardable` (which means a real merge/rebase is needed and only you
   should decide how).

Everything lives under `~/Library/Application Support/repo-fresh/` (the repo
list, a small config, and `repo-fresh.log`). Because it fast-forwards only, the
worst it can ever do is nothing.

## A note on credentials

A scheduled job runs headless. If your remotes use **HTTPS with the macOS
keychain**, fetches just work. If you use an **SSH key with a passphrase** that
isn't loaded into a persistent agent, the scheduled fetch may fail —
`repo-fresh run` will show that immediately, and the log records
`FETCH FAILED` when it happens.

## Alternatives & prior art

repo-fresh isn't a new idea — "pull my repos on a schedule" is well-trodden
ground. It aims to be the *smallest, safest, dependency-free* take. Reach for
something else if it fits you better:

- **[`git maintenance`](https://git-scm.com/docs/git-maintenance)** (built into
  git) — `git maintenance start` schedules background tasks via launchd/systemd,
  and its `prefetch` task fetches hourly. But prefetch only updates
  `refs/prefetch/*`; it deliberately **does not fast-forward your local
  branch**. Use it to keep fetches/`gc` cheap — not to keep your working copy
  current.
- **[autogitpull](https://github.com/supermarsx/autogitpull)** — closest cousin:
  scans a directory of repos, pulls on a schedule, skips dirty trees, with a TUI.
  More features; ships a binary.
- **[Auto-Pull](https://nightwalkax.github.io/auto-pull/)** — per-repo refresh
  intervals, aimed at SSH servers / continuous deployment.
- **[gitup / git-up](https://pypi.org/project/gitup/)** — updates many repos at
  once with smart handling of dirty/diverged/detached states, but you run it
  manually (no scheduler).
- **[myrepos (mr)](https://myrepos.branchable.com/)**,
  **[gita](https://github.com/nosarthur/gita)** — general multi-repo managers
  that run any command across repos; not background fresheners.
- **VS Code `git.autofetch`** / **GitHub Desktop auto-fetch** — *fetch* (not
  merge), and only while the app is open.

**Where repo-fresh fits:** fast-forward-**only** by contract (never merges,
resets, or forces — skips anything that can't cleanly fast-forward), a single
Bash script with **no runtime dependencies**, and per-directory branch detection
that plays nicely with **git worktrees** checked out on deployed branches.

## Uninstall

```bash
./uninstall.sh
```

Removes the agent, worker, command, and support files. Your repositories are
never touched.

## License

MIT — see [LICENSE](LICENSE).
