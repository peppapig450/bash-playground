#!/usr/bin/env bash
# ==============================================================================
# key_value_parser.sh — Minimal key-value parser using mapfile -C callback and associative arrays
#
# Description:
#   Parses lines of the form key=value from standard input into an associative array,
#   using Bash's `mapfile` builtin with the -C (callback) option to populate the map
#   on the fly.
#
#   This demonstrates a lesser-known feature of Bash: the ability to execute a callback
#   function during `mapfile` line ingestion. The callback is called with two positional
#   arguments:
#     - $1: the current array index (as would be assigned by mapfile)
#     - $2: the actual line read from input
#
#   In this case, we use the callback to:
#     - Split the input line into key and value (based on `=` delimiter)
#       - NOTE: this can probably be changed to use any delimiter in reality
#     - Store the key in an indexed array for order preservation
#     - Store the value in an associative array using the key
#
#   Example usage:
#     $ ./key_value_parser.sh mykey < input.txt
#     $ ./key_value_parser.sh --all < input.txt
#
#   Example input.txt:
#     user=alice
#     role=admin
#     id=42
#
#   Output with key lookup:
#     kv[0] = user = alice
#
#   Output with --all:
#     kv[0] = user = alice
#     kv[1] = role = admin
#     kv[2] = id = 42
#
# Requirements:
#   - Bash 4+ (for associative arrays and mapfile -C support)
# ==============================================================================

# Declare associative array to hold parsed key-value pairs
declare -A kv_map

# Indexed array to preserve insertion order of keys
kv_keys=()

usage() {
    cat <<'_CALL_ME_MAYBE_'
Usage: key_value_parser.sh <key>
       key_value_parser.sh --all

Parses key=value lines from stdin into an associative array using Bash's
mapfile -C callback mechanism, then either prints a specific key or all keys.

Examples:
    $ ./key_value_parser.sh user < input.txt
    kv[0] = user = alice

    $ ./key_value_parser.sh --all < input.txt
    kv[0] = user = alice
    kv[1] = role = admin
    kv[2] = id = 42

Expected input format (stdin):
    key1=value1
    key2=value2
    ...

Requirements:
    - Bash 4+
    - A faint will to live

Notes:
    - Keys must not contain '='
    - Values can contain '=' if you hate parsers
_CALL_ME_MAYBE_
    exit 2
}

# ------------------------------------------------------------------------------
# show_record
# Prints the key=value pair at the given key index (used for demo purposes)
# ------------------------------------------------------------------------------
show_record() {
    local key_index="$1"
    local key="${kv_keys[$key_index]}"
    printf 'kv[%d] = %s\n' "$key_index" "$key = ${kv_map[$key]}"
}

# ------------------------------------------------------------------------------
# print_all_kv
# Prints all key-value pairs in order of appearance
# ------------------------------------------------------------------------------
print_all_kv() {
    for i in "${!kv_keys[@]}"; do
        show_record "$i"
    done
}

# ------------------------------------------------------------------------------
# parse_line_into_map
# Callback used by mapfile to build the associative array on-the-fly
#
# Arguments:
#   $1 - Index of the line in the array (automatically passed by mapfile)
#   $2 - Content of the line read from input
#
# This function is called *before* each line is assigned to the array. We hijack
# it to avoid ever creating the array, and instead populate kv_keys and kv_map.
# ------------------------------------------------------------------------------
parse_line_into_map() {
    local idx="$1"
    local line="$2"
    # only accept lines that look like key=value (key must start with a letter)
    [[ ! "$line" =~ ^[[:space:]]*[[:alpha:]][^=]*=.*$ ]] && return

    IFS='=' read -r key val <<< "$line"
    kv_keys[idx]="$key"
    kv_map["$key"]="$val"
}

# ------------------------------------------------------------------------------
# parse_records
# Uses mapfile with a callback to populate key-value data
# - -t removes trailing newlines
# - -c1 triggers the callback for every single line
# - -C specifies the callback function to call
# ------------------------------------------------------------------------------
parse_records() {
    mapfile -tc1 -C parse_line_into_map
}

# ------------------------------------------------------------------------------
# main
# Parses stdin into map, then attempts to print the key the user is looking up
# ------------------------------------------------------------------------------
main() {
    parse_records

    if [[ -z "$1" || "$1" == "--all" ]]; then
        print_all_kv
        return 0
    fi

    local lookup_key="$1"
    for i in "${!kv_keys[@]}"; do
        if [[ "${kv_keys[$i]}" == "$lookup_key" ]]; then
            show_record "$i"
            return 0
        fi
    done

    echo "Key not found: $lookup_key" >&2
    return 1
}


# ------------------------------------------------------------------------------
# Entry point guard
# This makes the script both source-able and executable
# ------------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
    if (( $# != 1 )); then
        usage
    fi
    main "$1"
fi
