# Submit gear — fastlane deliver

Push a validated HyperShots set to App Store Connect with `fastlane deliver` — no manual uploads, no dragging PNGs into a browser. This doc covers ONLY the deliver/screenshots half.

`<skill>` = installed skill dir, `<ws>` = your workspace (default `.shots`).

**Prerequisite:** a working fastlane install with App Store Connect API-key auth — the `asc_api_key` helper, `Appfile`, and the gitignored `.env.testflight.local`. That is the `ios-testflight-fastlane` skill's job (`npx skills add hypersocialinc/agent-skills --skill ios-testflight-fastlane`) — set it up there, do NOT rebuild it here. Also assumed: the app exists in ASC with an editable version ("Prepare for Submission" draft) — deliver writes into that draft.

## Order of operations

1. `validate.sh` green for every profile+locale you're shipping — FIRST. deliver does not check dims/alpha/ICC/count; ASC rejects late (mid-upload or at review), which is the expensive place to find out.
2. Copy `out/` → `fastlane/screenshots/<asc-locale>/` (below).
3. Run the lane.
4. Verify in ASC — open the version's media page and **count the screenshots per size per locale** (see gotchas).

## Screenshot directory mapping

deliver expects `fastlane/screenshots/<asc-locale>/*.png` (next to the Fastfile) and orders by **filename, alphabetically** — so zero-pad. Unpadded, `panel-10` sorts ahead of `panel-2` and your narrative arc ships scrambled. HyperShots outputs `out/<profile>/<locale>/panel-N.png`; copy + rename per locale:

```bash
ws=.shots; profile=iphone-6.9
src=en; asc=en-US                 # repeat per locale — mapping table below
dest=fastlane/screenshots/$asc
mkdir -p "$dest"
for n in 1 2 3 4 5 6 7 8 9 10; do
  p="$ws/out/$profile/$src/panel-$n.png"
  [ -f "$p" ] || continue
  cp "$p" "$dest/$(printf '%02d' "$n")-panel.png"
done
```

- **Exclude `*.styled.png`** — the glob above never matches them, which is correct: the clean render is the deliverable. If the user explicitly chose the styled variant for a panel, copy `panel-N.styled.png` AS that slot (`cp …/panel-3.styled.png "$dest/03-panel.png"`) — it replaces the clean panel, never ships alongside it, and must itself have passed `validate.sh` (edit-filter.md).
- **ASC locale codes ≠ the workspace's short codes.** The workspace uses `en`, `es`; ASC wants region-qualified codes for most languages:

| `<ws>` locale | ASC folder |
|---|---|
| `en` | `en-US` (also `en-GB`, `en-AU`, `en-CA` as separate listings) |
| `es` | `es-ES` or `es-MX` — pick the market you localized FOR |
| `fr` | `fr-FR` (or `fr-CA`) |
| `de` | `de-DE` |
| `pt` | `pt-BR` or `pt-PT` |
| `it` `ja` `ko` `tr` | same code, no region |
| `zh` | `zh-Hans` or `zh-Hant` |

Anything else: check ASC's own locale list (App Information → localizations) — a wrong folder name is silently skipped, not errored.

## The lane

Grounded in the shipped Spotless `deliver_metadata` lane (the one that actually pushed its set). Add to the Fastfile from the `ios-testflight-fastlane` setup — `asc_api_key` and `BUNDLE_ID` already exist there:

```ruby
desc "Push screenshots (+ optional text metadata) to the editable App Store version."
desc "Options: screenshots_only:true (skip text metadata — see first-version gotcha)"
lane :deliver_screenshots do |options|
  deliver(
    api_key: asc_api_key,
    app_identifier: BUNDLE_ID,
    screenshots_path: File.join(IOS_DIR, "fastlane", "screenshots"),
    metadata_path: File.join(IOS_DIR, "fastlane", "metadata"),
    skip_binary_upload: true,                 # the binary is the beta lane's job
    skip_metadata: options[:screenshots_only] ? true : false,
    overwrite_screenshots: true,              # replace the slot, don't append
    submit_for_review: false,                 # never auto-submit from this lane
    automatic_release: false,
    run_precheck_before_submit: false,
    precheck_include_in_app_purchases: false,
    force: true                               # skip the interactive HTML preview — runs unattended
  )
end
```

No Deliverfile needed — everything inline. Every option above is live in the Spotless Fastfile; don't add flags you haven't verified against `fastlane action deliver`.

**Gotchas (both hit on the shipped Spotless run):**

- **First-version metadata crash.** On an app's very first version, deliver's App-Review-information step (`review_attachment_file` upload) throws "No data" and aborts — text metadata uploads fine before it, screenshots after, so the run half-lands. Workaround: `fastlane deliver_screenshots screenshots_only:true` (screenshots land via skip_metadata), then either fill the text metadata by hand in ASC or re-run without the option once the version has review info saved.
- **Transient retry = duplicate screenshots.** A flaky upload that fastlane retried once created a duplicate panel in ASC. The cap is **10 per device size per locale** — one dup pushes an honest 10-panel set over and blocks submission. After every upload, open the version's media page and count; the fix is deleting the duplicate in ASC by hand (deliver won't reconcile it for you).

## One profile = one ASC display-size slot

`iphone-6.9` (1290×2796) fills the required 6.9″ slot — ASC infers the slot from pixel dimensions, and Apple auto-scales it down for smaller devices. Shipping an explicit 6.5″ rendition too means a **second render + copy pass**: `render.sh <ws> iphone-6.5 <locale>`, then copy those PNGs into the SAME locale folder with a size prefix so filenames don't collide (`65-01-panel.png` vs `01-panel.png`) — deliver routes each file to its slot by dimensions, not by name. Same story for `ipad-13`, which is additionally a separate authoring pass (store-specs.md).
