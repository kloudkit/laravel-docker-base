from kloudkit.testshed.docker.decorators import shed_env
from python_on_whales import DockerException

import pytest


def test_database_connection_skipped_by_default(shed):
  assert "Skipping database connection test." in shed.logs()


@shed_env(
  KLOUDKIT_TEST_DB="true",
  DB_CONNECTION="pgsql",
  DB_DATABASE="laravel",
  DB_USERNAME="laravel",
  DB_PASSWORD="secret",
)
def test_database_connection_succeeds(docker_sidecar, shed_deferred):
  postgres = docker_sidecar(
    "postgres:alpine",
    envs={
      "POSTGRES_DB": "laravel",
      "POSTGRES_USER": "laravel",
      "POSTGRES_PASSWORD": "secret",
    },
  )

  container = shed_deferred(envs={"DB_HOST": postgres.ip()})
  logs = container.logs()

  assert "Testing database connection..." in logs
  assert "Database connection successful." in logs


@shed_env(
  KLOUDKIT_TEST_DB="true",
  DB_CONNECTION="pgsql",
  DB_HOST="nonexistent-host",
  KLOUDKIT_TEST_TIMEOUT=1,
)
def test_database_connection_fails_without_database(shed_deferred):
  with pytest.raises(
    DockerException, match="Database connection failed after 1s."
  ):
    shed_deferred(detach=False)
