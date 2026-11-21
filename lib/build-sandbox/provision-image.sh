#!/usr/bin/env bash
# Golden-image provisioning for the WSL2 build sandbox (New-BuildSandbox.ps1 -BuildImage).
# Runs ONCE as root inside a temporary distro imported from a base Ubuntu rootfs.
# This is the only stage that uses the network (apt). Never run it in a distro you use.
set -euo pipefail

ack=0
dotnet_pkg="dotnet-sdk-8.0"
while (($#)); do
  case "$1" in
    --image-build-acknowledged) ack=1 ;;
    --dotnet-package) dotnet_pkg="${2:?missing value}"; shift ;;
    *) echo "unknown argument: $1" >&2; exit 125 ;;
  esac
  shift
done
[[ $ack -eq 1 ]] || { echo "refusing to run without --image-build-acknowledged" >&2; exit 125; }
[[ $(id -u) -eq 0 ]] || { echo "must run as root" >&2; exit 125; }
[[ $dotnet_pkg =~ ^dotnet-sdk-[0-9]+\.[0-9]+$ ]] || { echo "invalid .NET SDK package name" >&2; exit 125; }
# shellcheck disable=SC1091
. /etc/os-release
[[ ${ID:-} == ubuntu ]] || { echo "base rootfs must be Ubuntu (found ${ID:-unknown})" >&2; exit 125; }

