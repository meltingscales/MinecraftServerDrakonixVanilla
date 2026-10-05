#!/usr/bin/env bash
# Vanilla server launcher. Unlike a Forge/NeoForge installer, plain vanilla
# doesn't generate its own run.sh, so this repo ships one: reads JVM
# memory/GC flags from user_jvm_args.txt (the @argfile syntax is a stock
# `java` feature, nothing vanilla-specific) and execs server.jar.
set -euo pipefail
cd "$(dirname "$0")"
exec java @user_jvm_args.txt -jar server.jar "$@"
