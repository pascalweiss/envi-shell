#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

echo -e "${BLUE}=== STAGE ALL CHANGES IN ALL PROJECTS ===${NC}"
echo "This script will stage all changes (git add .) in all submodules and the main project."
echo ""

# Get the root directory of the main repository
MAIN_REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)

if [ $? -ne 0 ]; then
    print_error "Not in a git repository!"
    exit 1
fi

cd "$MAIN_REPO_ROOT"

# Track results
submodules_processed=0
submodules_with_changes=0
main_repo_changes=false

echo -e "${BLUE}=== STAGING CHANGES IN SUBMODULES ===${NC}"

# Process each submodule
if [ -f .gitmodules ]; then
    # Get list of submodule paths
    submodule_paths=$(git config --file .gitmodules --get-regexp path | awk '{ print $2 }')
    
    for submodule_path in $submodule_paths; do
        if [ -d "$submodule_path" ]; then
            print_status "--- Processing submodule: $submodule_path ---"
            submodules_processed=$((submodules_processed + 1))
            
            cd "$MAIN_REPO_ROOT/$submodule_path"
            
            # Check if there are any changes to stage
            if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
                print_warning "No changes to stage in $submodule_path"
            else
                # Stage all changes
                git add .
                if [ $? -eq 0 ]; then
                    print_success "Staged all changes in $submodule_path"
                    submodules_with_changes=$((submodules_with_changes + 1))
                    
                    # Show what was staged
                    staged_files=$(git diff --cached --name-only | wc -l | tr -d ' ')
                    if [ "$staged_files" -gt 0 ]; then
                        echo "  Staged $staged_files file(s):"
                        git diff --cached --name-only | sed 's/^/    /'
                    fi
                else
                    print_error "Failed to stage changes in $submodule_path"
                fi
            fi
            
            cd "$MAIN_REPO_ROOT"
        else
            print_warning "Submodule directory not found: $submodule_path"
        fi
    done
else
    print_warning "No .gitmodules file found - no submodules to process"
fi

echo ""
echo -e "${BLUE}=== STAGING CHANGES IN MAIN PROJECT ===${NC}"

# Process main repository
print_status "--- Processing main project ---"

# Check if there are any changes to stage in main repo
if git diff --quiet && git diff --cached --quiet && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    print_warning "No changes to stage in main project"
else
    # Stage all changes in main repo
    git add .
    if [ $? -eq 0 ]; then
        print_success "Staged all changes in main project"
        main_repo_changes=true
        
        # Show what was staged
        staged_files=$(git diff --cached --name-only | wc -l | tr -d ' ')
        if [ "$staged_files" -gt 0 ]; then
            echo "  Staged $staged_files file(s):"
            git diff --cached --name-only | sed 's/^/    /'
        fi
    else
        print_error "Failed to stage changes in main project"
    fi
fi

echo ""
echo -e "${BLUE}=== SUMMARY ===${NC}"

if [ $submodules_processed -eq 0 ] && [ "$main_repo_changes" = false ]; then
    print_warning "No repositories processed"
elif [ $submodules_with_changes -eq 0 ] && [ "$main_repo_changes" = false ]; then
    print_warning "No changes found to stage in any repository"
else
    print_success "Staging completed successfully!"
    echo "  - Submodules processed: $submodules_processed"
    echo "  - Submodules with staged changes: $submodules_with_changes"
    if [ "$main_repo_changes" = true ]; then
        echo "  - Main project: staged changes"
    else
        echo "  - Main project: no changes"
    fi
    echo ""
    echo "Next steps:"
    echo "  1. Review staged changes: run/git_diff_all.sh"
    echo "  2. Commit changes: run/git_commit_all.sh \"your commit message\""
    echo "  3. Push changes: run/git_push_all.sh"
fi
