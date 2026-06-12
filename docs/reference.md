# Reference

Information-oriented lookup for `zj`. For learning, see the
[tutorial](tutorial.md); for tasks, the [how-to guides](how-to/); for the
reasoning behind these choices, the [explanation](explanation.md).

## Invocation

```sh
zj                 # open the fuzzy picker over all sources
zj <target>        # skip the picker and act on <target> directly
```

`<target>` may be a GitHub repo URL/slug, a remote web-session URL, an active
session name, or a directory. See [Dispatch](#dispatch) for how each is handled.

## Configuration files

`zj` reads config from `$XDG_CONFIG_HOME/zj` (default `~/.config/zj`). The
install script seeds both files from the bundled `*.example` files on first run
and never overwrites edits.

| File | Purpose | Format |
|------|---------|--------|
| `remotes` | Remote zellij web-session URLs offered in the picker | one URL per line; `#` comments and blank lines ignored |
| `orgs` | GitHub owners/orgs whose repos appear as `gh:owner/repo` | one login per line; `#` comments and blank lines ignored |

## Environment variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `ZJ_REMOTES_FILE` | `${XDG_CONFIG_HOME:-~/.config}/zj/remotes` | Remote session URL list |
| `ZJ_TOKEN_KEY` | `ZELLIJ_WEB_TOKEN` | fnox secret name for the remote token |
| `ZJ_CA_CERT` | _(unset)_ | CA cert (PEM) path for remote TLS; passed as `--ca-cert` when set and present |
| `ZJ_ORGS_FILE` | `${XDG_CONFIG_HOME:-~/.config}/zj/orgs` | GitHub owners/orgs to list repos for |
| `ZJ_REPOS_DIR` | `~/projects` | Base dir repos are cloned into and new projects scaffolded under |
| `ZJ_GH_LIMIT` | `200` | Max repos fetched per owner (GraphQL caps at 100) |
| `ZJ_GH_CACHE_TTL` | `60` | Minutes to cache repo lists (`0` disables) |
| `ZJ_GH_TOKEN_KEY` | `GH_API_TOKEN` | fnox secret name for the GitHub GraphQL token |

Other paths `zj` uses:

| Path | Purpose |
|------|---------|
| `${XDG_CACHE_HOME:-~/.cache}/zj/repos` | Cached `gh:owner/repo` list (see `ZJ_GH_CACHE_TTL`) |
| `~/.config/fnox/config.toml` | Where a cached token is written (`fnox set --global`) |

## Picker sources and colors

The no-argument picker merges these sources, deduplicates, and color-codes them:

| Source | Color | Entry shape |
|--------|-------|-------------|
| Active local zellij sessions | cyan | session name |
| zoxide-tracked directories | blue | directory path |
| Configured remote web sessions | magenta | URL |
| GitHub repos for configured orgs | green | `gh:owner/repo` |

In the picker: `Enter` on a match opens it; type a new name and `Enter` to create it; `Esc`/`Ctrl-c` cancels.

## Dispatch

Whether it comes from a picker selection, a typed query, or an explicit argument,
the target is dispatched in this order:

| Target | Action |
|--------|--------|
| `gh:owner/repo` | clone into `$ZJ_REPOS_DIR` if needed, then open a session there |
| GitHub repo URL/slug (`https://github.com/owner/repo`, `git@github.com:owner/repo`, `owner/repo`) | clone if needed, then open a session there |
| other `http(s)://…` URL | attach as a remote web session with the fnox token (`--remember`, plus `--ca-cert` when `ZJ_CA_CERT` is set) |
| active session name | attach, or hot-switch (`switch-session`) when already inside zellij |
| existing directory | create/attach a session named after the directory, rooted there |
| unmatched typed query | scaffold a new slugified project dir under `$ZJ_REPOS_DIR` and open it |

A bare `owner/repo` is ambiguous (repo to clone vs. nested dir to create). As an
explicit argument it clones; as an unmatched picker query `zj` asks which you meant.

## Required external tools

| Tool | Used for |
|------|----------|
| `zellij` | sessions (local and remote attach) |
| `fzf` | the fuzzy picker |
| `zoxide` | tracked-directory source |
| `gh` | listing org repos (GraphQL) and cloning |
| `fnox` _(optional)_ | resolving the remote token and GitHub token from an age-backed store |
