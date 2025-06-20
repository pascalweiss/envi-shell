#!/usr/bin/env bash

echo "=== COMMIT ALL PROJECTS ==="
echo "This script will commit changes in all submodules and the main project."
echo ""

# Prompt for commit message
read -p "Enter commit message: " commit_message

# Check if commit message is empty
if [ -z "$commit_message" ]; then
    echo "Error: Commit message cannot be empty."
    exit 1
fi

echo ""
echo "Using commit message: '$commit_message'"
echo ""

# Track if any commits were made
commits_made=false

echo "=== COMMITTING SUBMODULES ==="
if [ -d "submodules" ]; then
    for submodule in submodules/*/; do
        if [ -d "$submodule" ] && [ -d "$submodule/.git" ]; then
            submodule_name=$(basename "$submodule")
            echo "--- Processing submodule: $submodule_name ---"
            
            # Change to submodule directory
            cd "$submodule"
            
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
            cd - > /dev/null
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
