#!/usr/bin/env bash
#
# functions.sh – internal library for create_tree
#
# This file contains all the logic needed to parse the diagram, honour
# .gitignore rules, decide whether an item should be created, and actually
# create the file or directory.
#
# The following environment variables are expected to be defined by the
# caller (create_tree):
#
#   ROOT_DIR        – absolute path where the tree will be materialised
#   LEVEL_LIMIT     – integer depth limit (0 = no limit)
#   USE_GITIGNORE   – 1 if .gitignore rules should be honoured, 0 otherwise
#   GITIGNORE_PATH  – absolute path to the .gitignore file (if it exists)
#
# All functions are written in POSIX‑sh; no Bash‑only extensions are used.

# Global variable to maintain the path context
# It will be an array where each index corresponds to a depth level
declare -a PATH_STACK

# Define all known tree diagram glyphs
# Note: The first item is a non-breaking space (U+00A0), which often looks like a regular space
# but is not treated the same way by shell scripts.
declare -a TREE_GLYPHS=(' ' ' ' '│' '┃' '├' '┣' '└' '┗' '─' '──')

# --------------------------------------------------------------------------- #
# Utility helpers
# --------------------------------------------------------------------------- #

# trim_trailing_newlines - remove trailing CR/LF from a string
trim_trailing_newlines() {
    # $1 – string
    printf '%s' "$1" | tr -d '\r\n'
}

# --------------------------------------------------------------------------- #
# 1. Parsing the diagram
# --------------------------------------------------------------------------- #

# parse_line
#   Given a raw diagram line, determine the depth (number of tree
#   characters) and the relative path.
#   Returns the depth in the global variable LINE_DEPTH
#   and the relative path in the global variable REL_PATH.
#   The function assumes the line is non‑empty.
parse_line() {
    local raw_line="$1"
    local rest="${raw_line}"

    # --- 1. Strip leading whitespace from the entire line ----------------
    rest="${rest#"${rest%%[![:space:]]*}"}"

    # --- 2. Count glyphs and strip them --------------------------------
    LINE_DEPTH=0
    local matched=
    while true; do
        matched=""
        for g in "${TREE_GLYPHS[@]}"; do
            if [ "${rest#"${g}"}" != "$rest" ]; then
                matched="$g"
                break
            fi
        done

        if [ -z "$matched" ]; then
            break
        fi

        LINE_DEPTH=$((LINE_DEPTH + 1))
        rest="${rest#"$matched"}"

        # After removing a glyph there might be a space; skip it
        rest="${rest#"${rest%%[![:space:]]*}"}"
    done

    # --- 3. The remaining string is the item's name
    local item_name="${rest}"

    # --- 4. Build the full relative path using the path stack
    # Trim the stack to the current depth
    PATH_STACK=("${PATH_STACK[@]:0:$LINE_DEPTH}")

    # Add the current item to the stack
    PATH_STACK[$LINE_DEPTH]="$item_name"

    # Join the stack elements to create the full relative path
    local path_components
    path_components=$(IFS=/; echo "${PATH_STACK[*]:1}") # skip the root

    REL_PATH="$path_components"

    export LINE_DEPTH
    export REL_PATH
}

# --------------------------------------------------------------------------- #
# 2. Decision logic
# --------------------------------------------------------------------------- #

# should_create
#   Decide whether an item should be created:
#   * it must not already exist under ROOT_DIR
#   * its depth must be within LEVEL_LIMIT (if non‑zero)
#   Sets EXIT_STATUS: 0 – create, 1 – skip
should_create() {
    # Skip if depth is beyond the requested level
    if [ "$LEVEL_LIMIT" -gt 0 ] && [ "$LINE_DEPTH" -gt "$LEVEL_LIMIT" ]; then
        return 1
    fi

    # Resolve absolute path
    local abs_path="$ROOT_DIR/$REL_PATH"

    # Skip if the path already exists
    if [ -e "$abs_path" ]; then
        return 1
    fi

    return 0
}

# is_gitignored
#   Return 0 if REL_PATH matches a rule in the .gitignore file.
#   Implements a very small subset of the syntax:
#     * matches glob patterns (case statement)
#     * directory patterns (trailing '/')
#     * literal paths
#   If GITIGNORE_PATH is empty or not readable, it returns 1 (not ignored).
is_gitignored() {
    # Bail out if .gitignore handling is disabled
    if [ "$USE_GITIGNORE" -ne 1 ] || [ -z "$GITIGNORE_PATH" ]; then
        return 1
    fi

    # Return 1 if the .gitignore file is not readable
    if [ ! -r "$GITIGNORE_PATH" ]; then
        return 1
    fi

    # Iterate over each rule in the .gitignore file
    while IFS= read -r rule || [ -n "$rule" ]; do
        # Trim leading/trailing whitespace
        rule=$(printf '%s' "$rule" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip empty lines or comments (lines starting with '#')
        if [ -z "$rule" ] || [ "${rule#\#}" != "$rule" ]; then
            continue
        fi

        # Convert directory patterns (ending with '/') to glob patterns
        pattern="$rule"
        case "$pattern" in
            */) pattern="${rule%/}/*" ;;
        esac

        # Perform a glob match against REL_PATH
        case "$REL_PATH" in
            $pattern) return 0 ;;
        esac
    done < "$GITIGNORE_PATH"

    # No rule matched – not ignored
    return 1
}

# --------------------------------------------------------------------------- #
# 3. Creating the item
# --------------------------------------------------------------------------- #

# create_item
#   Creates the file or directory represented by REL_PATH.
#   A simple heuristic is used to decide the type:
#     * if REL_PATH contains a dot ('.') → file
#     * otherwise → directory
#   The function always calls `mkdir -p` for directories so that
#   any intermediate parents are created as well.
create_item() {
    local abs_path="$ROOT_DIR/$REL_PATH"

    case "$REL_PATH" in
        *.*)  # contains a dot → treat as file
            # Create an empty file
            if ! touch "$abs_path" 2>/dev/null; then
                printf 'ERROR: Failed to touch file "%s"\n' "$abs_path" >&2
                exit 1
            fi
            printf 'Created file:   %s\n' "$REL_PATH"
            ;;
        *)    # otherwise → treat as directory
            if ! mkdir -p "$abs_path" 2>/dev/null; then
                printf 'ERROR: Failed to mkdir "%s"\n' "$abs_path" >&2
                exit 1
            fi
            printf 'Created dir :   %s\n' "$REL_PATH"
            ;;
    esac
}

# --------------------------------------------------------------------------- #
# 4. Public wrapper – what the main script calls
# --------------------------------------------------------------------------- #

# process_line
#   Called by the main script for every diagram line.
#   Performs the full cycle:
#   1. parse_line → depth & path
#   2. should_create
#   3. honour .gitignore (if enabled)
#   4. create_item
#
#   Parameters:
#     $1 – the raw diagram line
process_line() {
    local raw_line="$1"

    # 1. Parse the line
    parse_line "$raw_line"

    # 2. Decide if we should even attempt to create it
    should_create || return 0   # nothing to do – skip

    # 3. If .gitignore is requested, check whether the item is ignored
    if is_gitignored; then
        printf 'Ignored by .gitignore: %s\n' "$REL_PATH"
        return 0
    fi

    # 4. Create the item
    create_item
}