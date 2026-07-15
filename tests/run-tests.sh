#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
R=skills/hypershots/scripts/render.sh
V=skills/hypershots/scripts/validate.sh
WS=tests/fixture
rm -rf "$WS/out" "$WS/profile.css" "$WS"/t11-* "$WS"/t14-* "$WS/panels-t16"

echo "== T1: render at iphone-6.9 =="
bash "$R" "$WS" iphone-6.9 en

echo "== T2: exact dims + no alpha =="
png="$WS/out/iphone-6.9/en/panel-1.png"
node -e "
  const b=require('fs').readFileSync('$png');
  const w=b.readUInt32BE(16),h=b.readUInt32BE(20),ct=b[25];
  if(w!==1290||h!==2796){console.error('dims '+w+'x'+h);process.exit(1)}
  if(ct===4||ct===6){console.error('PNG has alpha (colortype '+ct+')');process.exit(1)}
  console.log('dims 1290x2796, colortype '+ct+' (no alpha) OK')"

echo "== T3: boxes dump exists + fit ran =="
node -e "
  const j=require('./$WS/out/iphone-6.9/en/panel-1.boxes.json');
  if(!j.boxes.find(b=>b.name==='device'))throw new Error('no device box');
  if(!j.boxes.find(b=>b.name==='copy'))throw new Error('no copy box');
  if(j.fitFailures.length)throw new Error('unexpected fit failure');
  if(j.panelW!==430||j.panelH!==932)throw new Error('panel dims '+j.panelW+'x'+j.panelH);
  console.log('boxes:',j.boxes.map(b=>b.name).join(','),'OK')"

echo "== T4: validator passes the good render =="
bash "$V" "$WS" iphone-6.9 en

echo "== T5: validator fails a wrong-size PNG =="
# tiny valid PNG via node zlib (crc32 in node >=20.11), else magick fallback,
# else an explicit failure — never a silent skip.
rc5=0
node -e "
  const z=require('zlib'),fs=require('fs');
  if(typeof z.crc32!=='function'){process.exit(42)}
  const chunk=(t,d)=>{const l=Buffer.alloc(4);l.writeUInt32BE(d.length);
    const c=Buffer.concat([Buffer.from(t),d]);
    const cc=Buffer.alloc(4);cc.writeUInt32BE(z.crc32(c)>>>0);
    return Buffer.concat([l,c,cc])};
  const ihdr=Buffer.alloc(13);ihdr.writeUInt32BE(100,0);ihdr.writeUInt32BE(100,4);ihdr[8]=8;ihdr[9]=2;
  const row=Buffer.concat([Buffer.from([0]),Buffer.alloc(300,200)]);
  const idat=z.deflateSync(Buffer.concat(Array(100).fill(row)));
  fs.writeFileSync('$WS/out/iphone-6.9/en/panel-9.png',Buffer.concat(
    [Buffer.from([137,80,78,71,13,10,26,10]),chunk('IHDR',ihdr),chunk('IDAT',idat),chunk('IEND',Buffer.alloc(0))]));" || rc5=$?
if [ "$rc5" -eq 42 ]; then
  if command -v magick >/dev/null 2>&1; then
    magick -size 100x100 xc:gray "$WS/out/iphone-6.9/en/panel-9.png"
  else
    echo "T5 FAILED: need node>=20.11 (zlib.crc32) or imagemagick to build the bad PNG"; exit 1
  fi
elif [ "$rc5" -ne 0 ]; then
  echo "T5 FAILED: bad-png generator exited $rc5"; exit 1
fi
if bash "$V" "$WS" iphone-6.9 en; then echo "T5 FAILED: validator accepted a 100x100 png"; exit 1
else echo "validator correctly rejected wrong-size png"; fi
rm "$WS/out/iphone-6.9/en/panel-9.png"

echo "== T6: fit failure fails the render with exit 2 =="
mkdir -p "$WS/panels-xx"
sed 's/data-fit-floor="24"/data-fit-floor="60"/' "$WS/panels/panel-1.html" > "$WS/panels-xx/panel-1.html"
rc=0; bash "$R" "$WS" iphone-6.9 xx || rc=$?
if [ "$rc" -eq 0 ]; then echo "T6 FAILED: render accepted an unfittable headline"; exit 1; fi
if [ "$rc" -ne 2 ]; then echo "T6c FAILED: expected exit code 2 (fit failure), got $rc"; exit 1; fi
echo "render correctly failed on fit floor (exit 2)"
echo "== T6b: fit-failed render leaves no PNG behind =="
if compgen -G "$WS/out/iphone-6.9/xx/panel-*.png" > /dev/null; then
  echo "T6b FAILED: orphan PNG left in $WS/out/iphone-6.9/xx"; exit 1
