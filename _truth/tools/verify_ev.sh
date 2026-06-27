#!/usr/bin/env bash
set -euo pipefail

EV_ID="${1:-}"
if [[ -z "$EV_ID" ]]; then
  echo "Usage: $0 <EV-ID>" >&2
  exit 1
fi

RECEIPTS_DIR="_truth/receipts"
NORMALIZED_DIR="_truth/normalized"
STRUCTURED_RECEIPT="$RECEIPTS_DIR/$EV_ID.receipt.json"
SHA256_RECEIPT="$RECEIPTS_DIR/$EV_ID.sha256"
ANCHOR="$RECEIPTS_DIR/$EV_ID.anchor.json"
NORMALIZED="$NORMALIZED_DIR/$EV_ID.json"

echo "Verifying $EV_ID"

for file in "$STRUCTURED_RECEIPT" "$SHA256_RECEIPT" "$NORMALIZED"; do
  if [[ ! -f "$file" ]]; then
    echo "FAIL missing artifact: $file" >&2
    exit 2
  fi
done

NORM_SHA=$(jq -r '.chain.normalized.sha256 // empty' "$STRUCTURED_RECEIPT")
if [[ -z "$NORM_SHA" ]]; then
  echo "FAIL missing normalized sha in structured receipt" >&2
  exit 3
fi

ACTUAL_NORM_SHA=$(sha256sum "$NORMALIZED" | awk '{print $1}')
if [[ "$ACTUAL_NORM_SHA" != "$NORM_SHA" ]]; then
  echo "FAIL normalized hash mismatch" >&2
  echo "expected: $NORM_SHA" >&2
  echo "actual:   $ACTUAL_NORM_SHA" >&2
  exit 3
fi

echo "OK normalized hash"

RECEIPT_SHA=$(awk '{print $1}' "$SHA256_RECEIPT")
RECEIPT_PATH=$(awk '{print $2}' "$SHA256_RECEIPT")
if [[ "$RECEIPT_SHA" != "$NORM_SHA" ]]; then
  echo "FAIL sha256 receipt hash mismatch" >&2
  exit 4
fi
if [[ "$RECEIPT_PATH" != "$NORMALIZED" ]]; then
  echo "FAIL sha256 receipt path mismatch" >&2
  exit 4
fi

echo "OK sha256 receipt"

if [[ -f "$ANCHOR" ]]; then
  ANCHOR_PATH=$(jq -r '.receipt.path // empty' "$ANCHOR")
  ANCHOR_HASH=$(jq -r '.verification_hash // empty' "$ANCHOR")
  ACTUAL_RECEIPT_HASH=$(sha256sum "$STRUCTURED_RECEIPT" | awk '{print $1}')
  if [[ -n "$ANCHOR_PATH" && "$ANCHOR_PATH" != "$STRUCTURED_RECEIPT" ]]; then
    echo "FAIL anchor receipt path mismatch" >&2
    exit 5
  fi
  if [[ -n "$ANCHOR_HASH" && "$ANCHOR_HASH" != "$ACTUAL_RECEIPT_HASH" ]]; then
    echo "FAIL anchor structured receipt hash mismatch" >&2
    exit 5
  fi
  echo "OK anchor"
fi

for key in raw normalized manifest sha256_receipt; do
  COMMIT=$(jq -r ".chain.$key.commit // empty" "$STRUCTURED_RECEIPT")
  if [[ -n "$COMMIT" && "$COMMIT" != "null" ]]; then
    if ! git cat-file -e "${COMMIT}^{commit}" 2>/dev/null; then
      echo "FAIL missing commit for $key: $COMMIT" >&2
      exit 6
    fi
  fi
done

echo "OK commits"
echo "PASS $EV_ID"
