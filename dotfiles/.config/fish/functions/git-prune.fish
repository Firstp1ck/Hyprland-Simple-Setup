
function git-prune --description "List and optionally delete orphaned git branches (local & remote)"
    # Ensure we are inside a git repo
    if not command git rev-parse --is-inside-work-tree >/dev/null 2>/dev/null
        echo "Not a git repository."
        return 1
    end

    # Refresh and prune stale remote-tracking refs
    echo "Fetching and pruning remotes..."
    command git fetch --all --prune

    # Collect orphaned local branches: upstream is [gone]
    set -l orphan_locals (command git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
        | awk '$2 == "[gone]" {print $1}')

    # Collect orphaned remote branches: on origin but no matching local branch name
    set -l local_names (command git for-each-ref --format='%(refname:short)' refs/heads)
    set -l orphan_remotes (command git for-each-ref --format='%(refname:short)' refs/remotes/origin \
        | grep -vE '^origin/(HEAD|main|master)$' \
        | awk -v locals="$local_names" '
            BEGIN{
                n=split(locals, a, " ")
                for(i=1;i<=n;i++) L[a[i]]=1
            }
            {
                # convert origin/feature/x to feature/x for comparison
                name=$0; sub(/^origin\//, "", name)
                if(!(name in L)) print name
            }')

    echo
    echo "Orphaned local branches (upstream gone):"
    if test (count $orphan_locals) -gt 0
        for b in $orphan_locals
            echo "  $b"
        end
    else
        echo "  (none)"
    end

    echo
    echo "Remote-only branches on origin (no same-named local):"
    if test (count $orphan_remotes) -gt 0
        for b in $orphan_remotes
            echo "  origin/$b"
        end
    else
        echo "  (none)"
    end

    # Ask to delete orphaned locals
    if test (count $orphan_locals) -gt 0
        read -l -P "Delete orphaned LOCAL branches listed above? [y/N] " ans
        if test "$ans" = "y" -o "$ans" = "Y"
            for b in $orphan_locals
                # Use -d (safe) first; fallback to -D if not merged and user agrees
                if ! command git branch -d -- $b
                    read -l -P "Branch '$b' not fully merged. Force delete? [y/N] " f
                    if test "$f" = "y" -o "$f" = "Y"
                        command git branch -D -- $b
                    end
                end
            end
        end
    end

    # Ask to delete orphaned remotes
    if test (count $orphan_remotes) -gt 0
        read -l -P "Delete REMOTE branches on origin with no local counterpart? [y/N] " ans2
        if test "$ans2" = "y" -o "$ans2" = "Y"
            for b in $orphan_remotes
                command git push origin --delete -- $b
            end
            # Re-prune after remote deletes
            command git fetch --prune origin
        end
    end
end
