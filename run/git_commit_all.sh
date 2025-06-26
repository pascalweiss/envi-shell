#!/usr/bin/env bash

# Help function
show_help() {
    cat << EOF
=== GIT COMMIT ALL SCRIPT ===

DESCRIPTION:
    This script commits changes in all submodules first, then in the main project.
    It ensures submodule references are properly updated in the main project.

USAGE:
    $0 [OPTIONS]
    $0 "Your commit message"

OPTIONS:
    -h, --help    Show this help message
    
COMMIT MESSAGE:
    - Must be provided in quotes (single or double quotes)
    - Cannot be empty
    - Same message will be used for all repositories with changes

EXAMPLES:
    $0 "Add new feature to all modules"
    $0 'Fix bug in configuration files'
    $0 "Update documentation and scripts"

BEHAVIOR:
    1. Processes each submodule in submodules/ folder
    2. Checks out main branch if submodule is in detached HEAD
    3. Commits changes in submodules first
    4. Commits main project last (includes updated submodule references)
    5. Provides summary of what was committed

EOF
}

# Check for help flag
if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    show_help
    exit 0
fi

echo "=== COMMIT ALL PROJECTS ==="
echo "This script will commit changes in all submodules and the main project."
echo ""

# Check if commit message was provided as argument
if [ $# -eq 1 ]; then
    commit_message="$1"
    echo "Using provided commit message: '$commit_message'"
else
    # Prompt for commit message with quotes requirement
    echo "Please provide a commit message in quotes."
    echo "Example: \"Your commit message here\""
    echo ""
    read -p "Enter commit message (in quotes): " commit_message
    
    # Remove surrounding quotes if present and validate
    commit_message=$(echo "$commit_message" | sed 's/^['\''\"]\(.*\)['\''\"]/\1/')
fi

# Check if commit message is empty
if [ -z "$commit_message" ]; then
    echo "Error: Commit message cannot be empty."
    echo "Use: $0 --help for usage information"
    exit 1
fi

echo ""
echo "Using commit message: '$commit_message'"
echo ""

# Track if any commits were made
commits_made=false

# Store the main repository root directory
MAIN_REPO_ROOT=$(pwd)

echo "=== COMMITTING SUBMODULES ==="
if [ -d "submodules" ]; then
    for submodule in submodules/*/; do
        if [ -d "$submodule" ] && [ -e "$submodule/.git" ]; then
            submodule_name=$(basename "$submodule")
            echo "--- Processing submodule: $submodule_name ---"
            
            # Change to submodule directory
            cd "$MAIN_REPO_ROOT/$submodule"
            
            # Check if we're in detached HEAD and checkout main branch
            current_branch=$(git branch --show-current)
            if [ -z "$current_branch" ]; then
                echo "Submodule is in detached HEAD, checking out main branch..."
                git checkout main 2>/dev/null || git checkout -b main
            fi
            
            # Check if there are any changes
            if [ -n "$(git --no-pager status --porcelain)" ]; then
                echo "Changes found in $submodule_name:"
                git --no-pager status --porcelain
                
                # Add all changes
                git add .
                
                # Commit changes
                if git commit -m "$commit_message"; then
                    echo "✓ Successfully committed changes in $submodule_name"
                    commits_made=true
                else
                    echo "✗ Failed to commit changes in $submodule_name"
                fi
            else
                echo "No changes found in $submodule_name"
            fi
            
            # Return to main project directory
            cd "$MAIN_REPO_ROOT"
            echo ""
        fi
    done
else
    echo "No submodules folder found"
fi

echo "=== COMMITTING MAIN PROJECT ==="
echo "--- Processing main project ---"

# Check if there are any changes in main project
if [ -n "$(git --no-pager status --porcelain)" ]; then
    echo "Changes found in main project:"
    git --no-pager status --porcelain
    
    # Add all changes (including updated submodule references)
    git add .
    
    # Commit changes
    if git commit -m "$commit_message"; then
        echo "✓ Successfully committed changes in main project"
        commits_made=true
    else
        echo "✗ Failed to commit changes in main project"
    fi
else
    echo "No changes found in main project"
fi

echo ""
echo "=== SUMMARY ==="
if [ "$commits_made" = true ]; then
    echo "✓ Commit process completed successfully!"
    echo "All repositories with changes have been committed with message: '$commit_message'"
else
    echo "ℹ No commits were made (no changes found in any repository)"
fi
