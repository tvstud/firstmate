#!/usr/bin/env bash
# Behavior tests for fm-harness-quota.sh agy probe exits.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

QUOTA="$ROOT/bin/fm-harness-quota.sh"
TMP_ROOT=$(fm_test_tmproot fm-harness-quota)
fakebin=$(fm_fakebin "$TMP_ROOT/fake")

cat > "$fakebin/agy" <<'SH'
#!/usr/bin/env bash
echo "Individual quota reached for today" >&2
exit 1
SH
chmod +x "$fakebin/agy"

set +e
out=$(FM_AGY_QUOTA_BIN="$fakebin/agy" PATH="$fakebin:$PATH" "$QUOTA" agy 2>/dev/null)
rc=$?
set -u
expect_code 1 "$rc" "quota message should exit 1"
assert_contains "$out" 'AGY_QUOTA_EXHAUSTED' "quota exit should print AGY_QUOTA_EXHAUSTED"
pass "fm-harness-quota detects agy quota exhaustion"

cat > "$fakebin/agy" <<'SH'
#!/usr/bin/env bash
printf 'ok\n'
exit 0
SH
chmod +x "$fakebin/agy"

set +e
FM_AGY_QUOTA_BIN="$fakebin/agy" PATH="$fakebin:$PATH" "$QUOTA" agy >/dev/null
rc=$?
set -u
expect_code 0 "$rc" "successful agy probe should exit 0"
pass "fm-harness-quota accepts available agy"

cat > "$fakebin/agy" <<'SH'
#!/usr/bin/env bash
echo "something else failed" >&2
exit 3
SH
chmod +x "$fakebin/agy"

set +e
FM_AGY_QUOTA_BIN="$fakebin/agy" PATH="$fakebin:$PATH" "$QUOTA" agy >/dev/null 2>/dev/null
rc=$?
set -u
expect_code 2 "$rc" "non-quota agy failure should exit 2"
pass "fm-harness-quota treats inconclusive agy probe as exit 2"