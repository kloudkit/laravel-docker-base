from kloudkit.testshed.docker.decorators import shed_env
from python_on_whales import DockerException

import pytest


def test_queue_connection_skipped_by_default(shed):
  assert "Skipping queue connection test." in shed.logs()


@shed_env(
  KLOUDKIT_TEST_QUEUE="true",
  QUEUE_CONNECTION="redis",
)
def test_queue_connection_succeeds(docker_sidecar, shed_deferred):
  redis = docker_sidecar("redis:alpine")

  container = shed_deferred(envs={"REDIS_HOST": redis.ip()})
  logs = container.logs()

  assert "Testing queue connection..." in logs
  assert "Queue connection successful." in logs


@shed_env(
  KLOUDKIT_TEST_QUEUE="true",
  QUEUE_CONNECTION="redis",
  REDIS_HOST="nonexistent-host",
  KLOUDKIT_TEST_TIMEOUT=1,
)
def test_queue_connection_fails_without_queue(shed_deferred):
  with pytest.raises(
    DockerException, match="Queue connection failed after 1s."
  ):
    shed_deferred(detach=False)
