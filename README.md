# odoo20-docker

Build recipe and deploy example for **[`messiazmonteiro/odoo20-core`](https://hub.docker.com/r/messiazmonteiro/odoo20-core)** - an unofficial Odoo 20.0 (Community) Docker image, published because Odoo S.A. has no official `odoo:20.0` image yet.

- `Dockerfile` - builds the image from the public [odoo/odoo `20.0`](https://github.com/odoo/odoo/tree/20.0) branch (pinned commit via `ODOO_SHA`), laid out like the official `odoo:19.0` image.
- `entrypoint.sh`, `odoo.conf`, `wait-for-psql.py` - unchanged from [odoo/docker 19.0](https://github.com/odoo/docker/tree/master/19.0) (LGPL-3.0, Odoo S.A.). Keep them executable.
- `deploy/` - ready-to-run docker compose example (`docker-compose.yml`, `.env.example`, `config/odoo.conf`, optional `Dockerfile`).

## Build
```bash
docker build -t odoo20-core:20.0 .
# another commit:  docker build --build-arg ODOO_SHA=<sha> -t odoo20-core:custom .
```
If GitHub is slow from inside your builder, download `https://github.com/odoo/odoo/archive/<sha>.tar.gz` on the host and swap the `curl` step for a `COPY` + `sha256sum -c` (this is how the published `20.0-20260913` image was built; same commit `efc7cb0`).

## Deploy
```bash
cd deploy && cp .env.example .env
sed -i "s/change-me/$(openssl rand -hex 16)/" .env
sed -i "s/CHANGE_ME_MASTER/$(openssl rand -hex 16)/" config/odoo.conf
docker compose up -d
docker compose run --rm odoo odoo -d mydb -i base --stop-after-init && docker compose restart odoo
```
Ports are bound to `127.0.0.1` (use an SSH tunnel or a reverse proxy). Odoo 20 defaults `http_interface` to `127.0.0.1`, so `deploy/config/odoo.conf` sets `0.0.0.0`. Full walkthrough: the Docker Hub page. Example addon: [oca_migrated_20](https://github.com/beneditomonteiro/oca_migrated_20) (`web_responsive` ported to Odoo 20).

Unofficial and unsupported by Odoo S.A. Maintained by the Maxdoo Team (Benedito Monteiro).
