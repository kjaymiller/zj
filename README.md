# zj

A `gum`-powered fuzzy switcher for [zellij](https://zellij.dev). One keystroke to jump to:

- an **active local session** (cyan),
- a **zoxide-tracked directory** — opens/creates a session there (blue), or
- a **remote web session** over zellij's web server (magenta), e.g. `https://zellij.kjaymiller.dev/homelab`.

Remote sessions are attached with `zellij attach <url> --token …`. The token is resolved through [fnox](https://github.com/jdx/fnox), which can serve it straight from 1Password.

## Install

Tools are managed with [mise](https://mise.jdx.dev):

```sh
mise install      # zellij, zoxide, gum, fnox
mise run install  # symlink ./zj -> ~/.local/bin/zj
```

(`mise run uninstall` removes the symlink.)

## Configure

### Remote sessions

List remote web-session URLs, one per line:

```sh
mkdir -p ~/.config/zj
cp remotes.example ~/.config/zj/remotes
$EDITOR ~/.config/zj/remotes
```

Override the location with `$ZJ_REMOTES_FILE`.

### Token (fnox + 1Password)

`zj` fetches the remote auth token via `fnox get ZELLIJ_WEB_TOKEN`. Point fnox at
your 1Password item (see `fnox.toml` for a template) so the token is served on
demand. If fnox has no value, `zj` prompts and offers to cache it back into fnox.

Override the secret name with `$ZJ_TOKEN_KEY`.

### CA certificate (homelab TLS)

If your remote server uses a custom CA, point `zj` at the cert so TLS verification
passes:

```sh
export ZJ_CA_CERT="$HOME/.config/zj/ca.pem"
```

When unset (or the file is missing), `zj` attaches without `--ca-cert`.

## How it works

| Selection            | Action                                                                 |
|----------------------|------------------------------------------------------------------------|
| `http(s)://…` URL     | `zellij attach <url> --token <fnox> --remember [--ca-cert <ZJ_CA_CERT>]` |
| active session       | attach (or hot-switch via the `zellij-switch` plugin when already inside zellij) |
| directory            | create/attach a session named after the directory, opened there        |

## Environment variables

| Variable           | Default                                  | Purpose                              |
|--------------------|------------------------------------------|--------------------------------------|
| `ZJ_REMOTES_FILE`  | `${XDG_CONFIG_HOME:-~/.config}/zj/remotes` | Remote session URL list            |
| `ZJ_TOKEN_KEY`     | `ZELLIJ_WEB_TOKEN`                       | fnox secret name for the token       |
| `ZJ_CA_CERT`       | _(unset)_                                | CA cert path for remote TLS          |
