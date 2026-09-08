# davey.mywindowwashing.com

Static one-page site for Davey's brand, on GitHub Pages. No build step, no
framework, no server-side code — plain HTML and CSS in one file.

**Pushing to `main` publishes the live site about a minute later.** There is no
staging environment. A mistake on `main` is a mistake in public, so read the
rules below before editing.

## The one rule that breaks things silently

**Only `public/` is published.** A file added anywhere else is committed and
never served. This has already caused one incident: the homepage was
originally added at the repository root and appeared to be fine.

- A new page goes at `public/about.html`, served at `/about`.
- Images go in `img/` at the root — the deploy copies them into `public/img/`.
  Both work; `img/` is the one people upload to.

## Do not hand-edit these

- `public/sitemap.xml` — regenerated on every deploy by
  `deploy/generate-sitemap.sh`. Edits are overwritten.
- `public/img/` — populated from `img/` by `deploy/stage-images.sh`.
  Add images to `img/`.
- `CNAME` and `public/CNAME` — both hold the custom domain. Removing
  `public/CNAME` can clear the domain on the next deploy and take the site down.

## Paths and URLs

Always root-relative. Relative paths work on the homepage and silently 404
from any other page, which is how they get shipped:

```html
<img src="/img/photo.jpg">     <!-- yes -->
<img src="img/photo.jpg">      <!-- no -->
```

GitHub Pages serves `about.html` at `/about` but does **not** redirect
`/about.html` to it — both return 200. So:

- link internally to the extensionless form, consistently
- give every page a `<link rel="canonical">` naming that same form

Otherwise one page gets indexed as two.

## Images

Filenames are case-sensitive on the server: `Photo.JPG` will not answer a
request for `photo.jpg`. Every `<img>` needs `width` and `height` (prevents
layout shift) and `loading="lazy"` unless it is above the fold. The existing
markup follows this — copy it.

## Content and SEO rules

This site is a **separate brand** from `www.mywindowwashing.com`, deliberately.

- **Never copy service or location copy from the main site.** Two pages
  competing on the same terms leaves you with two weak ones instead of one
  strong one. Original content only.
- **Never invent reviews, ratings, addresses, phone numbers or hours.** Use
  only values that are already in this repo or that the user supplies. This
  mirrors the main site's playbook.
- **Do not add a second `LocalBusiness` to the structured data**, and do not
  set up a separate Google Business Profile for Davey. A second business
  entity sharing the real NAP puts the existing Google listing at risk.
  Model Davey as a `Person` who `worksFor`
  `https://www.mywindowwashing.com/northbrook#localbusiness`.

Real data that exists: Davey's number `(728) 777-5183`, the Northbrook office
`(847) 297-4492`, Instagram `@daveymww`, and a Housecall Pro booking link.
There is no address, no hours and no review data for this site.

## The contact form

Posts client-side to Web3Forms; the access key is in the page near
`WEB3FORMS_KEY`. That key is public by design — it is not a secret and not a
leak. Changing the destination email means creating a new key at web3forms.com.

## Deploys

- `.github/workflows/pages.yml` — publishes `public/` on every push to `main`.
- `.github/workflows/deploy.yml` — a VPS alternative, manual-run only. Along
  with `deploy/setup-vps.sh` and `deploy/nginx/`, it is unused while on Pages.
  Leave it alone unless moving off Pages.

Pages **Source must stay "GitHub Actions"** (Settings → Pages). If it is ever
switched to "Deploy from a branch", Jekyll builds the repository root and
serves `README.md` as the homepage instead of the real site.

## Fixing a bad deploy

Revert the commit and push. The revert deploys like any other change.
