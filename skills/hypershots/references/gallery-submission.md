# Gallery submission — getting a set featured on hypershots.dev

Featured sets appear in the gallery at https://hypershots.dev with the app's icon,
name, and a link back to the app. Submission is via a GitHub issue; a maintainer
reviews and merges. Nothing is published automatically.

`<ws>` = your workspace (default `.shots`).

## The permission rule (non-negotiable)

Submitting publishes the user's app name, icon, screenshots, and link on someone
else's website and in a public GitHub issue. So:

1. **Only offer after a set has shipped or the user is clearly done** — never
   mid-iteration.
2. **Ask explicitly** and show exactly what would be posted (the images, the
   name, the link, the story line) BEFORE filing anything.
3. **"No" ends it.** Don't re-offer in the same session. Never file the issue,
   open the URL, or stage the content without a clear yes.
4. The user must own the rights to everything submitted (the issue form makes
   them confirm this — don't check it on their behalf; it's their attestation).

## What to prepare (on yes)

- **Panels or contact sheet**: the validated PNGs from `out/<profile>/<locale>/`
  (or the review-page screenshot / `magick montage` contact sheet).
- **App icon**: ~512px PNG of the app's real icon (the gallery shows it on the
  set's filter chip and header).
- **Store link** (or website if not live yet).
- **One-line story**: e.g. "brief to store-ready in one agent session".

## How to file

Open the pre-filled template and let the user attach/confirm in their browser:

    https://github.com/hypersocialinc/hypershots/issues/new?template=featured-set.yml

Or, if `gh` is authenticated AND the user prefers it filed for them, `gh issue
create --repo hypersocialinc/hypershots --title "[featured] <app>" --body ...`
with the same fields — but images still upload most easily via the browser form,
so default to opening the URL.

## What happens next

A maintainer reviews the issue, and on approval adds the set to the site's
gallery data. The set then appears with its carousel, chip, and backlink.
Turnaround is human-speed; the issue is the status channel.