fi
if compgen -G "$WS/out/iphone-6.9/xx/panel-*.boxes.json*" > /dev/null; then
  echo "T6b FAILED: boxes.json left in $WS/out/iphone-6.9/xx"; exit 1
fi
echo "no orphan outputs after fit failure OK"
rm -rf "$WS/panels-xx" "$WS/out/iphone-6.9/xx"

echo "== T7: unknown profile fails without touching profile.css =="
printf 'sentinel\n' > "$WS/profile.css"
rc=0; bash "$R" "$WS" bogus en 2>"$WS/t7-err.txt" || rc=$?
if [ "$rc" -eq 0 ]; then echo "T7 FAILED: render accepted unknown profile"; exit 1; fi
grep -q "unknown profile: bogus" "$WS/t7-err.txt" || { echo "T7 FAILED: error does not name the bogus profile:"; cat "$WS/t7-err.txt"; exit 1; }
[ "$(cat "$WS/profile.css")" = "sentinel" ] || { echo "T7 FAILED: profile.css was rewritten for a bogus profile"; exit 1; }
rm "$WS/t7-err.txt" "$WS/profile.css"
echo "unknown profile rejected, workspace untouched OK"

echo "== T8: validator rejects a PNG with no boxes.json =="
cp "$WS/out/iphone-6.9/en/panel-1.png" "$WS/out/iphone-6.9/en/panel-8.png"
if bash "$V" "$WS" iphone-6.9 en; then echo "T8 FAILED: validator accepted a PNG without boxes.json"; exit 1
else echo "validator correctly rejected boxes-less png"; fi
rm "$WS/out/iphone-6.9/en/panel-8.png"

echo "== T9: alpha-flatten path (needs imagemagick) =="
if command -v magick >/dev/null 2>&1; then
  magick -size 1290x2796 xc:'rgba(200,200,200,0.5)' PNG32:"$WS/out/iphone-6.9/en/panel-7.png"
  printf '{"panelW":430,"panelH":932,"fitFailures":[],"boxes":[]}' > "$WS/out/iphone-6.9/en/panel-7.boxes.json"
  node -e "
    const b=require('fs').readFileSync('$WS/out/iphone-6.9/en/panel-7.png');
    if(b[25]!==6){console.error('T9 setup: expected colortype 6 (RGBA), got '+b[25]);process.exit(1)}"
  bash "$V" "$WS" iphone-6.9 en
  node -e "
    const b=require('fs').readFileSync('$WS/out/iphone-6.9/en/panel-7.png');
    const ct=b[25];
    if(ct===4||ct===6){console.error('T9 FAILED: still has alpha (colortype '+ct+') after validate');process.exit(1)}
    console.log('alpha flattened in place to colortype '+ct+' OK')"
  rm "$WS/out/iphone-6.9/en/panel-7.png" "$WS/out/iphone-6.9/en/panel-7.boxes.json"
else
  echo "SKIP T9: imagemagick not installed (flatten branch unexercised)"
fi

echo "== T10: translate-inject -> render es -> validate es =="
node skills/hypershots/scripts/translate-inject.mjs "$WS" es
bash "$R" "$WS" iphone-6.9 es
bash "$V" "$WS" iphone-6.9 es
rm -rf "$WS/panels-es" "$WS/out/iphone-6.9/es"
echo "translate-inject es round-trip OK"

echo "== T10b: translate-inject atomicity =="
# (a) missing key -> exit 1 AND zero html written (temp locale zz; es fixture untouched)
printf '{ "locale": "zz", "strings": { "p1.eyebrow": "X", "p1.headline": "Y" } }' > "$WS/strings.zz.json"
rc=0; node skills/hypershots/scripts/translate-inject.mjs "$WS" zz || rc=$?
[ "$rc" -eq 1 ] || { echo "T10b FAILED: missing-key inject exited $rc (want 1)"; exit 1; }
if compgen -G "$WS/panels-zz/*.html" > /dev/null; then
  echo "T10b FAILED: partial output written on missing-key failure"; exit 1
