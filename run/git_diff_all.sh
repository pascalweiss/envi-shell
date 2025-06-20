#!/usr/bin/env bash

echo "=== PROJECT CHANGES OVERVIEW ==="
echo "Date: $(date)"
echo "Project Directory: $(pwd)"
echo ""

echo "=== MAIN PROJECT STATUS ==="
echo "Git status:"
git --no-pager status --porcelain
echo ""

echo "Git diff (staged changes):"
git --no-pager diff --cached
echo ""

echo "Git diff (unstaged changes):"
git --no-pager diff
echo ""

echo "=== SUBMODULES CHANGES ==="
if [ -d "submodules" ]; then
    for submodule in submodules/*/; do
        if [ -d "$submodule" ] && [ -d "$submodule/.git" ]; then
            submodule_name=$(basename "$submodule")
            echo "=== SUBMODULE: $submodule_name ==="
            
            # Change to submodule directory
            cd "$submodule"
            
            echo "Git status:"
            git --no-pager status --porcelain
            echo ""
            
            echo "Git diff (staged changes):"
            git --no-pager diff --cached
            echo ""
            
            echo "Git diff (unstaged changes):"
            git --no-pager diff
            echo ""
            
            # Return to main project directory
            cd - > /dev/null
            echo "----------------------------------------"
        fi
    done
else
    echo "No submodules folder found"
fi

echo ""
echo "=== SUMMARY ==="
main_modified=$(git --no-pager status --porcelain | wc -l)
echo "Files with changes in main project: $main_modified"

if [ -d "submodules" ]; then
    total_submodule_changes=0
    submodule_count=0
    
    for submodule in submodules/*/; do
        if [ -d "$submodule" ] && [ -d "$submodule/.git" ]; then
            cd "$submodule"
            submodule_modified=$(git --no-pager status --porcelain | wc -l)
            total_submodule_changes=$((total_submodule_changes + submodule_modified))
            submodule_count=$((submodule_count + 1))
            cd - > /dev/null
        fi
    done
    
    echo "Submodules checked: $submodule_count"
    echo "Total files with changes in submodules: $total_submodule_changes"
    echo "Grand total files with changes: $((main_modified + total_submodule_changes))"
else
    echo "Submodules checked: 0"
    echo "Grand total files with changes: $main_modified"
fi
