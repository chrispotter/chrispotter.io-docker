# Legacy — retired, not migrating to the cluster

Everything in this directory is kept for history only. It is **not** part of the
k3s deployment, has no manifests under `apps/`, and should not be deployed
anywhere. Nothing here needs to be migrated or exported before the old host is
decommissioned.

## blog/

Hugo blog, previously served at `blog.chrispotter.io`.

**Status:** retired. **Data at risk: none** — the content lives in its own
repository at `github.com/chrispotter/blog`, so nothing is lost by deleting this
deployment wrapper.

The `Dockerfile` could not build in any case: the `ENV` block is missing a line
continuation before `HUGO_BASEURL`, so Docker parses that line as an unknown
instruction. Below that, `WORKDIR /site $BLOG_ROOT` passes two arguments to an
instruction that takes one, and `CMD` runs `hugo server` — Hugo's development
server — rather than building static output.

If the blog is ever revived, start from a fresh two-stage Dockerfile
(`hugo --minify` in a build stage, nginx serving the result) rather than
repairing this file.

## silverstripe/

**Status:** retired. **Data at risk: none.**

Despite the name, this was never a SilverStripe site. It is an unmodified LEMP
tutorial scaffold that never had an application installed:

- `public/index.html` is the tutorial's placeholder (`LEMP Docker-Compose`,
  `hakase-labs`)
- `public/info.php` is a bare `<?php phpinfo(); ?>`
- `logs/access.log` and `logs/error.log` are both empty — it appears to have
  served no traffic

So there is no database worth dumping and no content worth exporting before the
old host goes away.

Three things worth noting even though it is retired:

- `nginx/app.conf` hardcodes the old host IP `193.70.36.50`.
- `docker-compose.yml` contains a MariaDB root password in plaintext
  (`hakase-labs123`). It is a tutorial default rather than a real credential,
  but if it was ever reused anywhere else, rotate it there.
- `public/info.php` would expose full PHP configuration to anyone who reached
  it. Worth confirming it is not currently reachable on the old host.

## Not in here yet

`nginx/` — the `jwilder/nginx-proxy` + `jrcs/letsencrypt-nginx-proxy-companion`
stack. Both images are unmaintained and both are replaced by Traefik and
cert-manager in the cluster, so this directory is also destined for `legacy/`.
It is being left in place until the last app has been cut over, since it is what
still routes the current production host.
