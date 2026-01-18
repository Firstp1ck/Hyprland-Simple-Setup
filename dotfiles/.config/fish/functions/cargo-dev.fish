# Run cargo fmt and cargo clippy for Rust projects, auto-fix warnings if detected.
function cargo-dev
  # Icons for status
  set -l OK "✅"
  set -l FAIL "❌"
  # Run formatter
  cargo fmt
  if test $status -ne 0
    echo "$FAIL cargo fmt failed"
    return $status
  end
  echo "$OK cargo fmt completed"

  # Run Clippy and auto-fix if warnings are detected
  set -l clippy_tmp (mktemp)
  cargo clippy --all-targets --all-features -- -D warnings 2>&1 | tee $clippy_tmp
  set -l clippy_status $pipestatus[1]
  if test $clippy_status -ne 0
    echo "$FAIL cargo clippy failed"
    rm -f $clippy_tmp
    return $clippy_status
  end
  if grep -q "warning:" $clippy_tmp
    echo "ℹ️ Clippy warnings detected; attempting automatic fixes..."
    cargo clippy --fix --allow-dirty
    if test $status -ne 0
      echo "$FAIL cargo clippy --fix failed"
      rm -f $clippy_tmp
      return 1
    end
    echo "$OK cargo clippy --fix applied"

    # Re-run clippy and check for remaining warnings
    set -l clippy_tmp2 (mktemp)
    cargo clippy --all-targets --all-features -- -D warnings 2>&1 | tee $clippy_tmp2
    set -l clippy_status2 $pipestatus[1]
    if test $clippy_status2 -ne 0
      echo "$FAIL cargo clippy (post-fix) failed"
      rm -f $clippy_tmp2
      rm -f $clippy_tmp
      return $clippy_status2
    end
    if grep -q "warning:" $clippy_tmp2
      echo "$FAIL Clippy still has warnings"
    else
      echo "$OK Clippy warnings fixed, no warnings anymore"
    end
    rm -f $clippy_tmp2
  else
    echo "$OK cargo clippy completed (no warnings)"
  end
  rm -f $clippy_tmp

  # Run tests
  cargo test -- --test-threads=1
  if test $status -ne 0
    echo "$FAIL cargo test failed"
    return $status
  end
  echo "$OK cargo test passed"

  # Run static checks
  cargo check
  if test $status -ne 0
    echo "$FAIL cargo check failed"
    return $status
  end
  echo "$OK cargo check passed"

  # Build the application
  cargo build $argv
  if test $status -ne 0
    echo "$FAIL cargo build failed"
    return $status
  end
  echo "$OK cargo build succeeded"
end
