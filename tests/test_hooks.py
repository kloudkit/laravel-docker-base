from python_on_whales.exceptions import DockerException

from kloudkit.testshed.docker.probes.log_probe import LogProbe
from kloudkit.testshed.docker.decorators import (
  shed_config,
  shed_env,
  shed_volumes,
)


HOOK_VOLUMES = (
  ("pre-start/01-first.sh", "/laravel/hooks/pre-start/01-first.sh"),
  ("pre-start/02-second.sh", "/laravel/hooks/pre-start/02-second.sh"),
  (
    "pre-start/not-executable.txt",
    "/laravel/hooks/pre-start/not-executable.txt",
  ),
  ("pre-setup/01-setup-hook.sh", "/laravel/hooks/pre-setup/01-setup-hook.sh"),
  ("post-setup/01-setup-hook.sh", "/laravel/hooks/post-setup/01-setup-hook.sh"),
  ("pre-run/01-pre-run.sh", "/laravel/hooks/pre-run/01-pre-run.sh"),
)

FAIL_HOOK_VOLUMES = (
  ("pre-start-fail/01-fail.sh", "/laravel/hooks/pre-start/01-fail.sh"),
)


@shed_volumes(*HOOK_VOLUMES)
@shed_config(probe=LogProbe(pattern=r"pre-start-02-second"))
def test_hooks_execute_in_order(shed_deferred):
  container = shed_deferred()
  logs = container.logs()

  first_pos = logs.index("[test-hook] pre-start-01-first")
  second_pos = logs.index("[test-hook] pre-start-02-second")
  assert first_pos < second_pos


@shed_volumes(*HOOK_VOLUMES)
@shed_config(probe=LogProbe(pattern=r"\[test-hook\] pre-run mode=app"))
def test_hooks_receive_mode_app(shed_deferred):
  container = shed_deferred()
  assert "[test-hook] pre-run mode=app" in container.logs()


@shed_volumes(*HOOK_VOLUMES)
@shed_config(probe=LogProbe(pattern=r"\[test-hook\] pre-run mode=worker"))
@shed_env(KLOUDKIT_MODE="worker", KLOUDKIT_WORKER_MAX_JOBS="1")
def test_hooks_receive_mode_worker(shed_deferred):
  container = shed_deferred()
  assert "[test-hook] pre-run mode=worker" in container.logs()


@shed_volumes(*HOOK_VOLUMES)
@shed_config(probe=None)
@shed_env(KLOUDKIT_MODE="migrate")
def test_hooks_receive_mode_migrate(shed_deferred):
  output = shed_deferred(detach=False)
  assert "[test-hook] pre-run mode=migrate" in output


@shed_volumes(*FAIL_HOOK_VOLUMES)
@shed_config(probe=None)
def test_hook_failure_halts_startup(shed_deferred):
  try:
    output = shed_deferred(detach=False)
  except DockerException as e:
    output = e.stdout or ""

  assert "[test-hook] about-to-fail" in output
  assert "Hook failed:" in output
  assert "Connection tests complete" not in output


@shed_volumes(*FAIL_HOOK_VOLUMES)
@shed_config(probe=LogProbe(pattern=r"Connection tests complete"))
@shed_env(KLOUDKIT_HOOKS_IGNORE_FAILURES="true")
def test_hook_failure_continues_when_ignored(shed_deferred):
  container = shed_deferred()
  logs = container.logs()

  assert "[test-hook] about-to-fail" in logs
  assert "Hook failed (ignored):" in logs
  assert "Connection tests complete" in logs


@shed_volumes(*HOOK_VOLUMES)
@shed_config(probe=LogProbe(pattern=r"Completed.*pre-start hook"))
def test_non_executable_file_skipped_with_warning(shed_deferred):
  container = shed_deferred()
  assert (
    "Hook skipped (not executable): /laravel/hooks/pre-start/not-executable.txt"
    in container.logs()
  )


def test_empty_hooks_no_errors(shed):
  logs = shed.logs()

  assert "Running hook:" not in logs
  assert "Hook skipped" not in logs
  assert "Hook failed" not in logs
  assert "Starting Octane" in logs


@shed_volumes(*HOOK_VOLUMES)
@shed_config(probe=LogProbe(pattern=r"\[test-hook\] post-setup mode=app"))
def test_setup_hooks_fire_in_app_mode(shed_deferred):
  container = shed_deferred()
  logs = container.logs()

  assert "[test-hook] pre-setup mode=app" in logs
  assert "[test-hook] post-setup mode=app" in logs


@shed_volumes(*HOOK_VOLUMES)
@shed_config(probe=None)
@shed_env(KLOUDKIT_MODE="migrate")
def test_setup_hooks_fire_in_migrate_mode(shed_deferred):
  output = shed_deferred(detach=False)

  assert "[test-hook] pre-setup mode=migrate" in output
  assert "[test-hook] post-setup mode=migrate" in output


@shed_volumes(*HOOK_VOLUMES)
@shed_config(probe=LogProbe(pattern=r"\[test-hook\] pre-run mode=worker"))
@shed_env(KLOUDKIT_MODE="worker", KLOUDKIT_WORKER_MAX_JOBS="1")
def test_setup_hooks_do_not_fire_in_worker_mode(shed_deferred):
  container = shed_deferred()
  logs = container.logs()

  assert "[test-hook] pre-setup" not in logs
  assert "[test-hook] post-setup" not in logs
  assert "[test-hook] pre-run mode=worker" in logs


@shed_volumes(*HOOK_VOLUMES)
@shed_config(probe=LogProbe(pattern=r"\[test-hook\] post-setup mode=app"))
@shed_env(KLOUDKIT_MANUAL_SETUP="1")
def test_hooks_fire_with_manual_setup(shed_deferred):
  container = shed_deferred()
  logs = container.logs()

  assert "[test-hook] pre-setup mode=app" in logs
  assert "[test-hook] post-setup mode=app" in logs
  assert "Skipping setup..." in logs
