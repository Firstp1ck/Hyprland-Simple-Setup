# Activates a Python virtual environment in the current directory by sourcing activate.fish from .venv, venv, .env, or env (first found)
function source-activate-py
    if test -e .venv/bin/activate.fish
        source .venv/bin/activate.fish
    else if test -e venv/bin/activate.fish
        source venv/bin/activate.fish
    else if test -e .env/bin/activate.fish
        source .env/bin/activate.fish
    else if test -e env/bin/activate.fish
        source env/bin/activate.fish
    else
        echo "No virtualenv found."
        return 1
    end
end
