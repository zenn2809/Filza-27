#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="$(xcrun --sdk macosx --show-sdk-path)"
xcrun --sdk macosx clang -fobjc-arc -fblocks -framework Foundation \
  -I"$ROOT" "$ROOT/WebDAVPathResolver.m" "$ROOT/tests/WebDAVPathResolverTests.m" \
  -isysroot "$SDK" -o "$ROOT/.webdav-path-resolver-tests"
"$ROOT/.webdav-path-resolver-tests"
