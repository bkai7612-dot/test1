#!/usr/bin/env bash
# Type-checks and lints all Luau source against Roblox API definitions.
# Requires `rojo` and `luau-lsp` on PATH (see rokit.toml).
set -euo pipefail
cd "$(dirname "$0")/.."

DEFS=".cache/globalTypes.d.luau"
if [ ! -f "$DEFS" ]; then
	mkdir -p .cache
	curl -sSL -o "$DEFS" \
		https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.PluginSecurity.d.luau
fi

rojo sourcemap default.project.json --output .cache/sourcemap.json
luau-lsp analyze \
	--definitions="@roblox=$DEFS" \
	--sourcemap=.cache/sourcemap.json \
	--no-strict-dm-types \
	src
