# Laravel Docker Base

> Docker base image for **Laravel production** applications using **FrankenPHP**

This repository provides a minimal yet comprehensive Docker *base* image for deploying
your Laravel application in production.
**It is intended purely as a foundation image** &mdash; you should **extend** it in your
project rather than run it directly [*(see below)*](#getting-started).

## Release Tags

- **Development *(`:dev`)***: Built automatically from every commit to the `main` branch.
- **Production *(`:vX.Y.Z`)***: Tagged versions for stable releases, with `:latest`
    pointing to the most recent version.

## Table of Contents

- [Release Tags](#release-tags)
- [Table of Contents](#table-of-contents)
- [Features](#features)
- [Getting Started](#getting-started)
- [Environment Variables](#environment-variables)
- [Container Modes](#container-modes)
  - [`app`](#app)
  - [`worker`](#worker)
  - [`horizon`](#horizon)
  - [`scheduler`](#scheduler)
- [Manual Setup vs Automatic Setup](#manual-setup-vs-automatic-setup)
- [Testing Connections](#testing-connections)
- [Contributing](#contributing)
- [License](#license)

## Features

- **FrankenPHP**: Powered by the [FrankenPHP][] runtime, providing a performant way to
    serve Laravel.
- **Container Modes**: Easily switch between `app`, `worker`, `horizon`, and `scheduler`
    modes.
- **Connection Testing**: Optional checks for database, cache, S3, and SMTP connections
    before serving the app.
- **Automatic Setup**: Laravel migrations, caches *(config, routes, views, events)*, and
    storage linking happen by default.
- **PHP Extensions**: Commonly used PHP extensions for a typical Laravel application
    *(bcmath, bz2, intl, redis, etc.)*.

## Getting Started

Because this is a base image, you’ll typically reference it in your own `Dockerfile`.
We strongly recommend using multi-stage builds to handle dependencies
*(e.g., installing Composer or Node packages)*, ensuring your final production image is as
lean as possible.

Below is an example `Dockerfile` that extends `laravel-docker-base`:

```dockerfile
FROM ghcr.io/kloudkit/laravel-docker-base:latest AS base

#################################### Vendor ####################################

FROM base AS vendor
WORKDIR /build

COPY composer.json .
COPY composer.lock .
COPY packages packages

RUN composer install \
    --ignore-platform-reqs \
    --no-cache \
    --no-interaction \
    --no-scripts \
    --prefer-dist

#################################### NodeJS ####################################

FROM node:latest AS client
WORKDIR /build

COPY package*.json .
COPY postcss.config.js .
COPY tailwind.config.js .
COPY vite.config.js .

COPY resources resources
COPY --from=vendor /build/vendor vendor

RUN npm install && npm run build

##################################### App ######################################

FROM base

COPY --chown=laravel:laravel composer.json composer.json
COPY --chown=laravel:laravel composer.lock composer.lock
COPY --chown=laravel:laravel app app
COPY --chown=laravel:laravel bootstrap bootstrap
COPY --chown=laravel:laravel config config
COPY --chown=laravel:laravel database database
COPY --chown=laravel:laravel packages packages
COPY --chown=laravel:laravel public public
COPY --chown=laravel:laravel resources resources
COPY --chown=laravel:laravel routes routes
COPY --chown=laravel:laravel --from=client /build/public public

RUN composer install \
    --no-ansi \
    --no-dev \
    --no-interaction \
    --no-progress \
    --no-scripts \
    --prefer-dist \
    --quiet \
  && composer dump-autoload \
    --classmap-authoritative \
    --no-dev
```

## Environment Variables

You can customize the container by setting the following environment variables:

| **Variable**               | **Default**    | **Modes** | **Description**                                                       |
| -------------------------- | -------------- | --------- | --------------------------------------------------------------------- |
| `APP_DEBUG`                | `false`        | `*`       | Laravel debug mode                                                    |
| `APP_ENV`                  | `"production"` | `*`       | Laravel environment name                                              |
| `CONTAINER_MANUAL_SETUP`   | *(empty)*      | `*`       | Skips automatic setup *(migrations, caching, etc.)*                   |
| `CONTAINER_MODE`           | `"app"`        | `*`       | Define the container mode *(see [Container Modes](#container-modes))* |
| `CONTAINER_PORT`           | `8000`         | `app`     | Port FrankenPHP listens to *(when in `app` mode)*                     |
| `CONTAINER_WORKER_DELAY`   | `10`           | `worker`  | `queue:work` delay                                                    |
| `CONTAINER_WORKER_SLEEP`   | `5`            | `worker`  | `queue:work` sleep                                                    |
| `CONTAINER_WORKER_TRIES`   | `3`            | `worker`  | `queue:work` tries                                                    |
| `CONTAINER_WORKER_TIMEOUT` | `300`          | `worker`  | `queue:work` timeout                                                  |
| `TEST_CACHE_CONNECTION`    | `true`         | `*`       | Test cache connection on startup                                      |
| `TEST_DB_CONNECTION`       | `true`         | `*`       | Test database connection on startup                                   |
| `TEST_S3_CONNECTION`       | `false`        | `*`       | Test S3 connection on startup                                         |
| `TEST_SMTP_CONNECTION`     | `false`        | `*`       | Test SMTP connection on startup                                       |
| `TEST_CONNECTION_TIMEOUT`  | `10`           | `*`       | Seconds to attempt each connection test before failing                |

## Container Modes

This image supports multiple container modes via the `CONTAINER_MODE` variable, each
focusing on a specific type of service:

### `app`

- Serves the Laravel application using FrankenPHP on port `CONTAINER_PORT`
  *(default `8000`)*.
- Ideal for load-balanced or standalone app containers.

### `worker`

- Runs `php artisan queue:work` with the provided settings *(`CONTAINER_WORKER_*`)*.
- Suitable for handling asynchronous jobs.

### `horizon`

- Runs `php artisan horizon`.
- Ideal if you prefer Laravel Horizon for managing queues.

### `scheduler`

- Runs `php artisan schedule:work` in the foreground.
- Great for cron-like, scheduled tasks.

## Manual Setup vs Automatic Setup

By default, this image **automatically**:

- Tests connections *(DB, cache, S3, SMTP)* if `TEST_*` variables are set to `true`.
- Runs `php artisan migrate --force`.
- Creates the storage symlink *(if not already present)*.
- Caches config, events, routes, and views.

If you need to skip these steps *(e.g., you manage migrations separately)*, set
`CONTAINER_MANUAL_SETUP` to any non-empty value, and the container will **skip** all
auto-setup steps, running the [Container Mode](#container-modes) command directly.

## Testing Connections

The image's entrypoint can optionally test common connections before starting
*(or failing fast)*, depending on environment variables:

- **Database:**: Controlled by `TEST_DB_CONNECTION` *(`true` by default)*.
- **Cache:**: Controlled by `TEST_CACHE_CONNECTION` *(`true` by default)*.
- **S3:**: Controlled by `TEST_S3_CONNECTION` *(`false` by default)*.
- **SMTP:**: Controlled by `TEST_SMTP_CONNECTION` *(`false` by default)*.

Each test will attempt a connection for up to `TEST_CONNECTION_TIMEOUT` seconds before
giving up and exiting with a non-zero code.
This ensures your container won’t fully start unless its dependencies are actually ready.

> [!IMPORTANT]
> Ensure you provide the correct authentication environment variables
> *(DB_HOST, DB_USERNAME, DB_PASSWORD, etc.)* for any connections you enable.

## Contributing

Contributions are welcome!
Please open issues or submit pull requests for any improvements or fixes you find.

## License

This project is open-sourced software licensed under the [MIT license](LICENSE).
Feel free to adapt it to your needs.

[FrankenPHP]: https://frankenphp.dev
