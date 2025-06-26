#!/bin/bash

# Default values
COMPARISON_BRANCH="develop"
CURRENT_BRANCH=$(git branch --show-current)
files_log="git-diff-affected-files.log"
diff_log="git-diff-details.log"

# Function to display usage information
usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -c BRANCH    Comparison branch (default: develop)"
    echo "  -b BRANCH    Current branch (default: current git branch)"
    echo "  -f FILE      Output file for affected files list (default: affected-files.log)"
    echo "  -d FILE      Output file for diff details (default: branch-diff.log)"
    echo "  -h           Display this help message and exit"
    exit 1
}

# Parse command line options
while getopts ":c:b:f:d:h" opt; do
    case ${opt} in
        c)
            COMPARISON_BRANCH=$OPTARG
            ;;
        b)
            CURRENT_BRANCH=$OPTARG
            ;;
        f)
            files_log=$OPTARG
            ;;
        d)
            diff_log=$OPTARG
            ;;
        h)
            usage
            ;;
        \?)
            echo "Invalid option: $OPTARG" 1>&2
            usage
            ;;
        :)
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            usage
            ;;
    esac
done

# Create or clear the output files
> $files_log
> $diff_log

# Verify that both branches exist
if ! git rev-parse --verify $COMPARISON_BRANCH &> /dev/null; then
    echo "Error: Comparison branch '$COMPARISON_BRANCH' does not exist." >&2
    exit 1
fi

if ! git rev-parse --verify $CURRENT_BRANCH &> /dev/null; then
    echo "Error: Current branch '$CURRENT_BRANCH' does not exist." >&2
    exit 1
fi

# Get repository root directory
REPO_ROOT=$(git rev-parse --show-toplevel)

# Get a list of all modified files with absolute paths
git diff --name-only $COMPARISON_BRANCH...$CURRENT_BRANCH | while read file; do
    if [ -f "$file" ]; then
        echo "$REPO_ROOT/$file" >> $files_log
    fi
done

# Get a list of all modified files
echo "========================================" >> $diff_log
echo "Modified files:" >> $diff_log
git diff --name-status $COMPARISON_BRANCH...$CURRENT_BRANCH >> $diff_log
echo "" >> $diff_log

# Get detailed changes for each modified file
echo "Detailed changes:" >> $diff_log
echo "========================================" >> $diff_log

# Get the actual diff for all files
git diff $COMPARISON_BRANCH...$CURRENT_BRANCH >> $diff_log

echo "" >> $diff_log
echo "Summary of commits:" >> $diff_log
echo "========================================" >> $diff_log
git log --pretty=format:"%h - %s (%an, %ar)" $COMPARISON_BRANCH...$CURRENT_BRANCH >> $diff_log

echo "" >> $diff_log
echo "Changes have been written to $diff_log" >> $diff_log
echo "List of affected files with absolute paths saved to $files_log"
echo "Comparison complete. Results saved to $diff_log and $files_log"
echo "Compared $CURRENT_BRANCH with $COMPARISON_BRANCH"
