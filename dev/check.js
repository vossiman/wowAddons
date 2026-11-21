#!/usr/bin/env node
// Checks every addon in the repo: Lua syntax, .toc file list, and stray globals.
// Usage: node dev/check.js   (run dev/setup.sh once first)
const fs = require("fs");
const path = require("path");

const root = path.resolve(__dirname, "..");
let luaparse;
try {
  luaparse = require(path.join(root, ".devtools", "node_modules", "luaparse"));
} catch {
  console.error("luaparse missing: run dev/setup.sh first");
  process.exit(2);
}

// Globals WoW itself expects addons to define.
const ALLOWED_PREFIXES = ["SLASH_", "BINDING_HEADER_", "BINDING_NAME_"];
let failures = 0;
const fail = (msg) => { failures++; console.log("  FAIL " + msg); };

const addons = fs.readdirSync(root).filter((d) => fs.existsSync(path.join(root, d, d + ".toc")));
for (const addon of addons) {
  const dir = path.join(root, addon);
  console.log(addon);
  const toc = fs.readFileSync(path.join(dir, addon + ".toc"), "utf8").split(/\r?\n/)
    .map((l) => l.trim()).filter((l) => l && !l.startsWith("#"));
  for (const f of toc) if (!fs.existsSync(path.join(dir, f))) fail(`.toc lists ${f}, which does not exist`);

  const luaFiles = fs.readdirSync(dir).filter((f) => f.endsWith(".lua"));
  for (const f of luaFiles) if (!toc.includes(f)) fail(`${f} is not listed in the .toc, so the game never loads it`);

  const prefix = addon.toLowerCase();
  for (const f of luaFiles) {
    try {
      luaparse.parse(fs.readFileSync(path.join(dir, f), "utf8"), {
        luaVersion: "5.1", scope: true,
        onCreateNode(n) {
          const names = [];
          if (n.type === "AssignmentStatement")
            for (const v of n.variables) if (v.type === "Identifier" && v.isLocal === false) names.push(v.name);
          if (n.type === "FunctionDeclaration" && !n.isLocal && n.identifier && n.identifier.type === "Identifier")
            names.push(n.identifier.name);
          for (const name of names) {
            const ok = name.toLowerCase().startsWith(prefix) || ALLOWED_PREFIXES.some((p) => name.startsWith(p));
            if (!ok) fail(`${f}:${n.loc ? n.loc.start.line : "?"} writes global "${name}" (missing "local"?)`);
          }
        },
        locations: true,
      });
    } catch (e) {
      fail(`${f}: ${e.message}`);
    }
  }
  console.log(`  ${luaFiles.length} Lua files checked`);
}
console.log(failures ? `${failures} problem(s)` : "all good");
process.exit(failures ? 1 : 0);
