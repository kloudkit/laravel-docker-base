def test_default_environment(shed):
  logs = shed.logs()

  assert "Mode:  app" in logs
  assert "Env:   production" in logs
  assert "Debug: false" in logs


def test_setup_runs_migrations(shed):
  assert "Running migrations..." in shed.logs()


def test_setup_links_storage(shed):
  assert "Linking the storage..." in shed.logs()
  assert (
    shed.execute("test -L /laravel/public/storage && echo linked") == "linked"
  )


def test_setup_optimizes_application(shed):
  assert "Optimizing application..." in shed.logs()


def test_octane_starts_on_default_port(shed):
  assert "Starting Octane on port 8000..." in shed.logs()


def test_connection_tests_skipped(shed):
  assert "Connection tests complete: 0 tested, 6 skipped." in shed.logs()


def test_http_endpoint_available(shed):
  command = "curl -s -o /dev/null -w '%{http_code}' http://localhost:8000/"

  assert shed.execute(command) == "200"
