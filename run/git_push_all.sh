#!/usr/bin/env bash

#!/usr/bin/env bash

# Help function
show_help() {
    echo "=== GIT PUSH ALL SCRIPT ==="
    echo ""
    echo "DESCRIPTION:"
    echo "    This script pushes committed changes from all submodules and the main project"
    echo "    to their respective remote repositories."
    echo ""
    echo "USAGE:"
    echo "    $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "    -h, --help    Show this help message"
    echo "    -f, --force   Force push (use with caution!)"
    echo ""
    echo "BEHAVIOR:"
    echo "    1. Pushes each submodule in submodules/ folder to origin/main"
    echo "    2. Pushes main project to origin/main"
    echo "    3. Uses regular push by default, force push only with -f flag"
    echo "    4. Provides summary of what was pushed"
    echo ""
    echo "EXAMPLES:"
    echo "    $0                    # Regular push"
    echo "    $0 --force           # Force push (dangerous!)"
    echo "    $0 -h                # Show help"
    echo ""
    echo "WARNING:"
    echo "    Force push (--force) can overwrite remote history and cause data loss!"
    echo "    Only use force push if you understand the consequences."
    echo ""
}

# Initialize variables
force_push=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -f|--force)
            force_push=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use: $0 --help for usage information"
            exit 1
            ;;
    esac
done

echo "=== PUSH ALL PROJECTS ==="
if [ "$force_push" = true ]; then
    echo "WARNING: Force push mode enabled!"
    echo "This will overwrite remote history!"
    echo ""
    read -p "Are you sure you want to force push? (y/N): " confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Force push cancelled."
        exit 0
    fi
    push_flags="--force"
    echo "Using force push..."
else
    push_flags=""
    echo "Using regular push..."
fi
echo ""

# Track if any pushes were made
pushes_made=false
failed_pushes=false

# Store the main repository root directory
MAIN_REPO_ROOT=$(pwd)

echo "=== PUSHING SUBMODULES ==="
if [ -d "submodules" ]; then
    for submodule in submodules/*/; do
        if [ -d "$submodule" ] && [ -e "$submodule/.git" ]; then
            submodule_name=$(basename "$submodule")
            echo "--- Processing submodule: $submodule_name ---"
            
            # Change to submodule directory
            cd "$MAIN_REPO_ROOT/$submodule"
            
            # Check if we're on a proper branch
            current_branch=$(git branch --show-current)
            if [ -z "$current_branch" ]; then
                echo "⚠ Submodule is in detached HEAD, skipping push"
                cd "$MAIN_REPO_ROOT"
                echo ""
                continue
            fi
            
            # Check if there are commits to push
            if git log origin/"$current_branch".."$current_branch" --oneline | grep -q .; then
                echo "Commits found to push in $submodule_name"
                echo "Pushing to origin/$current_branch..."
                
                if git push $push_flags origin "$current_branch"; then
                    echo "✓ Successfully pushed $submodule_name"
                    pushes_made=true
                else
                    echo "✗ Failed to push $submodule_name"
                    failed_pushes=true
                fi
            else
                echo "No commits to push in $submodule_name"
            fi
            
            # Return to main project directory
            cd "$MAIN_REPO_ROOT"
            echo ""
        fi
    done
else
    echo "No submodules folder found"
fi

echo "=== PUSHING MAIN PROJECT ==="
echo "--- Processing main project ---"

# Get current branch
current_branch=$(git branch --show-current)
if [ -z "$current_branch" ]; then
    echo "⚠ Main project is in detached HEAD, cannot push"
else
    # Check if there are commits to push
    if git log origin/"$current_branch".."$current_branch" --oneline | grep -q .; then
        echo "Commits found to push in main project"
        echo "Pushing to origin/$current_branch..."
        
        if git push $push_flags origin "$current_branch"; then
            echo "✓ Successfully pushed main project"
            pushes_made=true
        else
            echo "✗ Failed to push main project"
            failed_pushes=true
        fi
    else
        echo "No commits to push in main project"
    fi
fi

echo ""
echo "=== SUMMARY ==="
if [ "$pushes_made" = true ] && [ "$failed_pushes" = false ]; then
    echo "✓ Push process completed successfully!"
    echo "All repositories with commits have been pushed to their remotes."
elif [ "$pushes_made" = true ] && [ "$failed_pushes" = true ]; then
    echo "⚠ Push process completed with some failures!"
    echo "Some repositories were pushed successfully, others failed."
    echo "Check the output above for details."
elif [ "$failed_pushes" = true ]; then
    echo "✗ Push process failed!"
    echo "No repositories were pushed successfully."
else
    echo "ℹ No pushes were made (no commits found to push in any repository)"
fi
