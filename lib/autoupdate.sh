#!/usr/bin/env bash
# ClaudeBox Auto-Update System
# Git-based update management with automatic symlink handling

# ============================================================================
# Git Repository Management
# ============================================================================

# Check if current script is running from a git repository
is_running_from_git() {
    local script_dir="${CLAUDEBOX_SCRIPT_DIR:-}"
    [[ -n "$script_dir" ]] && [[ -d "$script_dir/.git" ]]
}

# Get the git repository path for the running script
get_git_repo_path() {
    local script_dir="${CLAUDEBOX_SCRIPT_DIR:-}"
    if [[ -d "$script_dir/.git" ]]; then
        echo "$script_dir"
    else
        return 1
    fi
}

# Check if git repository is clean (no uncommitted changes)
is_git_repo_clean() {
    local repo_path="$1"
    [[ -z "$(cd "$repo_path" && git status --porcelain 2>/dev/null)" ]]
}

# Get current git branch
get_current_branch() {
    local repo_path="$1"
    cd "$repo_path" && git branch --show-current 2>/dev/null
}

# Get current git commit hash
get_current_commit() {
    local repo_path="$1"
    cd "$repo_path" && git rev-parse HEAD 2>/dev/null
}

# Check if remote has updates
has_remote_updates() {
    local repo_path="$1"
    cd "$repo_path" && git fetch --quiet 2>/dev/null
    local local_commit=$(git rev-parse HEAD 2>/dev/null)
    local remote_commit=$(git rev-parse @{u} 2>/dev/null)
    [[ "$local_commit" != "$remote_commit" ]]
}

# ============================================================================
# Symlink Management  
# ============================================================================

# Find all symlinks pointing to ClaudeBox
find_claudebox_symlinks() {
    local script_path="$1"
    local symlinks=()
    
    # Common locations to check
    local search_paths=(
        "/usr/local/bin"
        "/usr/bin" 
        "$HOME/.local/bin"
        "$HOME/bin"
    )
    
    for path in "${search_paths[@]}"; do
        if [[ -d "$path" ]]; then
            while IFS= read -r -d '' symlink; do
                local target
                target=$(readlink "$symlink" 2>/dev/null)
                if [[ "$target" == "$script_path" ]] || [[ "$(readlink -f "$symlink" 2>/dev/null)" == "$script_path" ]]; then
                    symlinks+=("$symlink")
                fi
            done < <(find "$path" -name "claudebox" -type l -print0 2>/dev/null)
        fi
    done
    
    printf '%s\n' "${symlinks[@]}"
}

