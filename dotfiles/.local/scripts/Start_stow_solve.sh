#!/bin/bash

# Check if stow is installed
if ! command -v stow >/dev/null 2>&1; then
    echo "Error: stow is not installed. Please install it first."
    exit 1
fi

# Get the directory containing the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# If script is in .dotfiles/.local/scripts, we need to go up two levels to get to the dotfiles root
DOTFILES_DIR="$(dirname "$(dirname "$SCRIPT_DIR")")"

# Change to dotfiles directory
cd "$DOTFILES_DIR" || {
    echo "Error: Could not change to dotfiles directory"
    exit 1
}

echo "Running stow from $DOTFILES_DIR to identify conflicted files..."
output=$(stow . 2>&1)

# Check if stow reported conflicts
if ! echo "$output" | grep -q "would cause conflicts"; then
    if echo "$output" | grep -q "Error"; then
        echo "Error running stow. Output:"
        echo "$output"
        exit 1
    else
        echo "No conflicted files found."
        exit 0
    fi
fi

echo "Conflicts detected. Processing..."
echo "$output"

# Extract the conflicted file paths using the new format
# Example: "* cannot stow .dotfiles/.nanorc over existing target .nanorc since neither a link nor a directory and --adopt not specified"
conflicted_files=$(echo "$output" | grep "cannot stow" | sed -E 's/.*cannot stow ([^ ]+) over existing target ([^ ]+).*/\2/')

# Check if there are any conflicted files
if [ -z "$conflicted_files" ]; then
    echo "Failed to extract conflicted files from output."
    exit 1
fi

echo "Conflicted files found:"
echo "$conflicted_files"

# Loop through each conflicted file and rename it
while IFS= read -r file; do
    # Skip if empty line
    [ -z "$file" ] && continue
    
    # Add HOME directory prefix if the file path is relative
    if [[ "$file" != /* ]]; then
        file="$HOME/$file"
    fi
    
    if [ -e "$file" ]; then
        if mv -n "$file" "$file.bak"; then
            echo "Renamed '$file' to '$file.bak'"
        else
            echo "Error: Failed to rename '$file'"
            exit 1
        fi
    else
        echo "Warning: File '$file' does not exist: $file"
    fi
done <<< "$conflicted_files"

# Run stow again
echo "Running stow again..."
if ! stow .; then
    echo "Error: Final stow command failed"
    exit 1
fi

echo "Completed successfully!"