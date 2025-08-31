#!/usr/bin/env bash
# Core Commands - Essential ClaudeBox operations
# ============================================================================
# Commands: help, shell, update
# These are the fundamental commands that users interact with most

# Show help function
_cmd_help() {
    # Set up IMAGE_NAME if we're in a project directory
    if [[ -n "${PROJECT_DIR:-}" ]]; then
        # Initialize project directory to ensure parent exists
        init_project_dir "$PROJECT_DIR"
        IMAGE_NAME=$(get_image_name 2>/dev/null || echo "")
    fi

    # Check for subcommands
    local subcommand="${1:-}"

    case "$subcommand" in
    "full")
        show_full_help
        ;;
    "claude")
        show_claude_help
        ;;
    "commands")
        show_claudebox_commands
        ;;
    "")
        # Always show ClaudeBox help first - users need to discover ClaudeBox commands
        show_help
        ;;
    *)
        # Unknown subcommand - show regular help
        show_help
        ;;
    esac

    exit 0
}

_cmd_shell() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo "[DEBUG] _cmd_shell called with args: $*" >&2
    fi

    # Set up slot variables if not already set
    if [[ -z "${IMAGE_NAME:-}" ]]; then
        local project_folder_name
        project_folder_name=$(get_project_folder_name "$PROJECT_DIR" 2>/dev/null || echo "NONE")

        if [[ "$project_folder_name" == "NONE" ]]; then
            show_no_slots_menu # This will exit
        fi

        IMAGE_NAME=$(get_image_name)
        PROJECT_SLOT_DIR="$PROJECT_PARENT_DIR/$project_folder_name"
        export PROJECT_SLOT_DIR
    fi

    # Check if image exists
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        error "No Docker image found for this project.\nRun 'claudebox' first to build the image."
    fi

    local persist_mode=false
    local shell_flags=()

    # Check if first arg is "admin"
    if [[ "${1:-}" == "admin" ]]; then
        persist_mode=true
        shift
        # In admin mode, automatically enable sudo and disable firewall
        shell_flags+=("--enable-sudo" "--disable-firewall")
    fi

    # Process remaining flags (only for non-persist mode)
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --enable-sudo | --disable-firewall)
            if [[ "$persist_mode" == "false" ]]; then
                shell_flags+=("$1")
            fi
            shift
            ;;
        *)
            shift
            ;;
        esac
    done

    # Run container for shell
    if [[ "$persist_mode" == "true" ]]; then
        cecho "Administration Mode" "$YELLOW"
        echo "Sudo enabled, firewall disabled."
        echo "Changes will be saved to the image when you exit."
        echo

        # Create a named container for admin mode so we can commit it
        local temp_container="claudebox-admin-$$"

        # Ensure cleanup runs on any exit (including Ctrl-C)
        cleanup_admin() {
            docker commit "$temp_container" "$IMAGE_NAME" >/dev/null 2>&1
            docker rm -f "$temp_container" >/dev/null 2>&1
        }
        trap cleanup_admin EXIT

        if [[ "$VERBOSE" == "true" ]]; then
            echo "[DEBUG] Running admin container with flags: ${shell_flags[*]}" >&2
            echo "[DEBUG] Remaining args after processing: $*" >&2
        fi
        # Don't pass any remaining arguments - only shell and the flags
        run_claudebox_container "$temp_container" "interactive" shell "${shell_flags[@]}"

        # Commit changes back to image
        fillbar
        docker commit "$temp_container" "$IMAGE_NAME" >/dev/null
        docker rm -f "$temp_container" >/dev/null 2>&1
        fillbar stop
        success "Changes saved to image!"
    else
        # Regular shell mode - just run without committing
        run_claudebox_container "" "interactive" shell "${shell_flags[@]}"
    fi

    exit 0
}

_cmd_update_self() {
    # ClaudeBox self-update using git
    update_claudebox_self "$@"
}

_cmd_update_status() {
    # Show ClaudeBox update status
    show_update_status
}

_cmd_update_all() {
    # Update both ClaudeBox and Claude - same as 'update all' but as standalone command
    info "Updating all components..."
    echo
    
    # First update ClaudeBox itself
    info "Updating ClaudeBox..."
    if update_claudebox_self update; then
        success "✓ ClaudeBox updated successfully"
    else
        warn "ClaudeBox update had issues, continuing with Claude update..."
    fi
    echo
    
    # Then update Claude
    info "Updating Claude..."
    
    # Check if image exists first
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        error "No Docker image found for this project folder: $PROJECT_DIR\nRun 'claudebox' first to build the image, or cd to your project directory."
    fi

    # Continue with normal update flow for Claude
    _cmd_special "update" "$@"
}

_cmd_update() {
    # Update only Claude CLI (no longer handles 'all' - use update-all command instead)
    
    # Check if image exists first
    if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        error "No Docker image found for this project folder: $PROJECT_DIR\nRun 'claudebox' first to build the image, or cd to your project directory."
    fi

    # Continue with normal Claude update flow
    _cmd_special "update" "$@"
}

export -f _cmd_help _cmd_shell _cmd_update _cmd_update_self _cmd_update_status _cmd_update_all
