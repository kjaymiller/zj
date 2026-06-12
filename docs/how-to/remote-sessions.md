# How to set up remote web sessions

Goal: have a remote zellij web server show up in the picker (magenta) and attach
to it with one keystroke, with the auth token resolved automatically.

## 1. List the remote URL

Add each remote web-session URL, one per line, to `~/.config/zj/remotes`:

```sh
$EDITOR ~/.config/zj/remotes
```

```
https://zellij.example.dev/homelab
```

If the file doesn't exist yet (e.g. you installed with `--symlink-only`):

```sh
mkdir -p ~/.config/zj
cp remotes.example ~/.config/zj/remotes
```

Override the location with `$ZJ_REMOTES_FILE` if you keep it elsewhere.

## 2. Provide the token

`zj` attaches with `zellij attach <url> --token …` and resolves the token via
`fnox get ZELLIJ_WEB_TOKEN`.

**Option A — let fnox serve it (recommended).** Configure a fnox provider backed
by [age](https://github.com/FiloSottile/age) so the token is served on demand:

```sh
fnox provider add …       # set up your age-backed provider
```

**Option B — type it once and cache it.** If fnox has no value, `zj` prompts for
the token at attach time and offers to cache it back into fnox's global config
(`~/.config/fnox/config.toml`) so later runs from any directory find it.

Override the secret name with `$ZJ_TOKEN_KEY`.

## 3. (If using a custom CA) point zj at the cert

When your remote server uses a custom CA, TLS verification will fail unless `zj`
knows the cert. Point it at the PEM:

```sh
export ZJ_CA_CERT="$HOME/.config/zj/ca.pem"
```

When `ZJ_CA_CERT` is unset or the file is missing, `zj` attaches without
`--ca-cert`.

## 4. Attach

Open the picker and select the magenta remote entry, or pass the URL directly:

```sh
zj https://zellij.example.dev/homelab
```

When you run this from inside zellij, `zj` hosts the remote in its own sibling
session and switches you to it rather than hijacking your current pane. See the
[explanation](../explanation.md#remote-sessions-and-the-dead-shell-problem) for
why.

Hitting an error? See [troubleshooting](troubleshooting.md).
