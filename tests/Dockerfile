ARG BASE_IMAGE=laravel-docker-base:tests
FROM ${BASE_IMAGE}

ENV APP_KEY=base64:CKcFno8bjubyT2XnxxwLbDsPpZHIP66aqGywNJ5xFxo= \
    DB_CONNECTION=sqlite \
    DB_DATABASE=/laravel/storage/database.sqlite \
    CACHE_STORE=array \
    KLOUDKIT_SKIP_CONFIG_WARNINGS=1 \
    KLOUDKIT_TEST_DB=false \
    KLOUDKIT_TEST_CACHE=false \
    KLOUDKIT_TEST_QUEUE=false \
    KLOUDKIT_TEST_REDIS=false \
    KLOUDKIT_TEST_S3=false \
    KLOUDKIT_TEST_SMTP=false

USER root
# @todo: FIX — pinned to ^12 because laravel/octane conflicts with phpunit >12 (shipped by Laravel 13)
RUN composer create-project laravel/laravel /tmp/skeleton "^12" --no-interaction --prefer-dist \
    && cp -a /tmp/skeleton/. /laravel/ \
    && rm -rf /tmp/skeleton \
    && composer require laravel/octane league/flysystem-aws-s3-v3 --no-interaction \
    && php artisan octane:install --server=frankenphp --no-interaction \
    && chown -R laravel:laravel /laravel
USER laravel
