#!/bin/bash

# Log file location
LOG_FILE="$HOME/stow_solve.log"

# Function to log messages
log() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] [$level] $message" | tee -a "$LOG_FILE"
}

# Add a separator line to indicate new script run
echo "----------------------------------------" >> "$LOG_FILE"
log "INFO" "Starting stow solve script"

# Function to restore moved symlinks and cleanup
restore_symlinks() {
    if [ ${#moved_symlinks[@]} -gt 0 ]; then
        log "INFO" "Restoring moved absolute symlinks..."
        for relpath in "${moved_symlinks[@]}"; do
            mkdir -p "$(dirname "$relpath")"
            if mv "$TEMP_SYMLINK_DIR/$relpath" "$relpath"; then
                log "INFO" "Restored absolute symlink: $relpath"
            else
                log "ERROR" "Failed to restore symlink: $relpath"
            fi
        done
        log "INFO" "All symlinks restored"
    else
        log "INFO" "No symlinks to restore"
    fi
    
    # Always remove the temp directory regardless of symlinks
    if [ -d "$TEMP_SYMLINK_DIR" ]; then
        rm -rf "$TEMP_SYMLINK_DIR"
        log "INFO" "Temporary directory removed: $TEMP_SYMLINK_DIR"
    fi
}

# Function to cleanup and exit
cleanup_and_exit() {
    local exit_code=$1
    log "INFO" "Performing cleanup before exit (code: $exit_code)"
    restore_symlinks
    log "INFO" "Script completed with exit code: $exit_code"
    exit "$exit_code"
}

# Check if stow is installed
if ! command -v stow >/dev/null 2>&1; then
    log "ERROR" "stow is not installed. Please install it first."
    exit 1
fi

# Set DOTFILES_DIR to /home/firstpick/dotfiles
DOTFILES_DIR="$HOME/dotfiles"
log "INFO" "Using dotfiles directory: $DOTFILES_DIR"

# Change to dotfiles directory
cd "$DOTFILES_DIR" || {
    log "ERROR" "Could not change to dotfiles directory"
    exit 1
}

log "INFO" "Running stow from $DOTFILES_DIR to identify conflicted files..."
output=$(stow -t "$HOME" . 2>&1)
log "DEBUG" "Stow output: $output"

# Detect absolute symlink source warnings and extract the problematic files
abs_symlinks=$(echo "$output" | grep "source is an absolute symlink" | sed -E 's/.*source is an absolute symlink[[:space:]]+([^ ]+)[[:space:]]+=>.*/\1/')
if [ -n "$abs_symlinks" ]; then
    log "INFO" "Detected absolute symlinks that need processing"
else
    log "INFO" "No absolute symlinks detected"
fi

# If there are any, move them out of the way
TEMP_SYMLINK_DIR="$DOTFILES_DIR/.stow_abs_symlinks_tmp"
mkdir -p "$TEMP_SYMLINK_DIR"
log "INFO" "Created temporary directory for symlinks: $TEMP_SYMLINK_DIR"
moved_symlinks=()

while IFS= read -r relpath; do
    # Skip empty lines
    [ -z "$relpath" ] && continue
    
    # Remove the username prefix if it exists (e.g., "firstpick/")
    cleaned_path=${relpath#*/}
    log "DEBUG" "Processing potential symlink: $cleaned_path"
    
    # Only move if the file exists and is a symlink
    if [ -L "$cleaned_path" ]; then
        mkdir -p "$TEMP_SYMLINK_DIR/$(dirname "$cleaned_path")"
        if mv "$cleaned_path" "$TEMP_SYMLINK_DIR/$cleaned_path"; then
            moved_symlinks+=("$cleaned_path")
            log "INFO" "Temporarily moved absolute symlink: $cleaned_path"
        else
            log "ERROR" "Failed to move symlink: $cleaned_path"
        fi
    else
        log "DEBUG" "Not a symlink or doesn't exist: $cleaned_path"
    fi
done <<< "$abs_symlinks"

# If any symlinks were moved, run stow again
if [ ${#moved_symlinks[@]} -gt 0 ]; then
    log "INFO" "Running stow again after moving ${#moved_symlinks[@]} absolute symlinks..."
    output=$(stow -t "$HOME" . 2>&1)
    log "DEBUG" "Stow output after moving symlinks: $output"
fi

# Check if stow reported conflicts
if ! echo "$output" | grep -q "would cause conflicts\|cannot stow"; then
    if echo "$output" | grep -q "Error"; then
        log "ERROR" "Error running stow. Output: $output"
        cleanup_and_exit 1
    else
        log "INFO" "No conflicted files found."
        cleanup_and_exit 0
    fi
fi

log "INFO" "Conflicts detected. Processing..."
log "DEBUG" "Stow conflict output: $output"

# Extract the conflicted file paths
conflicted_files=$(echo "$output" | grep "cannot stow" | sed -E 's/.*cannot stow ([^ ]+) over existing target ([^ ]+).*/\2/')

# Check if there are any conflicted files
if [ -z "$conflicted_files" ]; then
    log "ERROR" "Failed to extract conflicted files from output."
    cleanup_and_exit 1
fi

log "INFO" "Found conflicted files:"
echo "$conflicted_files" | tee -a "$LOG_FILE"

# Loop through each conflicted file and rename it
while IFS= read -r file; do
    # Skip if empty line
    [ -z "$file" ] && continue

    # Add HOME directory prefix if the file path is relative
    if [[ "$file" != /* ]]; then
        file="$HOME/$file"
    fi
    log "DEBUG" "Processing conflicted file: $file"

    if [ -e "$file" ]; then
        # Generate backup filename with date
        backup_file="${file}.$(date +%Y-%m-%d).bak"
        
        # If a backup with today's date exists, append time
        if [ -e "$backup_file" ]; then
            backup_file="${file}.$(date +%Y-%m-%d_%H%M%S).bak"
            log "DEBUG" "Backup with today's date exists, using time-based backup: $backup_file"
        fi
        
        if mv -n "$file" "$backup_file"; then
            log "INFO" "Renamed '$file' to '$backup_file'"
        else
            log "ERROR" "Failed to rename '$file'"
            cleanup_and_exit 1
        fi
    else
        log "WARNING" "File does not exist: $file"
    fi
done <<< "$conflicted_files"

# Run stow again
log "INFO" "Running stow again after handling conflicts..."
if ! stow -t "$HOME" .; then
    log "ERROR" "Final stow command failed"
    cleanup_and_exit 1
fi
log "INFO" "Final stow command completed successfully"

# All operations completed successfully
log "INFO" "All operations completed successfully"
cleanup_and_exit 0