import pytest


STORAGE_DIRS = [
  "bootstrap/cache",
  "storage/framework/cache",
  "storage/framework/sessions",
  "storage/framework/testing",
  "storage/framework/views",
  "storage/logs",
]

REQUIRED_EXTENSIONS = [
  "bcmath",
  "bz2",
  "curl",
  "exif",
  "gd",
  "intl",
  "pcntl",
  "pdo_pgsql",
  "Zend OPcache",
  "redis",
  "sockets",
  "zip",
]

INI_SETTINGS = {
  "memory_limit": "256M",
  "upload_max_filesize": "32M",
  "post_max_size": "100M",
  "opcache.enable": "1",
  "opcache.jit": "tracing",
}


def test_php_version(shed):
  assert "PHP 8.5" in shed.execute("php -v")


@pytest.mark.parametrize("extension", REQUIRED_EXTENSIONS)
def test_php_extensions_loaded(shed, extension):
  assert extension in shed.execute("php -m")


@pytest.mark.parametrize(("setting", "expected"), INI_SETTINGS.items())
def test_php_ini_settings(shed, setting, expected):
  assert shed.execute.bash(f"php -r 'echo ini_get(\"{setting}\");'") == expected


def test_php_ini_expose_php_off(shed):
  assert shed.execute.bash("php -r 'echo ini_get(\"expose_php\");'") in (
    "",
    "Off",
    "0",
  )


def test_composer_available(shed):
  assert shed.execute("composer --version")


def test_system_packages_curl(shed):
  assert shed.execute("curl --version")


def test_system_packages_unzip(shed):
  assert shed.execute("unzip -v")


def test_system_packages_vi(shed):
  assert shed.execute("vi --version")


def test_working_directory(shed):
  assert shed.execute("pwd") == "/laravel"


def test_runs_as_laravel_user(shed):
  assert shed.execute("whoami") == "laravel"
  assert shed.execute("id -u") == "1000"
  assert shed.execute("stat -c '%U:%G' /laravel") == "laravel:laravel"


@pytest.mark.parametrize("directory", STORAGE_DIRS)
def test_storage_dirs_exist(shed, directory):
  assert shed.fs.exists(f"/laravel/{directory}")


@pytest.mark.parametrize("directory", STORAGE_DIRS)
def test_storage_dirs_writable(shed, directory):
  shed.execute(f"touch /laravel/{directory}/test_write")


def test_caddy_dir_writable(shed):
  shed.execute("touch /data/caddy/test_write")
  shed.execute("touch /config/caddy/test_write")
