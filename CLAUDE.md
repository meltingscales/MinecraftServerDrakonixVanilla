# CLAUDE.md

Starter context for an AI agent working in this repo.

## What this is

A plain **vanilla** Minecraft server (no mods, no packwiz pack) for Milo, who
is learning Minecraft, plus friends. It's one of several Minecraft servers
hosted on the same box, following the same justfile/systemd/scripts pattern
as its sibling repos:

- `~/Git/MinecraftModpackDrakonixTechPack` - modded, packwiz-based
- `~/Git/MinecraftServerLiminalIndustries` - modded, CurseForge-zip-based
- `~/Git/MinecraftServerSpeedBuizModded` - modded, CurseForge-zip-based

When changing the hosting infra here (justfile recipes, systemd units,
scripts), check whether the same change should apply to those siblings too -
they were cloned from each other and have drifted only where their packaging
differs (packwiz vs. zip vs. plain vanilla jar).

## Audience matters

This server is for a kid learning the game, not a tech-savvy SMP crowd. Bias
towards boring and safe:

- Keep `white-list=true` / `enforce-whitelist=true` in `server.properties` -
  never suggest opening it up as a public/open server.
- `pvp=false` and `difficulty=easy` are deliberate starting defaults, not
  placeholders - don't "fix" them without being asked.
- Don't add gameplay-altering commands/datapacks/cheats without asking first
  - the point is vanilla survival, not giving Milo infinite diamonds.
- Treat `delete-chunk` and `restore-world` as destructive: confirm with the
  operator (Henry) before running either, same as the Claude Code default.

## Host conventions (shared across all Minecraft repos on this box)

- Server lives at `/srv/minecraft/<name>`, owned by a shared `minecraft`
  system user (`just setup-user`).
- systemd unit naming: `minecraftserver-<name>`,
  `minecraftserverbackup-<name>` (+ matching `.timer`). `<name>` here is
  `drakonixvanilla`.
- Each server gets a unique game-port/RCON-port pair so they can coexist -
  see the table in README.md. **Before adding a new sibling server, check
  `/etc/systemd/system/minecraftserver-*.service` on the host** (or grep
  `game_port`/`rcon_port` across the sibling justfiles) to avoid a collision;
  don't just guess the next number without checking.
- `scripts/backup.sh`, `scripts/rcon.py`, `scripts/mcping.py`,
  `scripts/delete-chunk.py`, `scripts/setup-user.sh` are near-identical
  across repos (only names/ports differ) - if you're fixing a bug in one,
  check whether it exists in the sibling copies too.
- RCON passwords and `whitelist.json`/`ops.json` are never committed - they
  go on the live server only (see README.md's Whitelist section).

## Version bumps

Vanilla doesn't use packwiz/NeoForge installers - just Mojang's own server
jar, pinned in the `justfile` (`mc_version`, `server_jar_url`,
`server_jar_sha1`). To bump: fetch
[version_manifest_v2.json](https://launchermeta.mojang.com/mc/game/version_manifest_v2.json),
find the target version's per-version manifest, pull `downloads.server.url`/
`.sha1` from it, update the three `justfile` variables, run `just deploy`.
Also check `javaVersion.majorVersion` in that manifest against the host's
installed JDKs (`/usr/lib/jvm/`) before bumping - a newer Minecraft version
can require a newer Java than the host has.

## No CI / no client distribution

Unlike `MinecraftModpackDrakonixTechPack`, there's no `.github/workflows/`
release pipeline and no client package to publish - vanilla players just use
the stock Minecraft launcher pointed at the server IP, nothing to install.
Don't add a release workflow here unless the project actually grows a reason
to (e.g. a shared resource pack or datapack bundle worth distributing).
