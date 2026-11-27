#!/bin/sh
# Download the pinned fixtures into fixtures/ and verify their hashes:
# the ONNX Runtime NuGet package (SHA-512), plus the e2e model + vocab
# (SHA-256).
# Nothing fetched here is ever committed; fixtures/ is gitignored, and
# ONNX Runtime is a runtime component the DLL loads dynamically — the
# fetch exists for the e2e proof and as a known-good source for users.
set -eu
cd "$(dirname "$0")"
# shellcheck disable=SC1091
. ./pins.txt
mkdir -p fixtures

sha_of() {  # sha_of <bits: 256|512> <file>
    if command -v "sha$1sum" >/dev/null 2>&1; then
        "sha$1sum" "$2" | awk '{print $1}'
    else
        shasum -a "$1" "$2" | awk '{print $1}'
    fi
}

fetch() {  # fetch <url> <file> <hash> [bits, default 256]
    url="$1"; file="$2"; want="$3"; bits="${4:-256}"
    if [ ! -f "fixtures/$file" ]; then
        echo "downloading $url"
        curl -fL "$url" -o "fixtures/$file"
    fi
    got=$(sha_of "$bits" "fixtures/$file")
    if [ "$got" != "$want" ]; then
        echo "SHA-$bits MISMATCH for $file" >&2
        echo "  pinned: $want" >&2
        echo "  actual: $got" >&2
        exit 1
    fi
    echo "verified $file ($got)"
}

case "$(uname -s)" in
    Linux) ;;
    *)
        echo "fetch.sh supports Linux x64 hosts; on Windows use fetch.ps1." >&2
        echo "Other platforms: get ONNX Runtime $ORT_VERSION from the NuGet package" >&2
        echo "  Microsoft.ML.OnnxRuntime (runtimes/<platform>/native/)." >&2
        exit 1
        ;;
esac

fetch "$ORT_NUPKG_URL" "$ORT_NUPKG_FILE" "$ORT_NUPKG_SHA512" 512
fetch "$TEST_MODEL_URL" "$TEST_MODEL_NAME" "$TEST_MODEL_SHA256"
fetch "$TEST_VOCAB_URL" "$TEST_VOCAB_NAME" "$TEST_VOCAB_SHA256"

# Lay the runtime out as fixtures/ort/lib/libonnxruntime.so (the path
# the e2e test uses). A .nupkg is a zip archive; only the linux-x64
# native files are taken from it.
rm -rf fixtures/ort
mkdir -p fixtures/ort/lib
unzip -q -j -o "fixtures/$ORT_NUPKG_FILE" 'runtimes/linux-x64/native/*' -d fixtures/ort/lib
[ -f fixtures/ort/lib/libonnxruntime.so ] || { echo "libonnxruntime.so not found in the NuGet package" >&2; exit 1; }
echo "runtime ready under fixtures/ort; model at fixtures/$TEST_MODEL_NAME; vocab at fixtures/$TEST_VOCAB_NAME"
echo "e2e: EK_ORT_LIB=fixtures/ort/lib/libonnxruntime.so EK_MODEL=fixtures/$TEST_MODEL_NAME EK_VOCAB=fixtures/$TEST_VOCAB_NAME cargo test --test e2e -- --ignored --nocapture"