fi
rm -rf "$WS/strings.zz.json" "$WS/panels-zz"
# (b) stale-file purge: a leftover panel from a previous run must not survive
mkdir -p "$WS/panels-es"; printf 'stale' > "$WS/panels-es/panel-9.html"
node skills/hypershots/scripts/translate-inject.mjs "$WS" es
[ ! -e "$WS/panels-es/panel-9.html" ] || { echo "T10b FAILED: stale panel-9.html survived inject"; exit 1; }
rm -rf "$WS/panels-es"
echo "atomic output + stale purge OK"

echo "== T11: style-grade masks (make-mask.mjs) =="
if command -v magick >/dev/null 2>&1; then
  MM=skills/hypershots/scripts/make-mask.mjs
  # synthetic protect box — the fixture's real boxes + shadow pad cover the
  # WHOLE canvas (minimal panel), which would leave no transparency to assert
  printf '{"panelW":430,"panelH":932,"fitFailures":[],"boxes":[{"name":"device","x":100,"y":400,"w":200,"h":300}]}' > "$WS/t11-boxes.json"
  node "$MM" "$WS/t11-boxes.json" 1290 2796 3 "$WS/t11-mask.png" "$WS/t11-feather.png"
  read -r mw mh ma mo <<< "$(magick identify -format '%w %h %A %[opaque]' "$WS/t11-mask.png")"
  [ "$mw" = 1290 ] && [ "$mh" = 2796 ] || { echo "T11 FAILED: mask dims ${mw}x${mh}, want 1290x2796"; exit 1; }
  case "$ma" in True|Blend) ;; *) echo "T11 FAILED: mask has no alpha channel (%A=$ma)"; exit 1 ;; esac
  [ "$mo" = "False" ] || { echo "T11 FAILED: mask is fully opaque — no editable zone"; exit 1; }
  read -r fw fh fa <<< "$(magick identify -format '%w %h %A' "$WS/t11-feather.png")"
  [ "$fw" = 1290 ] && [ "$fh" = 2796 ] || { echo "T11 FAILED: feather dims ${fw}x${fh}, want 1290x2796"; exit 1; }
  case "$fa" in False|Undefined) ;; *) echo "T11 FAILED: feather carries alpha (%A=$fa)"; exit 1 ;; esac
  # feather must be a real ramp: black background -> white protect zone
  read -r fmin fmax <<< "$(magick "$WS/t11-feather.png" -format '%[fx:255*minima] %[fx:255*maxima]' info:)"
  [ "${fmin%.*}" = 0 ] && [ "${fmax%.*}" = 255 ] || { echo "T11 FAILED: feather min/max $fmin/$fmax, want 0/255"; exit 1; }
  echo "mask (RGBA, transparent edit zone) + feather (gray 0..255 ramp) OK"
  # T11b: real fixture boxes fully cover the canvas after padding — the mask
  # must STILL carry an alpha channel (PNG32 guard against IM's opaque-optimize)
  node "$MM" "$WS/out/iphone-6.9/en/panel-1.boxes.json" 1290 2796 3 "$WS/t11-mask.png" "$WS/t11-feather.png"
  ma2="$(magick identify -format '%A' "$WS/t11-mask.png")"
  case "$ma2" in True|Blend) ;; *) echo "T11b FAILED: fully-covered mask lost its alpha channel (%A=$ma2)"; exit 1 ;; esac
  echo "fully-covered mask keeps alpha channel OK"
  rm "$WS/t11-boxes.json" "$WS/t11-mask.png" "$WS/t11-feather.png"
else
  echo "SKIP T11: imagemagick not installed (mask generation unexercised)"
fi

echo "== T12: styled panels are spec-checked but don't count toward the cap =="
cp "$WS/out/iphone-6.9/en/panel-1.png" "$WS/out/iphone-6.9/en/panel-1.styled.png"
cp "$WS/out/iphone-6.9/en/panel-1.boxes.json" "$WS/out/iphone-6.9/en/panel-1.styled.boxes.json"
out12="$(bash "$V" "$WS" iphone-6.9 en)"
echo "$out12"
echo "$out12" | grep -q "PASS panel-1.png" || { echo "T12 FAILED: no PASS line for the clean panel"; exit 1; }
echo "$out12" | grep -q "PASS panel-1.styled.png" || { echo "T12 FAILED: styled panel was not spec-checked"; exit 1; }
echo "$out12" | grep -q "VALIDATED: 1 panels" || { echo "T12 FAILED: styled alternate counted toward the store cap"; exit 1; }
rm "$WS/out/iphone-6.9/en/panel-1.styled.png" "$WS/out/iphone-6.9/en/panel-1.styled.boxes.json"
echo "styled alternate validated without occupying a store slot OK"

