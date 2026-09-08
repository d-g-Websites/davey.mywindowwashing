# davey.mywindowwashing.com

Static site for Davey's brand, served from its own VPS. Separate from
`www.mywindowwashing.com` and from that site's cPanel hosting.

Push to `main` and the live site updates. That's the whole workflow.

---

## Repository layout

```
public/                 the website — everything in here is served
  index.html            /
  404.html              error page (not in the sitemap)
  robots.txt
  sitemap.xml           generated on deploy, do not edit by hand
deploy/
  setup-vps.sh          one-time server setup
  generate-sitemap.sh   rebuilds sitemap.xml from public/
  nginx/                the server configuration, kept in version control
.github/workflows/
  deploy.yml            publishes public/ on every push to main
```

**Only `public/` is published.** Files outside it stay in the repo. When you
unzip the site, its `index.html` goes at `public/index.html`.

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

nginx serves `about.html` at `/about`, so link to pages **without** the
`.html`:

```html
<a href="/about">About</a>          <!-- yes -->
<a href="/about.html">About</a>     <!-- works, but redirects -->
```

Every other form redirects to the canonical one, so nothing 404s and search
engines only see one URL per page:

| Requested | Ends up at |
|---|---|
| `/about.html` | `/about` |
| `/about/` | `/about` |
| `/index.html` | `/` |
| `/blog/index.html` | `/blog/` |
| `http://…` | `https://…` |

A directory containing `index.html` keeps its trailing slash: `/blog/`.

---

## First-time setup

### 1. DNS

Point the subdomain at the new VPS:

| Type | Name | Value |
|---|---|---|
| A | `davey` | the VPS IPv4 address |
| AAAA | `davey` | the VPS IPv6 address, if it has one |

This record lives in the `mywindowwashing.com` DNS zone. It does not affect
the main site — that keeps resolving to cPanel.

Wait for it to resolve before step 2, or the certificate request fails:

```bash
dig +short davey.mywindowwashing.com
```

### 2. The server

On a fresh Debian or Ubuntu VPS:

```bash
git clone https://github.com/ginolyp-pixel/davey.mywindowwashing.git
cd davey.mywindowwashing
sudo ./deploy/setup-vps.sh
```

It installs nginx and certbot, creates the `deploy` user, issues the TLS
certificate, sets up automatic renewal, and turns on the firewall. Re-running
it is safe. It finishes by printing the exact secrets to add in step 3.

### 3. GitHub secrets

Make a deploy key on your own machine:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/davey_deploy -N "" -C "github-actions"
```

Authorise it on the server:

```bash
KEY=$(cat ~/.ssh/davey_deploy.pub)
ssh root@davey.mywindowwashing.com \
  "echo 'no-agent-forwarding,no-port-forwarding,no-X11-forwarding,no-pty $KEY' \
   >> /home/deploy/.ssh/authorized_keys"
```

Then add these under **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `SSH_PRIVATE_KEY` | contents of `~/.ssh/davey_deploy` — the file **without** `.pub` |
| `SSH_KNOWN_HOSTS` | output of `ssh-keyscan -t rsa,ecdsa,ed25519 davey.mywindowwashing.com` |
| `VPS_HOST` | `davey.mywindowwashing.com` |
| `VPS_USER` | `deploy` |
| `VPS_PATH` | `/var/www/davey/public` |

`SSH_KNOWN_HOSTS` pins the server's identity. Without it the deploy would
trust whatever answers at that address, so a hijacked DNS record could collect
the deploy key.

### 4. First deploy

Push to `main`, or run the workflow by hand from the Actions tab. You should
get the placeholder page over HTTPS.

### 5. Replace the placeholder

Put the real site in `public/`, then **delete the `noindex` line** from
`public/index.html`:

```html
<meta name="robots" content="noindex">
```

While that tag is present Google will not index the page.

---

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

**The Actions run failed.** Open the failed step in the Actions tab. A
`Permission denied (publickey)` in the rsync step means the deploy key is not
in `/home/deploy/.ssh/authorized_keys`, or `SSH_PRIVATE_KEY` is missing the
`-----BEGIN`/`-----END` lines — paste the whole file including those.

**`Host key verification failed`.** `SSH_KNOWN_HOSTS` is wrong or stale.
Re-run `ssh-keyscan` and update the secret. Expect this after rebuilding the
VPS, since the server gets a new host key.

**The site shows an old version.** Hard-refresh first. HTML is sent with
`Cache-Control: no-cache`, but images and CSS are cached for a long time by
design — rename a changed image, or add `?v=2` to its URL.

**Certificate errors.** Check renewal with
`sudo certbot certificates` and `systemctl status certbot.timer`. A dry run:
`sudo certbot renew --dry-run`.

**nginx will not start after a config change.** `sudo nginx -t` reports the
line. To change the server config, edit `deploy/nginx/` in this repo, then
re-run `sudo ./deploy/setup-vps.sh` on the VPS so the file stays in git rather
than only on the server.
