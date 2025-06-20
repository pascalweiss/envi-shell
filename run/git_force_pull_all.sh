#!/usr/bin/env bash

echo "=== FORCE PULL ALL PROJECTS ==="
echo "WARNING: This will FORCE PULL and overwrite any local changes!"
echo "Your local repositories will match the remote state exactly."
echo ""

# Ask for confirmation
read -p "Are you sure you want to continue? (y/N): " confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

echo ""
echo "=== FORCE PULLING SUBMODULES ==="
if [ -d "submodules" ]; then
    for submodule in submodules/*/; do
        if [ -d "$submodule" ] && [ -d "$submodule/.git" ]; then
            submodule_name=$(basename "$submodule")
            echo "--- Processing submodule: $submodule_name ---"
            
            # Change to submodule directory
            cd "$submodule"
            
            # Get the default branch name
            default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's@^refs/remotes/origin/@@' || echo 'main')
            
            echo "Fetching latest changes..."
            git fetch origin
            
            echo "Checking out $default_branch branch..."
            git checkout "$default_branch" 2>/dev/null || git checkout -b "$default_branch" "origin/$default_branch"
            
            echo "Force pulling from origin/$default_branch..."
            git reset --hard "origin/$default_branch"
            
            echo "✓ Successfully force pulled $submodule_name"
            
            # Return to main project directory
            cd - > /dev/null
            echo ""
        fi
    done
else
    echo "No submodules folder found"
fi

echo "=== FORCE PULLING MAIN PROJECT ==="
echo "--- Processing main project ---"

# Get the current branch
current_branch=$(git branch --show-current)
echo "Current branch: $current_branch"

echo "Fetching latest changes..."
git fetch origin

echo "Force pulling from origin/$current_branch..."
git reset --hard "origin/$current_branch"

echo "Updating submodule references..."
git submodule update --init --recursive --force

echo "✓ Successfully force pulled main project"

echo ""
echo "=== SUMMARY ==="
echo "✓ Force pull completed successfully!"
echo "All repositories now match their remote state exactly."
echo "Any local changes have been discarded."
