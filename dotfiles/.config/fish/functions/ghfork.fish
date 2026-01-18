# Forks a GitHub repository using gh CLI and clones it locally
function ghfork
    gh repo fork $argv[1]/$argv[2] --clone
end