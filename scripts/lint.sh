#!/bin/sh
# Created by Sébastien DAGUIN
set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
version=0.65.1
cache="${TMPDIR:-/tmp}/noctis-swiftlint-${version}"
binary="${SWIFTLINT_BIN:-${cache}/swiftlint}"

if [ ! -x "$binary" ]; then
    archive=$(mktemp)
    trap 'rm -f "$archive"' EXIT HUP INT TERM
    curl --fail --location --silent --show-error \
        "https://github.com/realm/SwiftLint/releases/download/${version}/portable_swiftlint.zip" \
        --output "$archive"
    printf '%s  %s\n' 'c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0' "$archive" | shasum -a 256 -c -
    mkdir -p "$cache"
    unzip -oq "$archive" -d "$cache"
fi

if [ "$("$binary" version)" != "$version" ]; then
    echo "error: SwiftLint ${version} est requis." >&2
    exit 1
fi

cd "$project_root"
"$binary" lint --strict --quiet --config .swiftlint.yml "$@"
