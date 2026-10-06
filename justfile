server_dir := "/srv/minecraft/drakonixvanilla"
backup_dir := "/srv/minecraft/backups"
service := "minecraftserver-drakonixvanilla"
unit := "systemd/" + service + ".service"
rcon_port := "25578"
game_port := "25568"
mc_version := "26.3"
server_jar_url := "https://piston-data.mojang.com/v1/objects/33680f5f2ac32864d6d7cf5e56a705fdb3e05f4c/server.jar"
server_jar_sha1 := "33680f5f2ac32864d6d7cf5e56a705fdb3e05f4c"

default:
    @just --list

# create the segregated `minecraft` user + /srv/minecraft
setup-user:
    sudo bash scripts/setup-user.sh

# fetch the official vanilla server jar for the pinned version (once per
# version - filename is version-specific so bumping mc_version re-fetches
# automatically), then verify it against the pinned sha1
fetch-server-jar:
    #!/usr/bin/env bash
    set -euo pipefail
    jar="minecraft-server-{{mc_version}}.jar"
    if [ ! -f "$jar" ]; then
        curl -fsSL -o "$jar" "{{server_jar_url}}"
    fi
    echo "{{server_jar_sha1}}  $jar" | sha1sum -c -

# deploy the vanilla server jar + run.sh to /srv/minecraft/drakonixvanilla.
# Never touches world/, logs, or operator-edited runtime state (server.properties,
# whitelist.json, ops.json, ban lists, user/usernamecache) once they exist, so a
# routine redeploy (to bump the pinned Minecraft version) can't wipe the world
# or clobber settings added on the live server.
# Writes eula.txt=true - only run this if you (the operator) have accepted
# https://www.minecraft.net/eula.
deploy: fetch-server-jar
    sudo mkdir -p "{{server_dir}}"
    sudo install -m 644 "minecraft-server-{{mc_version}}.jar" "{{server_dir}}/server.jar"
    sudo install -m 755 scripts/run.sh "{{server_dir}}/run.sh"
    sudo test -f "{{server_dir}}/server.properties" || sudo install -m 644 server.properties "{{server_dir}}/server.properties"
    sudo chown -R minecraft:minecraft "{{server_dir}}"
    printf -- '-Xmx2G\n-Xms2G\n' | sudo tee "{{server_dir}}/user_jvm_args.txt" >/dev/null
    printf 'eula=true\n' | sudo tee "{{server_dir}}/eula.txt" >/dev/null
    sudo chown minecraft:minecraft "{{server_dir}}/user_jvm_args.txt" "{{server_dir}}/eula.txt"
    sudo install -m 644 "{{unit}}" /etc/systemd/system/{{service}}.service
    sudo systemctl daemon-reload

# install/update whitelist.json on the deployed server, then reload it live
install-whitelist:
    sudo install -m 644 whitelist.json "{{server_dir}}/whitelist.json"
    sudo chown minecraft:minecraft "{{server_dir}}/whitelist.json"
    python3 scripts/rcon.py --port {{rcon_port}} whitelist reload

# install + enable the daily world backup timer (midnight, keeps last 10).
# Re-run this any time scripts/backup.sh, the backup service/timer unit, or
# the backup sudoers rule change - it's the one recipe that (re)installs all
# of them, so it's always safe to just re-run after editing any of those.
setup-backups:
    sudo install -m 755 scripts/backup.sh /usr/local/bin/minecraftserverbackup-drakonixvanilla.sh
    sudo install -m 644 scripts/rcon.py /usr/local/bin/rcon.py
    sudo install -m 644 systemd/minecraftserverbackup-drakonixvanilla.service /etc/systemd/system/minecraftserverbackup-drakonixvanilla.service
    sudo install -m 644 systemd/minecraftserverbackup-drakonixvanilla.timer /etc/systemd/system/minecraftserverbackup-drakonixvanilla.timer
    sudo install -m 440 systemd/minecraft-backup-sudoers /etc/sudoers.d/minecraft-backup-drakonixvanilla
    sudo visudo -c
    sudo systemctl daemon-reload
    sudo systemctl enable --now minecraftserverbackup-drakonixvanilla.timer

# Gamerules live in the world's level.dat, not server.properties, so this
# recipe is their "template" - re-run it after a fresh world or restore-world.
# Idempotent. Reads rcon.password from the live server.properties via sudo.
# apply the curated difficulty + gamerules to the live world over RCON
apply-gamerules:
    #!/usr/bin/env bash
    set -euo pipefail
    for cmd in "difficulty easy" "gamerule keep_inventory true" "gamerule mob_griefing false"; do
        sudo sed -n 's/^rcon.password=//p' "{{server_dir}}/server.properties" \
            | python3 scripts/rcon.py --port {{rcon_port}} --password-file /dev/stdin $cmd
    done

enable:
    sudo systemctl enable {{service}}

start:
    sudo systemctl start {{service}}

stop:
    sudo systemctl stop {{service}}

restart:
    sudo systemctl restart {{service}}

status:
    systemctl status {{service}}

# interactive RCON console (prompts for rcon.password from server.properties)
rcon:
    python3 scripts/rcon.py --port {{rcon_port}}

# check the game port is actually up and accepting connections (Server List Ping)
ping host="127.0.0.1" port=game_port:
    python3 scripts/mcping.py --host {{host}} --port {{port}}

# DESTRUCTIVE: force a chunk to regenerate (wipes it). Stop the server first, take a backup.
# region_dir defaults to the overworld; pass world/DIM-1/region (nether) or world/DIM1/region (the end) for other dimensions.
delete-chunk chunk_x chunk_z region_dir=(server_dir + "/world/region"):
    sudo python3 scripts/delete-chunk.py --region-dir "{{region_dir}}" {{chunk_x}} {{chunk_z}}

# restore world/ from a backup tar.gz - renames the current world/ aside first (doesn't delete it). Stop the server first.
restore-world backup_file:
    sudo bash -c '[ -d "{{server_dir}}/world" ] && mv "{{server_dir}}/world" "{{server_dir}}/world.pre-restore-$(date +%Y%m%d-%H%M%S)"' || true
    sudo tar -C "{{server_dir}}" -xzf "{{backup_file}}" world
    sudo chown -R minecraft:minecraft "{{server_dir}}/world"

logs:
    journalctl -u {{service}} -f

# list world backups on disk, newest first, with sizes
list-backups:
    ls -lht "{{backup_dir}}"

# storage stats: current world size, backup dir total size + count, disk free space
storage-stats:
    @echo "world size ({{server_dir}}/world):"
    du -sh "{{server_dir}}/world"
    @echo "backups ({{backup_dir}}):"
    du -sh "{{backup_dir}}"
    @ls "{{backup_dir}}"/*.tar.gz 2>/dev/null | wc -l | xargs echo "  count:"
    @echo "disk free:"
    df -h "{{backup_dir}}"
