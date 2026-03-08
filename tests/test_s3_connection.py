from kloudkit.testshed.docker.decorators import shed_env
from python_on_whales import DockerException

import pytest


def test_s3_connection_skipped_by_default(shed):
  assert "Skipping s3 connection test." in shed.logs()


@shed_env(
  KLOUDKIT_TEST_S3="true",
  AWS_ACCESS_KEY_ID="minioadmin",
  AWS_SECRET_ACCESS_KEY="minioadmin",
  AWS_DEFAULT_REGION="us-east-1",
  AWS_BUCKET="test",
  AWS_USE_PATH_STYLE_ENDPOINT="true",
)
def test_s3_connection_succeeds(docker_sidecar, shed_deferred):
  minio = docker_sidecar(
    "minio/minio:latest",
    command=["server", "/data"],
    envs={"MINIO_ROOT_USER": "minioadmin", "MINIO_ROOT_PASSWORD": "minioadmin"},
  )

  minio.execute(["mkdir", "-p", "/data/test"])

  container = shed_deferred(envs={"AWS_ENDPOINT": f"http://{minio.ip()}:9000"})
  logs = container.logs()

  assert "Testing s3 connection..." in logs
  assert "S3 connection successful." in logs


@shed_env(
  KLOUDKIT_TEST_S3="true",
  AWS_ENDPOINT="http://nonexistent-host:9000",
  KLOUDKIT_TEST_TIMEOUT=1,
)
def test_s3_connection_fails_without_s3(shed_deferred):
  with pytest.raises(
    DockerException, match="S3 connection failed after 1s."
  ):
    shed_deferred(detach=False)
