// Shared profiles.json reader for render.sh / validate.sh.
// Usage: node profile-dims.mjs <profiles.json path> <profile>
// Prints: "W H SCALE OW OH" (css dims, device scale factor, output pixels).
// Paths/names arrive as argv — never shell-interpolated into JS source.
import { readFileSync } from 'node:fs';

const [file, profile] = process.argv.slice(2);
if (!file || !profile) {
  console.error('usage: profile-dims.mjs <profiles.json> <profile>');
  process.exit(1);
}
let profiles;
try {
  profiles = JSON.parse(readFileSync(file, 'utf8'));
} catch (e) {
  console.error(`ERROR: cannot read profiles file ${file}: ${e.message}`);
  process.exit(1);
}
const p = profiles[profile];
if (!p) {
  console.error(`unknown profile: ${profile}`);
  process.exit(1);
}
console.log(p.css[0], p.css[1], p.scale, p.out[0], p.out[1]);