echo "== T13: review page (make-review.mjs) =="
node skills/hypershots/scripts/translate-inject.mjs "$WS" es
bash "$R" "$WS" iphone-6.9 es
cp "$WS/out/iphone-6.9/en/panel-1.png" "$WS/out/iphone-6.9/en/panel-1.styled.png"
node skills/hypershots/scripts/make-review.mjs "$WS" iphone-6.9 en es
review="$WS/out/iphone-6.9/review.html"
[ -s "$review" ] || { echo "T13 FAILED: review.html not written"; exit 1; }
grep -q 'en/panel-1.png' "$review" || { echo "T13 FAILED: en panel missing from review"; exit 1; }
grep -q 'es/panel-1.png' "$review" || { echo "T13 FAILED: es panel missing from review"; exit 1; }
grep -q 'visible before' "$review" || { echo "T13 FAILED: fold-line label missing"; exit 1; }
grep -q 'styled-toggle' "$review" || { echo "T13 FAILED: styled toggle missing despite panel-1.styled.png"; exit 1; }
rm "$review" "$WS/out/iphone-6.9/en/panel-1.styled.png"
rm -rf "$WS/panels-es" "$WS/out/iphone-6.9/es"
echo "review page (both locales, fold label, styled toggle) OK"

echo "== T14: grade-set.sh degrades before any upload; edit-pass 6-arg contract intact =="
GS=skills/hypershots/scripts/grade-set.sh
EP=skills/hypershots/scripts/edit-pass.sh
# (a) PATH stripped of every dir that ships genmedia — grade-set must fail on
# its genmedia preflight, before a single upload/paid call could happen
CLEAN_PATH=""
IFS=':' read -ra t14_dirs <<< "$PATH"
for d in "${t14_dirs[@]}"; do
  [ -n "$d" ] && [ -x "$d/genmedia" ] && continue
  CLEAN_PATH="${CLEAN_PATH:+$CLEAN_PATH:}$d"
done
if PATH="$CLEAN_PATH" command -v genmedia >/dev/null 2>&1; then
  echo "T14 setup FAILED: genmedia still reachable on stripped PATH"; exit 1
fi
PATH="$CLEAN_PATH" command -v node >/dev/null 2>&1 || { echo "T14 setup FAILED: node lost from stripped PATH"; exit 1; }
rc=0; PATH="$CLEAN_PATH" bash "$GS" "$WS" iphone-6.9 en "test style" protected 2>"$WS/t14-err.txt" || rc=$?
[ "$rc" -ne 0 ] || { echo "T14 FAILED: grade-set succeeded without genmedia"; exit 1; }
grep -q "genmedia" "$WS/t14-err.txt" || { echo "T14 FAILED: failure is not the genmedia error:"; cat "$WS/t14-err.txt"; exit 1; }
if compgen -G "$WS/out/iphone-6.9/en/panel-*.styled.png" > /dev/null; then
  echo "T14 FAILED: styled output created despite missing genmedia"; exit 1
