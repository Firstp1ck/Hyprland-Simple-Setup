# Pushes changes to an AUR package: runs makepkg --nobuild, updates .SRCINFO, commits, and pushes to remote.
function aur-push --description 'makepkg --nobuild, update .SRCINFO, commit, push'
    # Determine commit message from args or use default
    set -l msg (string join ' ' -- $argv)
    if test -z "$msg"
        set msg "Update Git Version in PKGBUILD"
    end

    # Icons for status
    set -l OK "✅"
    set -l FAIL "❌"

    # Ensure we're in a PKGBUILD directory
    if not test -f PKGBUILD
        printf "%s PKGBUILD not found in current directory: %s\n" $FAIL (pwd) >&2
        return 1
    end

    # Detect pkgname and whether this is a -bin package
    set -l pkgname (awk -F= '/^pkgname=/{print $2}' PKGBUILD | sed "s/[\"']//g")
    set -l is_bin 0
    if string match -r '.*-bin$' -- "$pkgname"
        set is_bin 1
    end

    # Build steps with -bin recovery for checksum drift
    if makepkg --nobuild
        echo "$OK makepkg --nobuild completed"
    else
        if test $is_bin -eq 1
            echo "ℹ️ makepkg --nobuild failed; attempting checksum refresh via updpkgsums for -bin package"
            if type -q updpkgsums
                if updpkgsums
                    echo "$OK Checksums updated via updpkgsums"
                    if makepkg --nobuild
                        echo "$OK makepkg --nobuild completed after checksum update"
                    else
                        echo "$FAIL makepkg --nobuild still failing after checksum update" >&2
                        return $status
                    end
                else
                    echo "$FAIL updpkgsums failed" >&2
                    return $status
                end
            else
                echo "$FAIL updpkgsums not found (install pacman-contrib)" >&2
                return 127
            end
        else
            echo "$FAIL makepkg --nobuild failed" >&2
            return $status
        end
    end

    if makepkg --printsrcinfo > .SRCINFO
        echo "$OK .SRCINFO updated"
    else
        echo "$FAIL .SRCINFO update failed" >&2
        return $status
    end

    # Stage changes
    if git add .
        echo "$OK Staged PKGBUILD and .SRCINFO changes"
    else
        echo "$FAIL Failed to stage PKGBUILD/.SRCINFO" >&2
        return $status
    end

    # Commit handling
    if git diff --quiet --cached
        echo "$OK Nothing to commit (no staged changes)"
    else
        if git commit -m "$msg"
            echo "$OK Committed: $msg"
        else
            echo "$FAIL Commit failed" >&2
            return $status
        end
    end

    # Push
    if git push origin master
        echo "$OK Pushed to origin master"
    else
        echo "$FAIL Push failed" >&2
        return $status
    end
end
