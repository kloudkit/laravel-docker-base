ARG php_version=8.3

FROM dunglas/frankenphp:1.1-php${php_version} AS base
WORKDIR /app

ENV SERVER_NAME=:80
ARG user=laravel

COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
COPY --chmod=755 src/entrypoint.sh /entrypoint.sh
COPY src/php.ini "${PHP_INI_DIR}/php.ini"

RUN apt-get update \
  && apt-get satisfy -y --no-install-recommends \
    "curl (>=7.88)" \
    "supervisor (>=4.2)" \
    "unzip (>=6.0)" \
  && rm -rf /var/lib/apt/lists/*

RUN useradd \
    --uid 1000 \
    --shell /bin/bash \
    "${user}" \
  && setcap CAP_NET_BIND_SERVICE=+eip /usr/local/bin/frankenphp \
  && chown -R "${user}:${user}" \
    /app \
    /data/caddy \
    /config/caddy \
  && mv "${PHP_INI_DIR}/php.ini-production" "${PHP_INI_DIR}/php.ini"

RUN install-php-extensions \
    curl \
    gd \
    intl \
    pcntl \
    pdo_pgsql \
    opcache \
    redis \
    zip

USER ${user}

COPY --chown=${user}:${user} src/artisan artisan

RUN mkdir -p \
    bootstrap/cache \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/testing \
    storage/framework/views \
    storage/logs \
  && chmod -R a+rw storage

ENTRYPOINT ["/entrypoint.sh"]