log() { printf '[provision %s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
export DEBIAN_FRONTEND=noninteractive

log "Installing toolchains on Ubuntu ${VERSION_ID}"
apt-get update
apt-get -y full-upgrade
apt-get install -y --no-install-recommends \
  ca-certificates util-linux procps file zip unzip xz-utils git jq \
  build-essential gcc g++ gdb make cmake ninja-build pkg-config ccache \
  clang lld lldb clang-format clang-tidy \
  valgrind cppcheck gcovr lcov \
  libgtest-dev libgmock-dev catch2 doctest-dev libbenchmark-dev \
  libfmt-dev libspdlog-dev nlohmann-json3-dev libboost-dev \
  zlib1g-dev libssl-dev libsqlite3-dev \
  mingw-w64 \
  python3 python3-pip python3-venv python3-dev python-is-python3 \
  python3-pytest python3-pytest-cov python3-pytest-mock python3-pytest-timeout python3-hypothesis \
  python3-numpy python3-yaml python3-mypy black flake8 pylint \
  "$dotnet_pkg"

log "Creating unprivileged build user"
if ! id builder >/dev/null 2>&1; then
  useradd --create-home --shell /bin/bash --user-group builder
fi
gpasswd -d builder sudo >/dev/null 2>&1 || true
passwd -l builder >/dev/null

log "Hardening WSL configuration (no Windows drive automount, no interop)"
cat > /etc/wsl.conf <<'EOF'
# Build sandbox: no Windows drive automount, no Windows interop, no systemd.
[boot]
systemd=false

[automount]
enabled=false
mountFsTab=false

[interop]
enabled=false
appendWindowsPath=false

[user]
default=builder
EOF
# Distribution OOBE metadata would try to create an interactive user on first launch.
rm -f /etc/wsl-distribution.conf

cat > /etc/profile.d/build-sandbox.sh <<'EOF'
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
EOF

log "Smoke-testing toolchains as builder"
smoke=$(mktemp -d)
mkdir -p "$smoke/home" "$smoke/tmp"
cat > "$smoke/t.cpp" <<'EOF'
#include <iostream>
int main() { std::cout << "cpp ok\n"; }
EOF
chown -R builder:builder "$smoke"
# Clean environment (as runner.py does): an inherited root XDG_RUNTIME_DIR=/run/user/0 makes .NET's
# named-mutex creation fail for builder ("NuGet-Migrations" IOException).
runuser -u builder -- env -i PATH=/usr/local/bin:/usr/bin:/bin HOME="$smoke/home" TMPDIR="$smoke/tmp" LANG=C.UTF-8 \
  DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 \
  bash -euo pipefail -c '
    cd "$1"
    g++ -std=c++20 -O2 t.cpp -o t-gcc && ./t-gcc
    clang++ -std=c++20 -O2 t.cpp -o t-clang && ./t-clang
    x86_64-w64-mingw32-g++ -std=c++20 -O2 -static t.cpp -o t.exe && file t.exe
    python3 -c "import sys; print(\"python\", sys.version.split()[0])"
    python3 -m pytest --version
    dotnet new console -o cs >/dev/null
    dotnet build cs -c Release -nologo -v quiet
    # Restore (with network, image build only) the packages offline jobs most often need;
    # the global package cache then becomes the read-only offline feed /opt/nuget-offline.
    for t in xunit nunit mstest; do
      dotnet new "$t" -o "test-$t" >/dev/null
      dotnet test "test-$t" -nologo -v quiet
    done
    dotnet new classlib -o libs >/dev/null
    for p in Newtonsoft.Json Moq NSubstitute Microsoft.Extensions.DependencyInjection \
             Microsoft.Extensions.Logging.Console Microsoft.Extensions.Configuration.Json; do
      dotnet add libs package "$p" >/dev/null
    done
    dotnet build libs -nologo -v quiet
    printf "#include <gtest/gtest.h>\n#include <catch2/catch_test_macros.hpp>\n#include <doctest/doctest.h>\n#include <fmt/core.h>\n#include <spdlog/spdlog.h>\n#include <nlohmann/json.hpp>\n#include <boost/algorithm/string.hpp>\n#include <benchmark/benchmark.h>\n" > libs.cpp
    g++ -std=c++20 -fsyntax-only libs.cpp && echo "c++ library headers ok"
    python3 -c "import pytest_cov, hypothesis, numpy, yaml, mypy; print(\"python libraries ok\")"
  ' smoke "$smoke"

log "Publishing offline NuGet feed"
rm -rf /opt/nuget-offline
cp -a "$smoke/home/.nuget/packages" /opt/nuget-offline
chown -R root:root /opt/nuget-offline
chmod -R u=rwX,go=rX /opt/nuget-offline
log "Offline feed: $(find /opt/nuget-offline -name '*.nupkg' | wc -l) packages"
rm -rf "$smoke"

log "Writing image marker"
DOTNET_CLI_HOME=/tmp/marker-dotnet python3 - "$dotnet_pkg" <<'EOF'
import datetime, json, os, subprocess, sys

def first_line(*cmd):
    try:
        out = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
        lines = [l.strip() for l in (out.stdout + out.stderr).splitlines() if l.strip()]
        return lines[0] if lines else ""
    except Exception as exc:  # recorded, not fatal
        return f"unavailable: {exc}"

marker = {
    "schemaVersion": 1,
    "builtUtc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "dotnetPackage": sys.argv[1],
    "os": first_line("sh", "-c", ". /etc/os-release && echo $PRETTY_NAME"),
    "toolchains": {
        "gcc": first_line("gcc", "--version"),
        "clang": first_line("clang++", "--version"),
        "mingw-w64": first_line("x86_64-w64-mingw32-g++", "--version"),
        "cmake": first_line("cmake", "--version"),
        "python": first_line("python3", "--version"),
        "dotnet": first_line("dotnet", "--version"),
        "valgrind": first_line("valgrind", "--version"),
        "cppcheck": first_line("cppcheck", "--version"),
        "gcovr": first_line("gcovr", "--version"),
        "black": first_line("black", "--version"),
        "mypy": first_line("mypy", "--version"),
    },
    "nugetOfflinePackages": sorted(os.listdir("/opt/nuget-offline")) if os.path.isdir("/opt/nuget-offline") else [],
}
with open("/etc/build-sandbox-image.json", "w", encoding="utf-8") as fh:
    json.dump(marker, fh, indent=2)
print(json.dumps(marker, indent=2))
EOF

log "Cleaning image"
apt-get clean
rm -rf /var/lib/apt/lists/* /root/.dotnet /root/.nuget /root/.cache /root/.bash_history
# /tmp/.X11-unix is WSLg's read-only mount, not image content (export only captures the root fs).
find /tmp /var/tmp -mindepth 1 -maxdepth 1 ! -name .X11-unix -exec rm -rf {} +
find /var/log -type f -exec truncate -s 0 {} +
log "Golden image ready"
