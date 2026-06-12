# zj

![zj session picker in a floating window](https://jmblogstorrage.blob.core.windows.net/media/zj-ac64196a.png)

An `fzf`-powered fuzzy switcher for [zellij](https://zellij.dev). One keystroke to jump to:

- an **active local session** (cyan),
- a **zoxide-tracked directory** — opens/creates a session there (blue),
- a **remote web session** over zellij's web server (magenta), e.g. `https://zellij.kjaymiller.dev/homelab`, or
- a **GitHub repo** for any owner/org you list (green, shown as `gh:owner/repo`) — clones it on demand, then opens a session there.

Remote sessions are attached with `zellij attach <url> --token …`. The token is resolved through [fnox](https://github.com/jdx/fnox), which can serve it from an [age](https://github.com/FiloSottile/age)-encrypted store.

Watch the video below for a walkthrough on how to use it

[![ZJ in Action](https://i.ytimg.com/vi/h2kwzpY5-sA/hqdefault.jpg?sqp=-oaymwE2CNACELwBSFXyq4qpAygIARUAAIhCGAFwAcABBvABAfgBkAmAAtAFigIMCAAQARhPIFYoZTAP&rs=AOn4CLAkBs2oSOKvrScj3u4LmgIxj0M2yQ)](https://youtu.be/h2kwzpY5-sA)

## Documentation

Full docs live in [`docs/`](docs/), organized in the [Diátaxis](https://diataxis.fr) style:

- **[Tutorial](docs/tutorial.md)** — learn `zj` from a clean machine to your first session.
- **[How-to guides](docs/how-to/)** — [remote sessions](docs/how-to/remote-sessions.md), [GitHub orgs](docs/how-to/github-orgs.md), and [troubleshooting](docs/how-to/troubleshooting.md).
- **[Reference](docs/reference.md)** — env vars, config files, and the dispatch table.
- **[Explanation](docs/explanation.md)** — how the picker and dispatch work, and why.

The rest of this README is a quick-start; the docs go deeper.

## Install

### With the install script (macOS / Linux)

No mise or package manager required — `install.sh` symlinks `zj` and installs any
missing tools by downloading the prebuilt binaries straight from each project's
GitHub releases:

```sh
./install.sh                # install missing dependencies + symlink zj
./install.sh --with-fnox    # also install fnox (optional; age-backed tokens)
./install.sh --symlink-only # just symlink zj, leave dependencies alone
./install.sh --uninstall    # remove the symlink
```

It installs into `~/.local/bin` by default; override with `ZJ_BIN_DIR`. The
required tools are `zellij`, `zoxide`, `fzf`, and `gh`; tools already on your
`PATH` are left untouched. Binaries are matched to your OS/arch automatically
(macOS and Linux, x86_64 and arm64); set `GITHUB_TOKEN` to avoid the
unauthenticated GitHub API rate limit.

`fnox` is **optional** and is not installed unless you pass `--with-fnox` — it's
only used to resolve tokens from an age-encrypted store (see below). Without it, `zj` prompts
for the remote token and the GitHub listing uses `gh`'s own auth.

## Configure

`zj` reads its config from `~/.config/zj` (or `$XDG_CONFIG_HOME/zj`): the `orgs`
and `remotes` files live there. The install script seeds both from the bundled
examples on first run (it never overwrites files you've already edited), so after
`./install.sh` you can just edit `~/.config/zj/orgs` and `~/.config/zj/remotes`.

### Remote sessions

List remote web-session URLs, one per line, in `~/.config/zj/remotes`:

```sh
$EDITOR ~/.config/zj/remotes   # seeded from remotes.example by install.sh
```

If the file isn't there (e.g. `--symlink-only`), create it:

```sh
mkdir -p ~/.config/zj
cp remotes.example ~/.config/zj/remotes
```

Override the location with `$ZJ_REMOTES_FILE`.

### GitHub repos

List the GitHub owners/orgs whose repos you want in the picker, one login per
line, in `~/.config/zj/orgs`:

```sh
$EDITOR ~/.config/zj/orgs   # seeded from orgs.example by install.sh
```

If the file isn't there, create it:

```sh
mkdir -p ~/.config/zj
cp orgs.example ~/.config/zj/orgs
```

`zj` fetches every repo owned by those logins in a **single** GitHub GraphQL call
(via `gh`, which must be installed and authenticated — `gh auth login`) and shows
each as `gh:owner/repo`. The results are cached for `ZJ_GH_CACHE_TTL` minutes
(default 60) so the picker stays instant.

Selecting a `gh:` entry clones the repo into `$ZJ_REPOS_DIR` (default `~/projects`)
if it isn't there yet, then opens a session named after the repo (cloning slugs
with `gh repo clone`).

#### Repos not in your orgs

To grab a one-off repo that isn't owned by a configured org, pass its GitHub URL
(or `owner/repo` slug) straight to `zj` — it clones and opens it exactly like a
`gh:` pick, no config needed:

```sh
zj https://github.com/zellij-org/zellij      # https URL
zj git@github.com:zellij-org/zellij.git      # ssh URL
zj zellij-org/zellij                         # owner/repo slug
```

`https://`/`git@` GitHub URLs are recognized as repos to clone; any other
`https://` argument is treated as a remote web session.

Override the owners file with `$ZJ_ORGS_FILE` and the clone base dir with
`$ZJ_REPOS_DIR`. GraphQL caps results at 100 repos per owner.

By default the GraphQL query uses `gh`'s own login. To authenticate it with a
specific token instead, stash one in fnox under `GH_API_TOKEN` (a classic PAT or
fine-grained token with `repo`/read access) — `zj` exports it as `GH_TOKEN` for
the call. Override the secret name with `$ZJ_GH_TOKEN_KEY`. When fnox has no
value, `gh`'s normal auth (or an existing `$GH_TOKEN`) is used.

### Token (fnox + age)

`zj` fetches the remote auth token via `fnox get ZELLIJ_WEB_TOKEN`. Configure a
fnox provider backed by [age](https://github.com/FiloSottile/age) (`fnox provider
add …`) so the token is served on demand. If fnox has no value, `zj` prompts and
offers to cache it back into fnox.

Override the secret name with `$ZJ_TOKEN_KEY`.

### CA certificate (homelab TLS)

If your remote server uses a custom CA, point `zj` at the cert so TLS verification
passes:

```sh
export ZJ_CA_CERT="$HOME/.config/zj/ca.pem"
```

When unset (or the file is missing), `zj` attaches without `--ca-cert`.

## How it works

`zj` with no arguments opens the picker; `zj <target>` skips the picker and acts
on `<target>` directly (handy for a repo that isn't in your configured orgs).
Either way, the selection/argument is dispatched as:

| Selection / argument | Action                                                                 |
|----------------------|------------------------------------------------------------------------|
| `gh:owner/repo`       | clone into `$ZJ_REPOS_DIR` if needed, then open a session there         |
| GitHub repo URL / slug | `https://github.com/owner/repo`, `git@github.com:owner/repo`, or a bare `owner/repo` slug — clone if needed, then open a session there |
| other `http(s)://…` URL | `zellij attach <url> --token <fnox> --remember [--ca-cert <ZJ_CA_CERT>]` (remote web session); when already inside zellij it's hosted in (or switched to) a dedicated local session named after the URL, rather than hijacking the current pane |
| active session       | attach (or hot-switch via `zellij action switch-session` when already inside zellij) |
| directory            | create/attach a session named after the directory, opened there        |

## Launching from a keybinding (floating pane)

When you run `zj` from inside zellij, bind it to a **floating pane** so the picker
overlays your current layout and tears itself down the moment you pick something.
Add this to your zellij config (`~/.config/zellij/config.kdl`):


```kdl
keybinds {
    locked {
        bind "Ctrl y" {
            SwitchToMode "Normal"
            Run "zj" {
                floating true
                close_on_exit true
            }
        }
    }
}
```

Keep this alongside the `shared_except "locked"` block above if you want the key
to work in every mode: `shared_except` covers the unlocked modes, and the `locked`
block adds the unlock-then-run behavior for that one mode.


## Environment variables

| Variable           | Default                                  | Purpose                              |
|--------------------|------------------------------------------|--------------------------------------|
| `ZJ_REMOTES_FILE`  | `${XDG_CONFIG_HOME:-~/.config}/zj/remotes` | Remote session URL list            |
| `ZJ_TOKEN_KEY`     | `ZELLIJ_WEB_TOKEN`                       | fnox secret name for the token       |
| `ZJ_CA_CERT`       | _(unset)_                                | CA cert path for remote TLS          |
| `ZJ_ORGS_FILE`     | `${XDG_CONFIG_HOME:-~/.config}/zj/orgs`    | GitHub owners/orgs to list repos for |
| `ZJ_REPOS_DIR`     | `~/projects`                             | Base dir repos are cloned into       |
| `ZJ_GH_LIMIT`      | `200`                                    | Max repos fetched per owner (GraphQL caps at 100) |
| `ZJ_GH_CACHE_TTL`  | `60`                                     | Minutes to cache repo lists (`0` disables) |
| `ZJ_GH_TOKEN_KEY`  | `GH_API_TOKEN`                           | fnox secret name for the GitHub GraphQL token |


## Acknowledgements

- This project is heavily built off Claude Code prompts
- This project was entirely inspired by [Sesh](https://github.com/joshmedeski/sesh)
