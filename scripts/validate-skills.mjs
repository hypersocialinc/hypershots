#!/usr/bin/env node
// Validate every skills/<name>/SKILL.md so a malformed frontmatter can never
// silently drop a skill from the installer's list again.
//
// The `npx skills` installer parses each SKILL.md's YAML frontmatter with
// gray-matter and SKIPS any skill whose frontmatter fails to parse — with no
// error. This check parses with the same library and fails loudly instead.
//
// Run: node scripts/validate-skills.mjs   (needs gray-matter on the path)

import { readFileSync, readdirSync, existsSync, statSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

let matter;
try {
  const mod = await import("gray-matter");
  matter = mod.default ?? mod;
} catch {
  console.error(
    "FATAL: gray-matter is not installed. Run `npm install gray-matter` " +
      "first (CI installs it before running this script)."
  );
  process.exit(2);
}

const repoRoot = join(dirname(fileURLToPath(import.meta.url)), "..");
const skillsDir = join(repoRoot, "skills");

const errors = [];
let checked = 0;

for (const entry of readdirSync(skillsDir).sort()) {
  const dir = join(skillsDir, entry);
  if (!statSync(dir).isDirectory()) continue;

  const skillPath = join(dir, "SKILL.md");
  const rel = `skills/${entry}/SKILL.md`;

  if (!existsSync(skillPath)) {
    errors.push(`${rel}: missing SKILL.md`);
    continue;
  }
  checked++;

  const raw = readFileSync(skillPath, "utf8");

  let data;
  try {
    // Same parse the installer does. A throw here = the skill is silently dropped.
    data = matter(raw).data;
  } catch (e) {
    errors.push(
      `${rel}: frontmatter failed to parse -> ${e.message.split("\n")[0]}. ` +
        `A common cause is an unquoted ': ' (colon-space) in 'description' — ` +
        `wrap the value in double quotes or remove the colon-space.`
    );
    continue;
  }

  if (!data || typeof data !== "object" || Array.isArray(data)) {
    errors.push(`${rel}: frontmatter did not parse to a mapping (is the '---' block present?)`);
    continue;
  }
  if (typeof data.name !== "string" || !data.name.trim()) {
    errors.push(`${rel}: missing or empty 'name'`);
  } else if (data.name !== entry) {
    errors.push(
      `${rel}: 'name: ${data.name}' must match the directory name '${entry}'`
    );
  }
  if (typeof data.description !== "string" || !data.description.trim()) {
    errors.push(`${rel}: missing or empty 'description'`);
  }
}

if (errors.length) {
  console.error(`\n✖ Skill frontmatter validation failed (${errors.length} problem(s)):\n`);
  for (const err of errors) console.error(`  - ${err}`);
  console.error("");
  process.exit(1);
}

console.log(`✓ All ${checked} skill frontmatters are valid.`);
