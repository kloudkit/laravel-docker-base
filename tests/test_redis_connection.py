from kloudkit.testshed.docker.decorators import shed_env
from python_on_whales import DockerException

import pytest


def test_redis_connection_skipped_by_default(shed):
  assert "Skipping redis connection test." in shed.logs()


@shed_env(
  KLOUDKIT_TEST_REDIS="true",
)
def test_redis_connection_succeeds(docker_sidecar, shed_deferred):
  redis = docker_sidecar("redis:alpine")
  container = shed_deferred(envs={"REDIS_HOST": redis.ip()})
  logs = container.logs()

  assert "Testing redis connection..." in logs
  assert "Redis connection successful." in logs


@shed_env(
  KLOUDKIT_TEST_REDIS="true",
  REDIS_HOST="nonexistent-host",
  KLOUDKIT_TEST_TIMEOUT=1,
)
def test_redis_connection_fails_without_redis(shed_deferred):
  with pytest.raises(
    DockerException, match="Redis connection failed after 1s."
  ):
    shed_deferred(detach=False)
