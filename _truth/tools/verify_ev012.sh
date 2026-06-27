#!/bin/bash
# EV-012 Verifier - Single source of truth chain check
# Usage: ./verify_ev012.sh

set -euo pipefail

ANCHOR="_truth/receipts/EV-012.anchor.json"
RECEIPT="_truth/receipts/EV-012.receipt.json"
SHA256_RECEIPT="_truth/receipts/EV-012.sha256"

echo "🔍 Verifying EV-012 Zora Market Snapshot chain..."

# 1. Anchor exists?
if [[ ! -f "$ANCHOR" ]]; then
  echo "❌ Anchor missing: $ANCHOR"
  exit 1
fi

# 2. Receipt exists + hash matches anchor?
if [[ ! -f "$RECEIPT" ]]; then
  echo "❌ Structured receipt missing: $RECEIPT"
  exit 1
fi
VERIFICATION_HASH=$(jq -r '.verification_hash' "$ANCHOR")
ACTUAL_RECEIPT_HASH=$(sha256sum "$RECEIPT" | awk '{print $1}')
if [[ "$ACTUAL_RECEIPT_HASH" != "$VERIFICATION_HASH" ]]; then
  echo "❌ Receipt hash mismatch!"
  echo "Expected (from anchor): $VERIFICATION_HASH"
  echo "Actual:               $ACTUAL_RECEIPT_HASH"
  exit 1
fi

# 3. SHA256 receipt exists?
if [[ ! -f "$SHA256_RECEIPT" ]]; then
  echo "❌ SHA256 receipt missing: $SHA256_RECEIPT"
  exit 1
fi

# 4. Parse normalized path + expected hash from SHA256 receipt
NORMALIZED=$(awk '{print $2}' "$SHA256_RECEIPT")
EXPECTED_NORM_SHA=$(awk '{print $1}' "$SHA256_RECEIPT")

if [[ -z "$NORMALIZED" || -z "$EXPECTED_NORM_SHA" ]]; then
  echo "❌ Failed to parse normalized path/hash from $SHA256_RECEIPT"
  exit 1
fi

# 5. Normalized artifact exists + hash matches?
if [[ ! -f "$NORMALIZED" ]]; then
  echo "❌ Normalized snapshot missing: $NORMALIZED"
  exit 1
fi
ACTUAL_NORM_SHA=$(sha256sum "$NORMALIZED" | awk '{print $1}')
if [[ "$ACTUAL_NORM_SHA" != "$EXPECTED_NORM_SHA" ]]; then
  echo "❌ Normalized content hash mismatch!"
  echo "Expected (from .sha256): $EXPECTED_NORM_SHA"
  echo "Actual:                  $ACTUAL_NORM_SHA"
  exit 1
fi

echo "✅ EV-012 verification SUCCESS: Full chain intact (anchor → receipt → sha256 → normalized)"
exit 0