# Update symlinks to point to new location
update_symlinks() {
    local old_target="$1"
    local new_target="$2"
    
    if [[ "$old_target" == "$new_target" ]]; then
        return 0
    fi
    
    local symlinks
    mapfile -t symlinks < <(find_claudebox_symlinks "$old_target")
    
    local updated_count=0
    for symlink in "${symlinks[@]}"; do
        if [[ -L "$symlink" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                echo "[DEBUG] Updating symlink: $symlink -> $new_target" >&2
            fi
            
            if [[ -w "$(dirname "$symlink")" ]]; then
                ln -sf "$new_target" "$symlink"
            else
                sudo ln -sf "$new_target" "$symlink"
            fi
            ((updated_count++))
        fi
    done
    
    if [[ $updated_count -gt 0 ]]; then
        info "Updated $updated_count symlink(s) to point to updated ClaudeBox"
    fi
}

# ============================================================================
# Backup and Rollback
# ============================================================================

# Create backup before update
create_update_backup() {
    local repo_path="$1"
    local backup_name="pre-update-$(date +%Y%m%d-%H%M%S)"
    
    cd "$repo_path"
    if git tag "$backup_name" 2>/dev/null; then
        info "Created backup tag: $backup_name"
        echo "$backup_name" > "$HOME/.claudebox/last-backup-tag"
        return 0
    else
        warn "Failed to create backup tag"
        return 1
    fi
}

# Rollback to previous version
rollback_update() {
    local repo_path="$1"
    local backup_file="$HOME/.claudebox/last-backup-tag"
    
    if [[ -f "$backup_file" ]]; then
        local backup_tag
        backup_tag=$(cat "$backup_file")
        
        cd "$repo_path"
        if git checkout "$backup_tag" 2>/dev/null; then
            success "Rolled back to backup: $backup_tag"
            return 0
        else
            error "Failed to rollback to backup: $backup_tag"
            return 1
        fi
    else
        error "No backup tag found for rollback"
        return 1
    fi
}

# ============================================================================
# Git-based Update Process
# ============================================================================

# Update ClaudeBox from git repository
update_claudebox_git() {
    local repo_path
    repo_path=$(get_git_repo_path) || {
        error "Not running from git repository. Use install method instead."
        return 1
    }
    
    info "Updating ClaudeBox from git repository..."
    echo "Repository: $repo_path"
    
    # Check git status
    if ! is_git_repo_clean "$repo_path"; then
        warn "Git repository has uncommitted changes:"
        cd "$repo_path" && git status --short
        echo
        printf "Continue with update anyway? [y/N]: "
        local answer
        read -r answer
        if [[ "${answer,,}" != "y" ]]; then
            info "Update cancelled by user"
            return 1
        fi
    fi
    
    # Check for remote updates
    info "Checking for updates..."
    if ! has_remote_updates "$repo_path"; then
        success "ClaudeBox is already up to date"
        return 0
    fi
    
    # Show what will be updated
    local current_commit
    current_commit=$(get_current_commit "$repo_path")
    cd "$repo_path"
    local remote_commit
    remote_commit=$(git rev-parse @{u} 2>/dev/null)
    
    info "Updates available:"
    git log --oneline "$current_commit..$remote_commit" | head -5
    echo
    
    # Create backup
    create_update_backup "$repo_path"
    
    # Perform update
    info "Pulling updates..."
    local old_script_path="$repo_path/main.sh"
    
    cd "$repo_path"
    if git pull --ff-only; then
        success "✓ Successfully updated ClaudeBox"
        
        # Update symlinks if needed
        local new_script_path="$repo_path/main.sh"
        update_symlinks "$old_script_path" "$new_script_path"
        
        # Verify update
        verify_update "$repo_path"
        
    else
        error "Failed to update. You may need to resolve conflicts manually."
        return 1
    fi
}

# Install ClaudeBox from git repository (for non-git installations)
install_claudebox_git() {
    local install_dir="$HOME/.local/share/claudebox"
    local repo_url="https://github.com/puffo/claudebox.git"
    
    info "Installing ClaudeBox from git repository..."
    
    # Create installation directory
    mkdir -p "$(dirname "$install_dir")"
    
    # Clone repository
    if [[ -d "$install_dir" ]]; then
        warn "Installation directory already exists: $install_dir"
        printf "Remove and reinstall? [y/N]: "
        local answer
        read -r answer
        if [[ "${answer,,}" == "y" ]]; then
            rm -rf "$install_dir"
        else
            info "Installation cancelled"
            return 1
        fi
    fi
    
    info "Cloning repository..."
    if git clone "$repo_url" "$install_dir"; then
        success "✓ Repository cloned successfully"
        
        # Create symlink
        local symlink_path="$HOME/.local/bin/claudebox"
        local script_path="$install_dir/main.sh"
        
        mkdir -p "$(dirname "$symlink_path")"
        
        if [[ -e "$symlink_path" ]]; then
            warn "Existing claudebox found at $symlink_path"
            if [[ -L "$symlink_path" ]]; then
                info "Updating existing symlink"
                ln -sf "$script_path" "$symlink_path"
            else
                error "Existing claudebox is not a symlink. Please remove manually."
                return 1
            fi
        else
            ln -sf "$script_path" "$symlink_path"
            success "✓ Created symlink: $symlink_path -> $script_path"
        fi
        
        # Verify installation
        verify_update "$install_dir"
        
        # Add to PATH if needed
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            warn "Add $HOME/.local/bin to your PATH to use 'claudebox' command:"
            echo "  echo 'export PATH=\"\$HOME/.local/bin:\$PATH\"' >> ~/.bashrc"
        fi
        
    else
        error "Failed to clone repository"
        return 1
    fi
}

# ============================================================================
# Update Verification
# ============================================================================

# Verify that update was successful
verify_update() {
    local repo_path="$1"
    local script_path="$repo_path/main.sh"
    
    info "Verifying update..."
    
    # Check script is executable
    if [[ ! -x "$script_path" ]]; then
        error "Main script is not executable: $script_path"
        return 1
    fi
    
    # Test basic functionality
    if "$script_path" help >/dev/null 2>&1; then
        success "✓ Update verification passed"
    else
        error "Update verification failed - basic functionality broken"
        warn "You may need to rollback: claudebox update --rollback"
        return 1
    fi
    
    # Show version info
    local commit_hash
    commit_hash=$(get_current_commit "$repo_path")
    local branch
    branch=$(get_current_branch "$repo_path")
    
    info "Updated to:"
    echo "  Branch: $branch"
    echo "  Commit: ${commit_hash:0:8}"
    
    # Check symlinks
    local symlinks
    mapfile -t symlinks < <(find_claudebox_symlinks "$script_path")
    if [[ ${#symlinks[@]} -gt 0 ]]; then
        info "Active symlinks:"
        printf "  %s\n" "${symlinks[@]}"
    fi
}

# ============================================================================
# Main Update Command
# ============================================================================

# Main update function with different modes
update_claudebox_self() {
    local mode="${1:-update}"
    
    case "$mode" in
    help|-h|--help)
        echo "ClaudeBox Self-Update Commands:"
        echo
        echo "  claudebox update-self         Update ClaudeBox to latest version"
        echo "  claudebox update-self install Install ClaudeBox from git repository"  
        echo "  claudebox update-self rollback Rollback to previous version"
        echo "  claudebox update-status       Show ClaudeBox update status"
        echo "  claudebox update-all          Update both ClaudeBox and Claude"
        echo
        return 0
        ;;
    status)
        show_update_status
        ;;
    rollback)
        local repo_path
        if repo_path=$(get_git_repo_path); then
            rollback_update "$repo_path"
        else
            error "Not running from git repository"
            return 1
        fi
        ;;
    install)
        install_claudebox_git
        ;;
    update|self|"")
        if is_running_from_git; then
            update_claudebox_git
        else
            warn "Not running from git repository."
            printf "Install git-based version? [y/N]: "
            local answer
            read -r answer
            if [[ "${answer,,}" == "y" ]]; then
                install_claudebox_git
            fi
        fi
        ;;
    *)
        error "Unknown update mode: $mode"
        update_claudebox_self --help
        return 1
        ;;
    esac
}

