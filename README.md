# davey.mywindowwashing.com

Static site for Davey's brand, published to GitHub Pages at
<https://davey.mywindowwashing.com>. Separate from `www.mywindowwashing.com`
and from that site's cPanel hosting — the only thing the two share is a DNS
zone.

Push to `main` and the live site updates. That's the whole workflow.

---

## Repository layout

```
img/                    put images here — copied to public/img/ on deploy
public/                 the website — everything in here is served
  index.html            /
  img/                  images, as served at /img/<filename>
  404.html              error page (not in the sitemap)
  robots.txt
  sitemap.xml           generated on deploy, do not edit by hand
  CNAME                 the custom domain, read by GitHub Pages
deploy/
  stage-images.sh       copies img/ into public/img/
  generate-sitemap.sh   rebuilds sitemap.xml from public/
  setup-vps.sh          VPS setup — unused while on Pages
  nginx/                VPS server config — unused while on Pages
.github/workflows/
  pages.yml             publishes public/ on every push to main
  deploy.yml            the VPS alternative, manual-run only
```

**Only `public/` is published.** Files outside it stay in the repo, with one
exception: the deploy copies `img/` into `public/img/` first, so images can be
uploaded to the top-level `img/` folder — the easiest place to reach from
GitHub's **Add file → Upload files** button.

Everything else goes in `public/`. A new page belongs at `public/about.html`,
not at the repository root — a stray `index.html` up there is not published.

### Adding images

Drop them in `img/`, using the exact filenames `public/index.html` references.
Names are case-sensitive on the server: `Photo.JPG` will not answer a request
for `photo.jpg`.

---

## Making a change

```bash
git add -A
git commit -m "Update the services page"
git push
```

Then watch the **Actions** tab on GitHub. A green check means it is live —
usually about 20 seconds. Hard-refresh the browser if you still see the old
page (Ctrl+Shift+R, or Cmd+Shift+R on a Mac).

Deleting a file here deletes it from the live site on the next push. The
deploy mirrors `public/` exactly rather than adding to what is already there.

---

## URL shapes

GitHub Pages serves `about.html` at `/about`, so link to pages **without** the
`.html`:

```html
<a href="/about">About</a>          <!-- yes -->
<a href="/about.html">About</a>     <!-- also 200, but see below -->
```

Unlike the nginx config in `deploy/`, Pages does **not** redirect the variants
onto one canonical form — `/about` and `/about.html` both return 200. That is
only an SEO problem if search engines find both, so:

- link internally to the extensionless form, consistently, and
- give every page a `<link rel="canonical">` naming that same form.

`public/index.html` already has its canonical tag. Getting this right in your
own links is what keeps one page from being indexed as two.

Use **root-relative** paths for images, CSS and links:

```html
<img src="/img/photo.jpg">     <!-- yes -->
<img src="img/photo.jpg">      <!-- breaks on any page below the root -->
```

---

## First-time setup

### 1. DNS

Add one record to the `mywindowwashing.com` zone:

| Type | Name | Value |
|---|---|---|
| CNAME | `davey` | `d-g-websites.github.io` |

Add only this record. Do not modify the existing `A` records for the apex or
`www` — those are what keep the main site pointed at cPanel. Nothing else in
the zone changes, and mail is unaffected.

Check it with:

```bash
dig +short davey.mywindowwashing.com
```

### 2. Enable Pages

The workflow tries to switch Pages on by itself. If the run fails saying Pages
is not enabled, set it by hand: **Settings → Pages → Source: GitHub Actions**.

### 3. Custom domain and HTTPS

`public/CNAME` already names the domain, so the deploy claims it. Once DNS
resolves, GitHub issues a Let's Encrypt certificate — usually minutes, but it
can take up to an hour on a first setup. Then tick **Enforce HTTPS** under
Settings → Pages.

Until DNS resolves the site is not reachable. This is expected: the page uses
root-relative paths (`/img/…`), which only work at the domain root, so there
is no useful preview at the `github.io` project URL.

### 4. Verify

Push to `main`, watch the Actions tab, then load
<https://davey.mywindowwashing.com>.

---

## Hosting on a VPS instead

`deploy/setup-vps.sh` and `deploy/nginx/` still work and are kept for the day
a VPS is wanted — for server-side code, custom response headers, or redirect
rules that Pages cannot express. Nothing in `public/` needs to change.

To switch: run `sudo ./deploy/setup-vps.sh` on the server, add the secrets it
prints (`SSH_PRIVATE_KEY`, `SSH_KNOWN_HOSTS`, `VPS_HOST`, `VPS_USER`,
`VPS_PATH`), restore the `push:` trigger in `.github/workflows/deploy.yml`,
and point DNS at the server with an `A` record instead of the CNAME.

## SEO notes

This subdomain is a separate site as far as search engines are concerned. It
inherits nothing from `www.mywindowwashing.com` — not its rankings, not its
links, not its Search Console property.

- **Add a separate Search Console property** for `davey.mywindowwashing.com`
  and submit `https://davey.mywindowwashing.com/sitemap.xml`.
- **Write original content.** Copying service or location pages from the main
  site produces two weak pages competing with each other instead of one strong
  one. This is the main thing to get right.
- **Give every page a unique `<title>`, `<meta name="description">` and
  `<link rel="canonical">`.** The canonical URL is the extensionless form:
  `https://davey.mywindowwashing.com/about`.
- **No separate Google Business Profile for Davey.** A second listing at the
  same address under a different brand puts the main listing at risk.
- The sitemap regenerates on every deploy, so a new page in `public/` is in
  the sitemap automatically. Nothing to update by hand.

---

## Troubleshooting

**The Actions run failed.** Open the failed step in the Actions tab. "Pages is
not enabled" means step 2 above was skipped.

**The site 404s at the custom domain.** DNS has not resolved yet, or the CNAME
points somewhere other than `d-g-websites.github.io`. Check with `dig +short
davey.mywindowwashing.com`.

**Certificate warning.** GitHub has not finished issuing yet. Wait, then tick
Enforce HTTPS. If it is still stuck after an hour, remove and re-add the
custom domain under Settings → Pages.

**Images are broken.** The filenames in `img/` must match what
`public/index.html` references exactly — the server is case-sensitive, so
`Photo.JPG` will not answer a request for `photo.jpg`.

**The site shows an old version.** Hard-refresh (Ctrl+Shift+R, or Cmd+Shift+R
on a Mac). A Pages deploy takes about a minute after the run goes green.
