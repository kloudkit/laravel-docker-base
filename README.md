# Laravel Docker Base

> Docker base image for Laravel production applications

## Environment Variables

| `env`                      | Default        | Mode   |
| -------------------------- | -------------- | ------ |
| `APP_DEBUG`                | `false`        | `*`    |
| `APP_ENV`                  | `"production"` | `*`    |
| `CONTAINER_MANUAL_SETUP`   | ➖              | `*`    |
| `CONTAINER_MODE`           | `"app"`        | `*`    |
| `CONTAINER_PORT`           | `8000`         | app    |
| `CONTAINER_WORKER_DELAY`   | `10`           | worker |
| `CONTAINER_WORKER_SLEEP`   | `5`            | worker |
| `CONTAINER_WORKER_TRIES`   | `3`            | worker |
| `CONTAINER_WORKER_TIMEOUT` | `300`          | worker |
| `TEST_DB_CONNECTION`       | `true`         | `*`    |
| `TEST_CACHE_CONNECTION`    | `true`         | `*`    |
| `TEST_CONNECTION_TIMEOUT`  | `10`           | `*`    |
