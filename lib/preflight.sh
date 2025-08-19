#!/usr/bin/env bash
# Pre-flight validation for commands
# Checks if a command can actually run before building Docker

# Check if a command can run with given arguments
# Returns: 0 if can run, 1 if cannot (with error message printed)
preflight_check() {
    local cmd="${1:-}"
    shift || true

    # First, check if we need a valid project for ANY Docker command
    local project_folder_name=$(get_project_folder_name "$PROJECT_DIR" 2>/dev/null || echo "NONE")

    case "$cmd" in
    # Help always passes - no requirements
    help | -h | --help)
        return 0
        ;;

    # Empty command (running claude) is handled specially by main.sh
    "")
        # Don't check anything - main.sh handles this case
        return 0
        ;;

    # Commands that NEED an existing slot
    slot | shell | update | config | mcp | migrate-installer)
        # Check if we have a valid project first
        if [[ "$project_folder_name" == "NONE" ]]; then
            show_no_slots_menu
            return 1
        fi

        # For slot command, check specific slot
        if [[ "$cmd" == "slot" ]]; then
            local slot_num="${1:-}"
            if [[ -n "$slot_num" ]]; then
                local slot_dir=$(get_slot_dir "$PROJECT_DIR" "$slot_num" 2>/dev/null || echo "")
                if [[ -z "$slot_dir" ]] || [[ ! -d "$slot_dir" ]]; then
                    error "Slot $slot_num does not exist. Run 'claudebox slots' to see available slots."
                    return 1
                fi
            fi
        else
            # For other commands, just need ANY authenticated slot
            local has_slot=false
            local parent_dir=$(get_parent_dir "$PROJECT_DIR" 2>/dev/null || echo "")
            if [[ -n "$parent_dir" ]] && [[ -d "$parent_dir" ]]; then
                for slot_dir in "$parent_dir"/*/; do
                    if [[ -d "$slot_dir" ]] && [[ -f "$slot_dir/.claude/.credentials.json" ]]; then
                        has_slot=true
                        break
                    fi
                done
            fi

            if [[ "$has_slot" == "false" ]]; then
                show_no_slots_menu
                return 1
            fi
        fi
        ;;

    # Commands that need a valid project directory
    rebuild | info | profile | add | remove | install | allowlist | save)
        if [[ "$project_folder_name" == "NONE" ]]; then
            error "No project found in current directory.
Please cd to a project directory first."
            return 1
        fi
        ;;

    # Project command needs special handling
    project)
        local search="${1:-}"
        if [[ -n "$search" ]]; then
            # Check if project exists
            local search_lower=$(echo "$search" | tr '[:upper:]' '[:lower:]')
            local found=false

            for parent_dir in "$HOME/.claudebox/projects"/*/; do
                [[ -d "$parent_dir" ]] || continue
                local dir_name=$(basename "$parent_dir")
                local dir_lower=$(echo "$dir_name" | tr '[:upper:]' '[:lower:]')

                if [[ "$dir_lower" == *"$search_lower"* ]]; then
                    found=true
                    break
                fi
            done

            if [[ "$found" == "false" ]]; then
                error "No projects found matching '$search'"
                return 1
            fi
        fi
        ;;

    # Tmux - skip pre-flight entirely, it handles its own validation
    tmux)
        return 0
        ;;

    # Default: Unknown commands are forwarded to Claude, so need a slot
    *)
        if [[ "$project_folder_name" == "NONE" ]]; then
            show_no_slots_menu
            return 1
        fi

        # Check for ANY authenticated slot
        local has_slot=false
        local parent_dir=$(get_parent_dir "$PROJECT_DIR" 2>/dev/null || echo "")
        if [[ -n "$parent_dir" ]] && [[ -d "$parent_dir" ]]; then
            for slot_dir in "$parent_dir"/*/; do
                if [[ -d "$slot_dir" ]] && [[ -f "$slot_dir/.claude/.credentials.json" ]]; then
                    has_slot=true
                    break
                fi
            done
        fi

        if [[ "$has_slot" == "false" ]]; then
            show_no_slots_menu
            return 1
        fi
        ;;
    esac

    return 0
}

export -f preflight_check
