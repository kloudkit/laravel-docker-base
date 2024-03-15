# Laravel Docker Base

> Docker base image for Laravel production applications

## Environment Variables

| `env`                          | Default | Mode      |
| ------------------------------ | ------- | --------- |
| `CONTAINER_MANUAL_SETUP`       | ➖       | `*`       |
| `CONTAINER_MODE`               | `"app"` | `*`       |
| `CONTAINER_PORT`               | `8000`  | app       |
| `CONTAINER_SCHEDULER_INTERVAL` | `60`    | scheduler |
| `CONTAINER_WORKER_DELAY`       | `10`    | worker    |
| `CONTAINER_WORKER_SLEEP`       | `5`     | worker    |
| `CONTAINER_WORKER_TRIES`       | `3`     | worker    |
| `CONTAINER_WORKER_TIMEOUT`     | `300`   | worker    |
