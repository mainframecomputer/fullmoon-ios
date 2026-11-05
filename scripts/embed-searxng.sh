#!/bin/sh
# Created by Sébastien DAGUIN
set -eu

case "${PLATFORM_NAME}" in
    iphoneos|iphonesimulator)
        exec /usr/bin/python3 "${SRCROOT}/scripts/embed-ios-searxng.py"
        ;;
esac

[ "${PLATFORM_NAME}" = macosx ] || exit 0

runtime="${SRCROOT}/build/SearXNG/python"
if [ ! -x "${runtime}/bin/python3" ]; then
    echo "error: Préparer SearXNG : python3 ../NoctisAi/infrastructure/searxng/setup_runtime.py --standalone --destination build/SearXNG" >&2
    exit 1
fi

if ! /usr/bin/lipo -verify_arch ${ARCHS} "${runtime}/bin/python3"; then
    echo "error: Le Python SearXNG préparé ne couvre pas les architectures de cette compilation : ${ARCHS}." >&2
    exit 1
fi

app="${TARGET_BUILD_DIR}/${WRAPPER_NAME}"
destination="${app}/Contents/Resources/SearXNG/python"
mkdir -p "${app}/Contents"
if [ -d "${destination}" ]; then
    rm -rf "${destination}"
fi

/usr/bin/python3 "${SRCROOT}/../NoctisAi/infrastructure/searxng/package_runtime.py" \
    "${runtime}" "${app}" \
    --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" \
    --entitlements "${SRCROOT}/scripts/searxng.entitlements"
