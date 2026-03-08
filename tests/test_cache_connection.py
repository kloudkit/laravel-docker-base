from kloudkit.testshed.docker.decorators import shed_env
from python_on_whales import DockerException

import pytest


def test_cache_connection_skipped_by_default(shed):
  assert "Skipping cache connection test." in shed.logs()


@shed_env(KLOUDKIT_TEST_CACHE="true")
def test_cache_connection_succeeds(shed):
  logs = shed.logs()

  assert "Testing cache connection..." in logs
  assert "Cache connection successful." in logs


@shed_env(
  KLOUDKIT_TEST_CACHE="true",
  CACHE_STORE="redis",
  REDIS_HOST="nonexistent-host",
  KLOUDKIT_TEST_TIMEOUT=1,
)
def test_cache_connection_fails_without_cache(shed_deferred):
  with pytest.raises(
    DockerException, match="Cache connection failed after 1s."
  ):
    shed_deferred(detach=False)