# Show current update status
show_update_status() {
    logo_small
    echo
    cecho "ClaudeBox Update Status" "$CYAN"
    echo
    
    if is_running_from_git; then
        local repo_path
        repo_path=$(get_git_repo_path)
        local branch
        branch=$(get_current_branch "$repo_path")
        local commit
        commit=$(get_current_commit "$repo_path")
        
        cecho "🔄 Git Repository Mode" "$WHITE"
        echo "   Repository: $repo_path"
        echo "   Branch:     $branch"
        echo "   Commit:     ${commit:0:8}"
        
        if is_git_repo_clean "$repo_path"; then
            echo "   Status:     ✅ Clean"
        else
            echo "   Status:     ⚠️  Has uncommitted changes"
        fi
        
        echo
        info "Checking for updates..."
        if has_remote_updates "$repo_path"; then
            cecho "📦 Updates Available" "$YELLOW"
            cd "$repo_path"
            git log --oneline HEAD..@{u} | head -3
            echo
            echo "Run 'claudebox update --self' to update"
        else
            cecho "✅ Up to date" "$GREEN"
        fi
        
    else
        cecho "📦 Installed Version Mode" "$WHITE"
        echo "   Location: $(which claudebox 2>/dev/null || echo "Not found")"
        echo "   Type:     Non-git installation"
        echo
        echo "Run 'claudebox update --install' to switch to git-based updates"
    fi
    
    echo
    # Show symlinks
    local script_path="${SCRIPT_PATH:-}"
    if [[ -n "$script_path" ]]; then
        local symlinks
        mapfile -t symlinks < <(find_claudebox_symlinks "$script_path")
        if [[ ${#symlinks[@]} -gt 0 ]]; then
            cecho "🔗 Active Symlinks" "$WHITE"
            printf "   %s\n" "${symlinks[@]}"
        fi
    fi
    
    echo
}

# Export functions
export -f is_running_from_git get_git_repo_path is_git_repo_clean get_current_branch get_current_commit
export -f has_remote_updates find_claudebox_symlinks update_symlinks create_update_backup rollback_update
export -f update_claudebox_git install_claudebox_git verify_update update_claudebox_self show_update_status