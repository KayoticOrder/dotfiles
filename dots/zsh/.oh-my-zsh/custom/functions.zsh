function nv() {
    if [[ $# -eq 0 ]]; then
        echo "Usage: nv <path> [file pattern]"
        return 1
    fi

    # Concatenate all arguments to try as a full path first
    local full_query="$*"
    local dir="$(zoxide query "$full_query" && echo)"

    # If no directory found, reduce the query by peeling off potential file patterns from the end
    local num_args=$#
    while [[ -z "$dir" && $num_args -gt 0 ]]; do
        num_args=$((num_args - 1))
        local query_terms=($@)
        local potential_dir="${query_terms[@]:0:$num_args}"
        dir="$(zoxide query "$potential_dir" && echo)"

        # If a directory is found, the remaining terms are considered as a file pattern
        if [[ -n "$dir" ]]; then
            local file_pattern="${query_terms[@]:$num_args}"
            break
        fi
    done

    # Handle cases where no directory is found at all
    if [[ -z "$dir" ]]; then
        echo "No directory found matching any part of '$full_query'"
        return 1
    fi

    # Change to the directory
    cd "$dir" || return

    # Define the preview command (using bat if available, otherwise cat)
    local preview_cmd="bat --style=numbers --color=always {} || cat {}"

    # Use fzf to select a file with a preview and automatic selection of the top result
    local file
    if [[ -n "$file_pattern" ]]; then
        file="$(find . -type f | fzf -1 -0 --query="$file_pattern" --height 40% --reverse --preview "$preview_cmd")"
    else
        file="$(find . -type f | fzf -1 -0 --height 40% --reverse --preview "$preview_cmd")"
    fi

    if [[ -n "$file" ]]; then
        nvim "$file"
    else
        echo "No file selected."
    fi
}
