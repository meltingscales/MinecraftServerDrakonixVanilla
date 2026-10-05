# Drakonix Vanilla

A plain vanilla Minecraft server for Milo (learning Minecraft) and friends.
Hosting setup is a clone of the sibling `MinecraftModpackDrakonixTechPack` /
`MinecraftServerLiminalIndustries` repos (same justfile/systemd/scripts
pattern) - no packwiz pack here since there's no modpack, just the official
vanilla server jar.

## Server URL

TBD - set up a [playit.gg](https://playit.gg/) tunnel like the sibling
servers once it's time to let Milo connect from outside the LAN.

## What is this

- no `pack/` - vanilla has no mod list to track, just a pinned Minecraft
  version (`mc_version` in the `justfile`) and the official server jar,
  fetched straight from Mojang
- `justfile`, `systemd/`, `scripts/` - the infra to run it as a
  systemd-managed server with backups, RCON, and a whitelist (same pattern
  as the modded sibling repos)

## Quickstart

```
just setup-user                     # creates the minecraft system user + /srv/minecraft
just deploy                         # fetches the pinned vanilla server jar, installs it + run.sh to /srv/minecraft/drakonixvanilla, writes eula.txt=true
just enable                         # systemctl enable minecraftserver-drakonixvanilla
just start                          # systemctl start minecraftserver-drakonixvanilla
just status                         # confirm it's running
just setup-backups                  # install + enable the daily backup timer (keeps last 10)
```

`just deploy` writes `eula.txt=true` on your behalf - only run it once you've
accepted [Mojang's EULA](https://www.minecraft.net/eula) yourself, since
that's the operator's agreement to make, not something to accept silently.

**Redeploying is safe** - `just deploy` only ever installs `server.jar` and
`run.sh`, and only writes `server.properties` if one doesn't already exist on
the live server. `world/`, `whitelist.json`, `ops.json`, ban/user-cache
lists, and any hand-edited `server.properties` are left alone, so bumping
`mc_version` and redeploying won't wipe the world or clobber settings you've
changed live.

## Ports

Several Minecraft servers run on this same host. Each uses a distinct
game/RCON port pair so they can coexist:

| Server | Game port | RCON port |
|---|---|---|
| `buizmcmodded` (SpeedBuizModded) | 25565 | 25575 |
| `liminalindustries` | 25566 | 25576 |
| `drakonixtechpack` | 25567 | 25577 |
| **`drakonixvanilla` (this repo)** | **25568** | **25578** |

Check `/etc/systemd/system/minecraftserver-*.service` on the host (or the
sibling repos' justfiles) before picking a port for yet another server.

RCON isn't pre-configured (no secret gets committed to the repo). After the
first `just deploy` + `just start`, edit the live
`/srv/minecraft/drakonixvanilla/server.properties` and add:

```
enable-rcon=true
rcon.port=25578
rcon.password=<a-generated-secret>
```

then `just restart` to pick it up - RCON settings are only read at startup.
`just rcon` connects with `scripts/rcon.py`, prompting for the password
interactively.

## Version

Pinned to vanilla **`26.3`** (`mc_version`/`server_jar_url`/`server_jar_sha1`
in the `justfile`, sourced from Mojang's
[version manifest](https://launchermeta.mojang.com/mc/game/version_manifest_v2.json)).
To bump: look up the new version's `downloads.server.url`/`.sha1` in its
entry from that manifest, update the three `justfile` variables, then
`just deploy`.

Default server-side JVM heap is `-Xmx2G -Xms2G` (`user_jvm_args.txt`, written
by `just deploy`) - plenty for a handful of players on a plain vanilla world;
bump it by editing the `deploy` recipe if the world grows.

## Whitelist

`white-list=true` + `enforce-whitelist=true` are set in `server.properties`
(so this never accidentally runs as an open server). `whitelist.json` itself
is *not* tracked in git (it's a list of real players' Minecraft usernames) -
create one locally:

```json
[
  { "uuid": "...", "name": "Milo" }
]
```

then `just install-whitelist` to push it to the live server and reload it.
`ops.json` is similarly untracked - add operators by hand on the live server
(`/op <name>` via `just rcon`, or edit the file directly) rather than
committing it.

## Operating

```
just logs            # tail the systemd journal
just rcon             # interactive console
just ping             # liveness check (Server List Ping)
just list-backups      # see what's on disk
just storage-stats     # world/backup sizes, disk free space
just restore-world <backup.tar.gz>   # restore from a backup (stop the server first)
just delete-chunk <x> <z>            # DESTRUCTIVE - regenerate a single chunk
```
