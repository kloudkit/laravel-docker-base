# Laravel Docker Base

> Docker base image for **Laravel production** applications using **FrankenPHP**

This repository provides a minimal yet comprehensive Docker *base* image for deploying
your Laravel application in production.
**It is intended purely as a foundation image** &mdash; you should **extend** it in your
project rather than run it directly [*(see below)*](#getting-started).

## Release Tags

- **Development *(`:dev`)*:** Built automatically from every commit to the `main` branch.
- **Production *(`:vX.Y.Z`)*:** Tagged versions for stable releases, with `:latest`
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
  - [`migrate`](#migrate)
- [Automatic Setup](#automatic-setup)
- [Deployment Strategy](#deployment-strategy)
  - [Single image, multiple services](#single-image-multiple-services)
  - [No supervisor needed](#no-supervisor-needed)
  - [Init container pattern](#init-container-pattern)
  - [Example docker-compose](#example-docker-compose)
  - [Health checks](#health-checks)
- [Connection Tests](#connection-tests)
- [Config Warnings](#config-warnings)
- [Helper Scripts](#helper-scripts)
- [Startup Hooks](#startup-hooks)
  - [Adding hooks](#adding-hooks)
  - [Hook script example](#hook-script-example)
  - [Failure handling](#failure-handling)
- [Maintenance Mode](#maintenance-mode)
  - [Recommended workflow](#recommended-workflow)
- [Contributing](#contributing)
- [License](#license)

## Features

- **FrankenPHP:** Powered by the [FrankenPHP][] runtime, providing a performant way to
    serve Laravel.
- **Container Modes:** Easily switch between `app`, `worker`, `horizon`, `scheduler`,
    and `migrate` modes.
- **Connection Tests:** Optional startup checks for database, cache, queue, Redis, S3,
    and SMTP connections before the process starts.
- **Config Warnings:** Detects common misconfigurations *(file-based sessions, sync queues,
    etc.)* and logs warnings on startup.
- **Automatic Setup:** Migrations, caches *(config, routes, views, events)*, and
    storage linking happen by default in `app` and `migrate` modes.
- **Graceful Shutdown:** `STOPSIGNAL SIGTERM` ensures clean shutdown of Octane, Horizon,
    and queue workers.
- **Memory Leak Prevention:** Workers use `--max-jobs` and `--max-time` to exit gracefully,
    relying on the orchestrator to restart.
- **Helper Scripts:** Bundled scripts at `/helpers` for common Composer and Artisan
    operations in your Dockerfile.
- **Startup Hooks:** Run custom scripts before and after startup phases using
    `/laravel/hooks/` directories — extend the entrypoint without overriding it.
- **PHP Extensions:** Commonly used PHP extensions for a typical Laravel application
    *(bcmath, bz2, intl, redis, etc.)*.

## Getting Started

Because this is a base image, you'll typically reference it in your own `Dockerfile`.
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

RUN /helpers/composer-install

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

RUN /helpers/composer-install \
  && /helpers/composer-optimize
```

## Environment Variables

You can customize the container by setting the following environment variables:

| **Variable**                     | **Default**    | **Modes**        | **Description**                                                       |
| -------------------------------- | -------------- | ---------------- | --------------------------------------------------------------------- |
| `APP_DEBUG`                      | `false`        | `*`              | Laravel debug mode                                                    |
| `APP_ENV`                        | `"production"` | `*`              | Laravel environment name                                              |
| `KLOUDKIT_MANUAL_SETUP`          | *(empty)*      | `app`, `migrate` | Skips automatic setup *(migrations, caching, etc.)*                   |
| `KLOUDKIT_MODE`                  | `"app"`        | `*`              | Define the container mode *(see [Container Modes](#container-modes))* |
| `KLOUDKIT_PORT`                  | `8000`         | `app`            | Port FrankenPHP listens to *(when in `app` mode)*                     |
| `KLOUDKIT_WORKER_CONNECTION`     | *(empty)*      | `worker`         | Queue connection name *(positional arg to `queue:work`)*              |
| `KLOUDKIT_WORKER_DELAY`          | `10`           | `worker`         | `queue:work` delay                                                    |
| `KLOUDKIT_WORKER_MAX_JOBS`       | `1000`         | `worker`         | Max jobs before worker exits gracefully                               |
| `KLOUDKIT_WORKER_MAX_TIME`       | `3600`         | `worker`         | Max seconds before worker exits gracefully                            |
| `KLOUDKIT_WORKER_QUEUE`          | `"default"`    | `worker`         | Queue name(s) to process *(comma-separated for priority)*             |
| `KLOUDKIT_WORKER_SLEEP`          | `5`            | `worker`         | `queue:work` sleep                                                    |
| `KLOUDKIT_WORKER_TRIES`          | `3`            | `worker`         | `queue:work` tries                                                    |
| `KLOUDKIT_WORKER_TIMEOUT`        | `300`          | `worker`         | `queue:work` timeout                                                  |
| `KLOUDKIT_TEST_CACHE`            | `true`         | `*`              | Test cache connection on startup                                      |
| `KLOUDKIT_TEST_DB`               | `true`         | `*`              | Test database connection on startup                                   |
| `KLOUDKIT_TEST_QUEUE`            | `false`        | `*`              | Test queue connection on startup                                      |
| `KLOUDKIT_TEST_REDIS`            | `false`        | `*`              | Test Redis connection on startup                                      |
| `KLOUDKIT_TEST_S3`               | `false`        | `*`              | Test S3 connection on startup                                         |
| `KLOUDKIT_TEST_SMTP`             | `false`        | `*`              | Test SMTP connection on startup                                       |
| `KLOUDKIT_TEST_TIMEOUT`          | `10`           | `*`              | Seconds to attempt each connection test before failing                |
| `KLOUDKIT_LOG_COLOR`             | *(empty)*      | `*`              | Force colored log output (`true` to enable)                           |
| `NO_COLOR`                       | *(empty)*      | `*`              | Disable colored output (per [no-color.org](https://no-color.org))     |
| `KLOUDKIT_SKIP_CONFIG_WARNINGS`  | *(empty)*      | `*`              | Skip config warnings on startup                                       |
| `KLOUDKIT_HOOKS_IGNORE_FAILURES` | *(empty)*      | `*`              | Continue startup even if a hook script fails (`true` to enable)       |

## Container Modes

This image supports multiple container modes via the `KLOUDKIT_MODE` variable, each
focusing on a specific type of service:

### `app`

- Runs setup *(migrations, caching)* then serves the Laravel application using FrankenPHP
  on port `KLOUDKIT_PORT` *(default `8000`)*.
- Ideal for load-balanced or standalone app containers.

### `worker`

- Runs `php artisan queue:work` with the provided settings *(`KLOUDKIT_WORKER_*`)*.
- Exits gracefully after `KLOUDKIT_WORKER_MAX_JOBS` jobs or `KLOUDKIT_WORKER_MAX_TIME`
  seconds to prevent memory leaks. The orchestrator restarts the container automatically.
- Use `KLOUDKIT_WORKER_QUEUE` to target specific queues *(comma-separated for priority,
  processed left-to-right)* and `KLOUDKIT_WORKER_CONNECTION` to select an alternative
  queue driver *(e.g., `sqs` instead of the default)*.
- Scale horizontally by running multiple replicas of any worker container. Each replica
  independently pulls jobs from the same queue.

### `horizon`

- Runs `php artisan horizon`.
- Ideal if you prefer Laravel Horizon for managing queues.

### `scheduler`

- Runs `php artisan schedule:work` in the foreground.
- Great for cron-like, scheduled tasks.

### `migrate`

- Runs setup *(migrations, caching)* then exits.
- Designed as an init container that runs before other services start.
- Use with `depends_on: { condition: service_completed_successfully }` in Docker Compose
  or as a Kubernetes init container.

## Automatic Setup

By default, the `app` and `migrate` modes **automatically**:

- Run `php artisan migrate --force --isolated`.
- Create the storage symlink *(if not already present)*.
- Cache config, events, routes, and views.

Other modes *(`worker`, `horizon`, `scheduler`)* skip setup and start their process directly.
This prevents race conditions where multiple containers try to run migrations simultaneously.

To skip setup in `app` or `migrate` mode, set `KLOUDKIT_MANUAL_SETUP` to any non-empty value.

## Deployment Strategy

### Single image, multiple services

Build your application image once, then deploy multiple containers with different
`KLOUDKIT_MODE` values.
Every container uses the same image, only the mode differs.

### No supervisor needed

Each container mode uses `exec` to replace the shell with the target process *(PID 1)*.
The orchestrator *(Docker restart policy or Kubernetes)* handles restarts:

- **Process crash:** container exits, orchestrator restarts.
- **`--max-jobs`/`--max-time`:** worker exits gracefully (code 0), orchestrator restarts.
- **SIGTERM:** Octane, Horizon, and queue:work all handle graceful shutdown natively.

### Init container pattern

Use `KLOUDKIT_MODE=migrate` as an init container that runs setup once before the rest of
your services start.

This avoids race conditions from multiple containers running migrations simultaneously.

### Example docker-compose

```yaml
services:
  migrate:
    image: my-app:latest
    environment:
      KLOUDKIT_MODE: migrate
    depends_on:
      db: { condition: service_healthy }
    restart: "no"

  app:
    image: my-app:latest
    environment:
      KLOUDKIT_MODE: app
      KLOUDKIT_MANUAL_SETUP: "1"
    depends_on:
      migrate: { condition: service_completed_successfully }
    restart: unless-stopped

  worker:
    image: my-app:latest
    environment:
      KLOUDKIT_MODE: worker
      KLOUDKIT_WORKER_MAX_JOBS: 1000
      KLOUDKIT_WORKER_MAX_TIME: 3600
    depends_on:
      migrate: { condition: service_completed_successfully }
    restart: unless-stopped

  worker-emails:
    image: my-app:latest
    environment:
      KLOUDKIT_MODE: worker
      KLOUDKIT_WORKER_QUEUE: emails
      KLOUDKIT_WORKER_MAX_JOBS: 500
    depends_on:
      migrate: { condition: service_completed_successfully }
    restart: unless-stopped

  scheduler:
    image: my-app:latest
    environment:
      KLOUDKIT_MODE: scheduler
    depends_on:
      migrate: { condition: service_completed_successfully }
    restart: unless-stopped
```

### Health checks

Health checks are left to the deployment layer.

Use Kubernetes liveness/readiness probes or Docker Compose `healthcheck` directives on
your services as needed.

## Connection Tests

The entrypoint can optionally test connections before starting, controlled by the
`KLOUDKIT_TEST_*` environment variables. Database and cache tests are enabled by default;
queue, Redis, S3, and SMTP are opt-in.

Each test retries for up to `KLOUDKIT_TEST_TIMEOUT` seconds *(default `10`)* before
exiting with a non-zero code. This ensures your container won't start unless its
dependencies are actually ready.

Connection tests run in **all** container modes.

> [!IMPORTANT]
> Ensure you provide the correct authentication environment variables
> *(DB_HOST, DB_USERNAME, DB_PASSWORD, etc.)* for any connections you enable.

## Config Warnings

On startup, the entrypoint checks your Laravel configuration and logs warnings for
common issues in containerized deployments:

- **Sessions:** file or array driver &mdash; consider `redis` or `database`.
- **Cache:** file or array driver &mdash; consider `redis` or `memcached`.
- **Queue:** sync driver &mdash; consider `redis`, `sqs`, or `database`.
- **Logging:** single or daily driver &mdash; consider `stderr`.
- **Broadcasting:** `log` or `null` driver when `channels.php` uses `Broadcast::`.

Set `KLOUDKIT_SKIP_CONFIG_WARNINGS` to any non-empty value to suppress these warnings.

## Helper Scripts

The image includes scripts at `/helpers` for common operations in your Dockerfile or
custom entrypoint:

| Script                       | Description                                                 |
| ---------------------------- | ----------------------------------------------------------- |
| `/helpers/composer-install`  | Production `composer install` *(no-dev, no-scripts, quiet)* |
| `/helpers/composer-optimize` | `composer dump-autoload --classmap-authoritative --no-dev`  |
| `/helpers/artisan-optimize`  | Caches config, events, routes, and views                    |
| `/helpers/artisan-clear`     | Clears config, event, route, and view caches                |

## Startup Hooks

Run custom scripts at specific points during container startup by placing executable
files in `/laravel/hooks/<phase>/`:

| Hook Directory      | When                                      | Modes            |
| ------------------- | ----------------------------------------- | ---------------- |
| `hooks/pre-start/`  | Before connection tests and config checks | `*`              |
| `hooks/pre-setup/`  | Before migrations, storage link, optimize | `app`, `migrate` |
| `hooks/post-setup/` | After migrations, storage link, optimize  | `app`, `migrate` |
| `hooks/pre-run/`    | Right before the final process starts     | `*`              |

Scripts run in **lexicographic order** — prefix with numbers to control execution
order *(e.g., `01-first.sh`, `02-second.sh`)*.

### Adding hooks

In your Dockerfile:

```dockerfile
COPY --chmod=755 hooks/pre-run/01-warmup-cache.sh /laravel/hooks/pre-run/
```

Or via Docker Compose volumes:

```yaml
volumes:
  - ./hooks/pre-start:/laravel/hooks/pre-start
```

### Hook script example

```bash
#!/bin/bash
# Only warm cache in app mode
if [ "$KLOUDKIT_MODE" = "app" ]; then
  php artisan cache:prime
fi
```

`KLOUDKIT_MODE` is exported so hook scripts can branch on the container mode.

### Failure handling

By default, a failing hook script **stops the container** *(exit non-zero)*. Set
`KLOUDKIT_HOOKS_IGNORE_FAILURES=true` to log a warning and continue instead.

Non-executable files are skipped with a warning. Hidden files *(dotfiles)* are
ignored silently.

> [!NOTE]
> `pre-start` hooks run **before** connection tests — external services may not be
> reachable yet. Use `pre-run` for hooks that depend on database or cache availability.

## Maintenance Mode

In a multi-container deployment, Laravel's default file-based maintenance mode
only affects the container it's run on. Use the `--store` option to share the
maintenance signal across all containers via Redis:

```bash
# All containers see maintenance mode
php artisan down --store=redis

# Clear maintenance mode (automatically detects the store)
php artisan up
```

### Recommended workflow

1. `php artisan down --store=redis`
2. Send SIGTERM to worker and scheduler containers
3. Workers finish in-flight jobs, then exit — remaining jobs wait in the queue
4. Run migrations or patches
5. Start worker and scheduler containers back up
6. `php artisan up`

Workers resume processing the queue. The scheduler resumes on its next tick.
No jobs are lost during graceful shutdown.

## Contributing

Contributions are welcome!
Please open issues or submit pull requests for any improvements or fixes you find.

## License

This project is open-sourced software licensed under the [MIT license](LICENSE).
Feel free to adapt it to your needs.

[FrankenPHP]: https://frankenphp.dev
