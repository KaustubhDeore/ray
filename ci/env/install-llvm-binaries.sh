#!/usr/bin/env bash

# This script downloads LLVM prebuilt binaries, extract them to a user specified location, and setup Bazel
# with this location. Example usage:
#
# (Repository root) $ ci/env/install-llvm-binaries.sh <optional URL to LLVM> <optional target directory>
# (Repository root) $ bazel build --config=llvm //:ray_pkg
#
# If the arguments are unspecified, the default ${LLVM_URL} and ${TARGET_DIR} are used. They are set to be
# suitable for CI, but may not be suitable under other environments.

set -eo pipefail

printInfo() {
    printf '\033[32mINFO:\033[0m %s\n' "$@"
}

printError() {
    printf '\033[31mERROR:\033[0m %s\n' "$@"
}

log_err() {
    printError "Setting up LLVM encountered an error"
}

trap '[ $? -eq 0 ] || log_err' EXIT

LLVM_URL="https://github.com/llvm/llvm-project/releases/download/llvmorg-12.0.1/clang+llvm-12.0.1-x86_64-linux-gnu-ubuntu-16.04.tar.xz"
TARGET_DIR="/opt/llvm"
LLVM_DOWNLOAD_URL_FILENAME="${TARGET_DIR}/llvm_download_url.txt"

install_llvm() {
  local url targetdir

  if [ $# -ge 1 ]; then
    url="$1"
  else
    url="${LLVM_URL}"
  fi
  if [ $# -ge 2 ]; then
    targetdir="$2"
  else
    targetdir="${TARGET_DIR}"
  fi
  case "${OSTYPE}" in
    msys)
      printError "This script does not support installing LLVM on Windows yet. Please install with LLVM's instruction."
      exit 1
      ;;
    linux-gnu)
      osversion="${OSTYPE}-$(sed -n -e '/^PRETTY_NAME/ { s/^[^=]*="\(.*\)"/\1/g; s/ /-/; s/\([0-9]*\.[0-9]*\)\.[0-9]*/\1/; s/ .*//; p }' /etc/os-release | tr '[:upper:]' '[:lower:]')"
      ;;
    darwin*)
      printError "This script does not support installing LLVM on MacOS yet. Please use the system compiler, "
      printError "install with Homebrew or install with LLVM's instruction."
      exit 1
      ;;
    *)
      printError "Unsupported system ${OSTYPE}"
      exit 1
  esac
  case "${osversion}" in
    linux-gnu-ubuntu*)
      printInfo "Downloading LLVM from ${url}"

      WGET_OPTIONS=""
      if [ -n "${BUILDKITE-}" ]; then
        # Non-verbose output in BUILDKITE
        WGET_OPTIONS="-nv"
      fi

      wget ${WGET_OPTIONS} -c $url -O llvm.tar.xz

      printInfo "Installing LLVM to ${targetdir}"
      mkdir -p "${targetdir}"
      tar -xf ./llvm.tar.xz -C "${targetdir}" --strip-components=1
      rm llvm.tar.xz
      ;;
    *)
      printError "Unsupported Linux distro ${OSTYPE}"
      exit 1
      ;;
  esac

  printInfo "Updating .bazelrc"
  echo "
# ==== --config=llvm options generated by ci/env/install-llvm-binaries.sh
build:llvm --action_env='PATH=${targetdir}/bin:$PATH'
build:llvm --action_env='BAZEL_COMPILER=${targetdir}/bin/clang'
build:llvm --action_env='CC=${targetdir}/bin/clang'
build:llvm --action_env='CXX=${targetdir}/bin/clang++'
build:llvm --action_env='LLVM_CONFIG=${targetdir}/bin/llvm-config'
build:llvm --repo_env='LLVM_CONFIG=${targetdir}/bin/llvm-config'
build:llvm --linkopt='-fuse-ld=${targetdir}/bin/ld.lld'
build:llvm --linkopt='-L${targetdir}/lib'
build:llvm --linkopt='-Wl,-rpath,${targetdir}/lib'
# ==== end of --config=llvm options generated by ci/env/install-llvm-binaries.sh" >> .llvm-local.bazelrc

  echo "$url" > $LLVM_DOWNLOAD_URL_FILENAME
  printInfo "LLVML installed and URL of current llvm install logged to $LLVM_DOWNLOAD_URL_FILENAME"
}

if [ -n "${BUILDKITE-}" ] && [ -f "$LLVM_DOWNLOAD_URL_FILENAME" ]; then
  read -r line < "$LLVM_DOWNLOAD_URL_FILENAME"
  if [ "$line" == "$LLVM_URL" ]; then
    printInfo "Skipping llvm download/install on Buildkite because LLVM was previously installed from the same URL ${line}."
    exit 0
  fi
fi


if [ ! -f ".bazelrc" ]; then
    printError ".bazelrc not found under working directory. Please run this script under repository root."
    exit 1
fi

install_llvm "$@"
