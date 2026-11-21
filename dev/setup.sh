#!/usr/bin/env bash
# Installs the dev tools (Lua parser) into .devtools/, which git ignores.
set -euo pipefail
cd "$(dirname "$0")/.."
command -v node >/dev/null || { echo "node is required (https://nodejs.org)"; exit 1; }
npm install --prefix .devtools --no-save --no-audit --no-fund --silent luaparse@0.3.1
echo "dev tools ready in .devtools/. Run: node dev/check.js"
