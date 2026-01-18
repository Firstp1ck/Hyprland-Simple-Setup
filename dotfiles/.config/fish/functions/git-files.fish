function git-files --description "Find files in src/ with more than N lines (default 600)"
    set -l threshold (test -n "$argv[1]" && echo "$argv[1]" || echo "600")
    git ls-files src/ | xargs wc -l | sort -rn | awk -v limit=$threshold '$2 != "total" && $1 > limit {print}'
end