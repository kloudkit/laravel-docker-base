ARG php_version=8.3

FROM dunglas/frankenphp:1.2-php${php_version} AS base
WORKDIR /laravel
SHELL ["/bin/bash", "-eou", "pipefail", "-c"]

ENV SERVER_NAME=:80
ARG user=laravel

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
COPY --chmod=755 src/entrypoint.sh /entrypoint.sh
COPY --chmod=755 src/common /common
COPY --chown=${user}:${user} src/artisan artisan
COPY src/php.ini "${PHP_INI_DIR}/php.ini"

RUN apt-get update \
  && apt-get satisfy -y --no-install-recommends \
    "curl (>=7.88)" \
    "supervisor (>=4.2)" \
    "unzip (>=6.0)" \
    "vim-tiny (>=2)" \
  && rm -rf /var/lib/apt/lists/*

RUN useradd \
    --uid 1000 \
    --shell /bin/bash \
    "${user}" \
  && setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp \
  && chown -R "${user}:${user}" \
    /laravel \
    /data/caddy \
    /config/caddy \
    /var/{log,run} \
  && chmod -R a+rw \
    /var/{log,run}

RUN install-php-extensions \
    bcmath \
    bz2 \
    curl \
    exif \
    gd \
    intl \
    pcntl \
    pdo_pgsql \
    opcache \
    redis \
    sockets \
    zip

USER ${user}

RUN mkdir -p \
    bootstrap/cache \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/testing \
    storage/framework/views \
    storage/logs \
  && chmod -R a+rw storage

ENTRYPOINT ["/entrypoint.sh"]