fi
echo "grade-set correctly refused without genmedia, no styled output OK"
# (b) 7th-arg support must not break 6-arg calls: a bogus workspace has to hit
# the "not rendered" check, not an argument-parsing error
rc=0; bash "$EP" "$WS-nonexistent" iphone-6.9 en panel-1 "test style" protected 2>"$WS/t14-err.txt" || rc=$?
[ "$rc" -ne 0 ] || { echo "T14 FAILED: edit-pass accepted a bogus workspace"; exit 1; }
grep -q "not rendered" "$WS/t14-err.txt" || { echo "T14 FAILED: 6-arg edit-pass call broke — expected 'not rendered', got:"; cat "$WS/t14-err.txt"; exit 1; }
rm "$WS/t14-err.txt"
echo "edit-pass 6-arg call unchanged (fails on 'not rendered', not args) OK"
# (c) full-canvas protection guard: the fixture's protect boxes cover the whole
# canvas after padding (see T11b), so a protected edit is a guaranteed paid
# no-op — edit-pass must refuse AFTER building the mask but BEFORE any genmedia
# upload. Stub genmedia proves no invocation happened.
if command -v magick >/dev/null 2>&1; then
  mkdir -p "$WS/t14-bin"
  printf '#!/bin/sh\ntouch "%s"\necho "T14c: genmedia was invoked" >&2\nexit 99\n' "$WS/t14-genmedia-invoked" > "$WS/t14-bin/genmedia"
  chmod +x "$WS/t14-bin/genmedia"
  rc=0; PATH="$(cd "$WS/t14-bin" && pwd):$PATH" bash "$EP" "$WS" iphone-6.9 en panel-1 "test style" protected 2>"$WS/t14-err.txt" || rc=$?
  [ "$rc" -ne 0 ] || { echo "T14c FAILED: edit-pass accepted a fully-protected canvas"; exit 1; }
  grep -q "no editable pixels" "$WS/t14-err.txt" || { echo "T14c FAILED: expected the no-editable-pixels error, got:"; cat "$WS/t14-err.txt"; exit 1; }
  [ ! -e "$WS/t14-genmedia-invoked" ] || { echo "T14c FAILED: genmedia was invoked before the coverage guard"; exit 1; }
  rm -rf "$WS/t14-bin" "$WS/t14-err.txt" "$WS/t14-genmedia-invoked"
  echo "fully-protected canvas refused before any upload OK"
else
  echo "SKIP T14c: imagemagick not installed (coverage guard unexercised)"
fi

echo "== T15: boxes dump carries shots; --grid render is quarantined =="
# (a) every clean render's boxes.json must carry a shots array (capture-region
# coordinates; empty here — the fixture screen is hand-built)
node -e "
  const j=require('./$WS/out/iphone-6.9/en/panel-1.boxes.json');
  if(!Array.isArray(j.shots))throw new Error('boxes.json missing shots array');
  console.log('shots key present ('+j.shots.length+' entries) OK')"
# (b) --grid outputs land in <locale>-grid, warn loudly, and differ from clean
before15="$(shasum "$WS/out/iphone-6.9/en/panel-1.png")"
out15="$(bash "$R" "$WS" iphone-6.9 en --grid)"
echo "$out15" | grep -q "GRID RENDER — not for upload" || { echo "T15 FAILED: grid warning not printed"; exit 1; }
gp="$WS/out/iphone-6.9/en-grid/panel-1.png"
[ -s "$gp" ] || { echo "T15 FAILED: grid render did not land in en-grid/"; exit 1; }
[ "$(shasum "$WS/out/iphone-6.9/en/panel-1.png")" = "$before15" ] || { echo "T15 FAILED: --grid render touched the normal en/ output"; exit 1; }
if cmp -s "$WS/out/iphone-6.9/en/panel-1.png" "$gp"; then
  echo "T15 FAILED: grid PNG identical to clean render — overlay not drawn"; exit 1
fi
# (c) validate on the normal dir still passes — the grid dir is invisible to it
bash "$V" "$WS" iphone-6.9 en
rm -rf "$WS/out/iphone-6.9/en-grid"
echo "shots dump + quarantined grid render OK"

echo "== T16: perspective preset (.device.tilt-l) renders + validates =="
mkdir -p "$WS/panels-t16"
sed 's/class="device"/class="device tilt-l"/' "$WS/panels/panel-1.html" > "$WS/panels-t16/panel-1.html"
grep -q 'class="device tilt-l"' "$WS/panels-t16/panel-1.html" || { echo "T16 setup FAILED: tilt-l class not injected"; exit 1; }
bash "$R" "$WS" iphone-6.9 t16
bash "$V" "$WS" iphone-6.9 t16
# boxes.json must still carry the device box (transformed bounds, not a miss)
node -e "
  const j=require('./$WS/out/iphone-6.9/t16/panel-1.boxes.json');
  const d=j.boxes.find(b=>b.name==='device');
  if(!d)throw new Error('no device box in tilted render');
  if(!(d.w>0&&d.h>0))throw new Error('degenerate device box '+JSON.stringify(d));
  console.log('tilted device box captured ('+Math.round(d.w)+'x'+Math.round(d.h)+') OK')"
rm -rf "$WS/panels-t16" "$WS/out/iphone-6.9/t16"
echo "tilt-l panel rendered + validated OK"

echo "ALL TESTS PASSED"
