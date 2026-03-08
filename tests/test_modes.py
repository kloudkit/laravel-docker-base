import time

from kloudkit.testshed.docker.decorators import shed_config, shed_env

import pytest


def wait_for_log(container, text, timeout=15):
  """Poll container logs until text appears."""

  deadline = time.monotonic() + timeout

  while time.monotonic() < deadline:
    logs = container.logs()
    if text in logs:
      return logs
    time.sleep(0.5)

  pytest.fail(f"'{text}' not found in container logs after {timeout}s")


@pytest.mark.skip(reason="shed probe bug: probe=None doesn't disable default probe")
@shed_config(probe=None)
@shed_env(KLOUDKIT_MODE="worker", QUEUE_CONNECTION="redis")
def test_worker_mode(docker_sidecar, shed_deferred):
  redis = docker_sidecar("redis:alpine")
  container = shed_deferred(envs={"REDIS_HOST": redis.ip()})
  logs = wait_for_log(container, "Starting queue worker...")

  assert "Mode:  worker" in logs
  assert "Starting queue worker..." in logs
  assert "Queue:      default" in logs
  assert "Connection: default" in logs
  assert "Tries:      3" in logs


@pytest.mark.skip(reason="shed probe bug: probe=None doesn't disable default probe")
@shed_config(probe=None)
@shed_env(KLOUDKIT_MODE="scheduler")
def test_scheduler_mode(shed):
  logs = wait_for_log(shed, "Starting scheduler...")

  assert "Mode:  scheduler" in logs
  assert "Starting scheduler..." in logs


@pytest.mark.skip(reason="shed probe bug: probe=None doesn't disable default probe")
@shed_config(probe=None)
@shed_env(KLOUDKIT_MODE="migrate")
def test_migrate_mode(shed_deferred):
  output = shed_deferred(detach=False)

  assert "Mode:  migrate" in output
  assert "Running migrations..." in output
  assert "Setup complete." in output


@pytest.mark.skip(reason="shed probe bug: probe=None doesn't disable default probe")
@shed_env(KLOUDKIT_PORT="9000")
@shed_config(port=9000)
def test_custom_port(shed):
  logs = shed.logs()
  command = "curl -s -o /dev/null -w '%{http_code}' http://localhost:9000"

  assert "Starting Octane on port 9000..." in logs
  assert shed.execute(command) == "200"
