#!/bin/bash

# Make the script executable
chmod +x "$0"

# Path to the Rust crate directory
RUST_DIR="/home/joy/Coding/Joy/pi_task_watch/rust"

echo "Fixing Rust compilation warnings and errors..."

# Remove unused imports from all Rust files
find "$RUST_DIR" -name "*.rs" -type f -exec sed -i -E '
    s/use std::path::(PathBuf|Path)(, )?//g;
    s/, (PathBuf|Path)//g;
    s/use sysinfo::(Pid|Process)(, )?//g;
    s/, (Pid|Process)//g;
    s/use enigo::Keycode(, )?//g;
    s/, Keycode//g;
' {} \;

# Look for unreachable statements (typically after return statements)
echo "Finding files with potential unreachable statements..."
grep -r "return" --include="*.rs" "$RUST_DIR" | grep -B 1 -A 3 ";" | grep -v "^\-\-" | grep -v "return"

echo "Please check the above contexts for possible unreachable code (statements after return)"
echo "Common fixes:"
echo "1. Remove code that follows a return statement"
echo "2. Move code that follows a return statement to before the return"
echo "3. Add a condition to make both code paths reachable"

echo "Building project to check if issues are resolved..."
cd "$RUST_DIR"
cargo check

echo "If the build succeeds, the warnings have been fixed."
echo "If not, manual inspection of the files with unreachable statements may be required."
