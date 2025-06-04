function g
    switch $argv[1]
        case a
            command git add . 
        case c
            command git add .
            command git commit -m $argv[2]
        case ps
            command git add .
            command git commit -m $argv[2]
            command git push
        case pl
            command git pull
        case s
            command git status
        case '*'
            echo "Usage: g [c|ps|pl|s] [commit_message]"
            echo "  c  - commit changes"
            echo "  ps - commit and push changes"
            echo "  pl - pull changes"
            echo "  s  - show status"
    end
end