from kloudkit.testshed.docker.decorators import shed_env
from python_on_whales import DockerException

import pytest


def test_smtp_connection_skipped_by_default(shed):
  assert "Skipping smtp connection test." in shed.logs()


@shed_env(
  KLOUDKIT_TEST_SMTP="true",
  MAIL_MAILER="smtp",
  MAIL_PORT="1025",
)
def test_smtp_connection_succeeds(docker_sidecar, shed_deferred):
  mailpit = docker_sidecar("axllent/mailpit:latest")

  container = shed_deferred(envs={"MAIL_HOST": mailpit.ip()})
  logs = container.logs()

  assert "Testing smtp connection..." in logs
  assert "Smtp connection successful." in logs


@shed_env(
  KLOUDKIT_TEST_SMTP="true",
  MAIL_MAILER="smtp",
  MAIL_HOST="nonexistent-host",
  KLOUDKIT_TEST_TIMEOUT=1,
)
def test_smtp_connection_fails_without_smtp(shed_deferred):
  with pytest.raises(DockerException, match="Smtp connection failed after 1s."):
    shed_deferred(detach=False)
