import subprocess

from kloudkit.testshed.docker import Container
from kloudkit.testshed.docker.probes.http_probe import HttpProbe

import pytest


pytest_plugins = ["kloudkit.testshed.fixtures"]


class LaravelContainer(Container):
  DEFAULT_USER = "laravel"
  DEFAULT_SHELL = "bash"


@pytest.fixture(scope="session")
def shed_tag(shed_state):
  """Build a derived image with a real Laravel skeleton + Octane."""

  tag = f"{shed_state.image}:test-laravel"
  subprocess.run(
    [
      "docker", "build",
      "--build-arg", f"BASE_IMAGE={shed_state.image_and_tag}",
      "-t", tag,
      str(shed_state.tests_path.parent),
    ],
    check=True,
  )
  return tag


@pytest.fixture(scope="session")
def shed_container_defaults():
  return {
    "container_class": LaravelContainer,
    "probe": HttpProbe(port=8000),
  }
