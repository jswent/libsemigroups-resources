#!/bin/bash
# This script is meant to be run inside the container to sync from host

set -e

REPO_PATH="/workspace/libsemigroups"
HOST_REPO="/host-repo"

if [ ! -d "$HOST_REPO/.git" ]; then
    echo "Error: Host repository not mounted at $HOST_REPO"
    exit 1
fi

if [ ! -d "$REPO_PATH/.git" ]; then
    echo "Error: Dev repository not found at $REPO_PATH"
    echo "Run the init command from the host to clone the repository first"
    exit 1
fi

cd "$REPO_PATH"

echo "Fetching all changes from host repository..."
git fetch "$HOST_REPO" '+refs/heads/*:refs/remotes/host/*'

CURRENT_BRANCH=$(git branch --show-current)
echo "Current branch: $CURRENT_BRANCH"

# Check if there are uncommitted changes
if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "Warning: You have uncommitted changes:"
    git status --short
    echo ""
    read -p "Stash changes and pull? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stash
        echo "Changes stashed"
    else
        echo "Sync cancelled"
        exit 1
    fi
fi

# Check if the branch exists on host
if git show-ref --verify --quiet "refs/remotes/host/$CURRENT_BRANCH"; then
    echo "Pulling changes from host/$CURRENT_BRANCH..."
    git pull "$HOST_REPO" "$CURRENT_BRANCH"
    echo "Sync completed successfully!"
    echo "Latest commit:"
    git log -1 --oneline
else
    echo "Warning: Branch '$CURRENT_BRANCH' not found on host"
    echo "Available branches on host:"
    git branch -r | grep 'host/' | sed 's/.*host\//  /'
    echo ""
    read -p "Enter branch name to pull from host (or press Enter to cancel): " BRANCH_NAME
    if [ -n "$BRANCH_NAME" ]; then
        git pull "$HOST_REPO" "$BRANCH_NAME"
        echo "Sync completed successfully!"
    else
        echo "Sync cancelled"
    fi
fi
