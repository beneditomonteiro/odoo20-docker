FROM ubuntu:noble
LABEL maintainer="Maxdoo Team <messiaz@gmail.com>" \
      org.opencontainers.image.title="odoo20-core" \
      org.opencontainers.image.description="Odoo 20.0 community core, built from the odoo/odoo 20.0 git branch (no official Docker image / nightly deb for 20.0 yet). Same layout as the official odoo image." \
      org.opencontainers.image.source="https://github.com/odoo/odoo/tree/20.0" \
      org.opencontainers.image.licenses="LGPL-3.0"

SHELL ["/bin/bash", "-xo", "pipefail", "-c"]
ENV LANG=en_US.UTF-8
ARG TARGETARCH

# Base deps, lessc, wkhtmltopdf (same recipe as the official odoo/docker 19.0 image)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates curl dirmngr fonts-noto-cjk gnupg libssl-dev node-less python3-pip xz-utils && \
    if [ -z "${TARGETARCH}" ]; then TARGETARCH="$(dpkg --print-architecture)"; fi; \
    WKHTMLTOPDF_ARCH=${TARGETARCH} && \
    case ${TARGETARCH} in \
    "amd64") WKHTMLTOPDF_ARCH=amd64 && WKHTMLTOPDF_SHA=967390a759707337b46d1c02452e2bb6b2dc6d59  ;; \
    "arm64")  WKHTMLTOPDF_SHA=90f6e69896d51ef77339d3f3a20f8582bdf496cc  ;; \
    "ppc64le" | "ppc64el") WKHTMLTOPDF_ARCH=ppc64el && WKHTMLTOPDF_SHA=5312d7d34a25b321282929df82e3574319aed25c  ;; \
    esac \
    && curl -o wkhtmltox.deb -sSL https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-3/wkhtmltox_0.12.6.1-3.jammy_${WKHTMLTOPDF_ARCH}.deb \
    && echo ${WKHTMLTOPDF_SHA} wkhtmltox.deb | sha1sum -c - \
    && apt-get install -y --no-install-recommends ./wkhtmltox.deb \
    && rm -rf /var/lib/apt/lists/* wkhtmltox.deb

# Latest postgresql-client
RUN echo 'deb http://apt.postgresql.org/pub/repos/apt/ noble-pgdg main' > /etc/apt/sources.list.d/pgdg.list \
    && GNUPGHOME="$(mktemp -d)" \
    && export GNUPGHOME \
    && repokey='B97B0AFCAA1A47F044F244A07FCC7D46ACCC4CF8' \
    && gpg --batch --keyserver keyserver.ubuntu.com --recv-keys "${repokey}" \
    && gpg --batch --armor --export "${repokey}" > /etc/apt/trusted.gpg.d/pgdg.gpg.asc \
    && gpgconf --kill all \
    && rm -rf "$GNUPGHOME" \
    && apt-get update  \
    && apt-get install --no-install-recommends -y postgresql-client \
    && rm -f /etc/apt/sources.list.d/pgdg.list \
    && rm -rf /var/lib/apt/lists/*

# rtlcss
RUN apt-get update && \
    apt-get install -y --no-install-recommends nodejs npm \
    && npm install -g rtlcss \
    && apt-get purge --autoremove -y npm \
    && rm -rf /var/lib/apt/lists/*

# Odoo 20.0 runtime deps = the python3-* packages in Odoo's debian/control "Depends"
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        python3-asn1crypto python3-babel python3-cbor2 python3-chardet python3-cryptography \
        python3-dateutil python3-docutils python3-freezegun python3-geoip2 python3-gevent \
        python3-greenlet python3-h11 python3-idna python3-jinja2 python3-ldap python3-libsass \
        python3-lxml python3-lxml-html-clean python3-magic python3-markupsafe python3-num2words \
        python3-ofxparse python3-openpyxl python3-openssl python3-passlib python3-pil python3-polib \
        python3-psutil python3-psycopg2 python3-pypdf python3-pypdf2 python3-qrcode python3-renderpm \
        python3-reportlab python3-requests python3-rjsmin python3-setuptools python3-stdnum \
        python3-urllib3 python3-vobject python3-werkzeug python3-xlrd python3-xlsxwriter python3-zeep \
    && rm -rf /var/lib/apt/lists/*

# odoo user, same uid:gid (100:101) as the official image
RUN groupadd -r -g 101 odoo \
    && useradd -r -u 100 -g 101 -d /var/lib/odoo -s /usr/sbin/nologin odoo \
    && mkdir -p /var/lib/odoo /var/log/odoo \
    && chown odoo:odoo /var/lib/odoo /var/log/odoo

# Odoo 20.0 from git, laid out like the official .deb (python package + all community addons in one dir)
ENV ODOO_VERSION=20.0
ARG ODOO_SHA=efc7cb0f13a1817a068330f14faa8dc811e31f2a
RUN curl -fsSL --retry 8 --retry-all-errors https://github.com/odoo/odoo/archive/${ODOO_SHA}.tar.gz -o /tmp/odoo.tar.gz \
    && mkdir /tmp/odoo-src && tar -xzf /tmp/odoo.tar.gz -C /tmp/odoo-src --strip-components=1 \
    && cp -r /tmp/odoo-src/odoo /usr/lib/python3/dist-packages/odoo \
    && cp -r /tmp/odoo-src/addons/. /usr/lib/python3/dist-packages/odoo/addons/ \
    && install -m 0755 /tmp/odoo-src/odoo-bin /usr/bin/odoo \
    && mkdir -p /usr/share/doc/odoo && cp /tmp/odoo-src/LICENSE /usr/share/doc/odoo/ \
    && rm -rf /tmp/odoo.tar.gz /tmp/odoo-src \
    && python3 -c "import odoo.release as r; print(r.version)"

COPY ./entrypoint.sh /
COPY ./odoo.conf /etc/odoo/
RUN chown odoo /etc/odoo/odoo.conf \
    && mkdir -p /mnt/extra-addons \
    && chown -R odoo /mnt/extra-addons
VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]
EXPOSE 8069 8071 8072
ENV ODOO_RC=/etc/odoo/odoo.conf
COPY wait-for-psql.py /usr/local/bin/wait-for-psql.py
USER odoo
ENTRYPOINT ["/entrypoint.sh"]
CMD ["odoo"]
