#!/bin/bash

# Navigate to the directory where this script is located
cd "$(dirname "$0")"

echo "=== Taskwatch App Upload Script ==="

# Initialize git if not already done
if [ ! -d ".git" ]; then
    echo "Initializing Git repository..."
    git init
else
    echo "Git repository already initialized."
fi

# Set the remote URL
echo "Configuring remote repository..."
git remote remove origin 2>/dev/null
git remote add origin https://github.com/primacyinfotechpvtltd/taskwatch_app.git

# Stage all files
echo "Staging files..."
git add .

# Check if there are changes to commit
if git diff-index --quiet HEAD -- 2>/dev/null; then
    echo "No new changes to commit."
else
    echo "Creating commit..."
    git commit -m "Initial commit of taskwatch app"
fi

# Ensure branch is main
git branch -M main

# Push to GitHub
echo "Pushing to GitHub (https://github.com/primacyinfotechpvtltd/taskwatch_app.git)..."
echo "Note: If you haven't authenticated, Git will prompt you for your GitHub username and Personal Access Token (PAT) / Password."
git push -u origin main

echo "=== Upload attempt completed! ==="
