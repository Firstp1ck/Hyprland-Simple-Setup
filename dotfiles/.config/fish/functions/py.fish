function py
    switch $argv[1]
        case venv
            python -m venv venv
        case activate
            source venv/bin/activate.fish
        case rm
            rm -rf venv/
        case install
            pip install --trusted-host pypi.org --trusted-host files.pythonhosted.org --verbose $argv[2..-1]
        case '*'
            echo "Usage: py [venv|activate|rm|install] [package_name]"
            echo "  venv     - create a new Python virtual environment"
            echo "  activate - activate the virtual environment"
            echo "  rm       - remove the virtual environment"
            echo "  install  - install package(s) using pip with trusted hosts"
    end
end