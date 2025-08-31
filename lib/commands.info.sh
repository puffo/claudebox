#!/usr/bin/env bash
# Info Commands - Information display
# ============================================================================
# Commands: info, projects, allowlist, status
# Shows system, project, and configuration information

_cmd_projects() {
    cecho "ClaudeBox Projects:" "$CYAN"
    echo
    printf "%10s  %s  %s\n" "Size" "🐳" "Path"
    printf "%10s  %s  %s\n" "----" "--" "----"

    if ! list_all_projects; then
        echo
        warn "No ClaudeBox projects found."
        echo
        cecho "Start a new project:" "$GREEN"
        echo "  cd /your/project/directory"
        echo "  claudebox"
    fi
    echo
    exit 0
}

_cmd_allowlist() {
    # Allowlist is stored in parent directory, not slot directory
    local allowlist_file="$PROJECT_PARENT_DIR/allowlist"

    cecho "🔒 ClaudeBox Firewall Allowlist" "$CYAN"
    echo
    cecho "Current Project: $PROJECT_DIR" "$WHITE"
    echo

    if [[ -f "$allowlist_file" ]]; then
        cecho "Allowlist file:" "$GREEN"
        echo "  $allowlist_file"
        echo
        cecho "Allowed domains:" "$CYAN"
        # Display allowlist contents
        while IFS= read -r line; do
            if [[ -n "$line" ]] && [[ ! "$line" =~ ^#.* ]]; then
                echo "  $line"
            fi
        done <"$allowlist_file"
        echo
    else
        cecho "Allowlist file:" "$YELLOW"
        echo "  Not yet created (will be created on first run)"
        echo "  Location: $allowlist_file"
    fi

    echo
    cecho "Default Allowed Domains:" "$CYAN"
    echo "  api.anthropic.com, console.anthropic.com, statsig.anthropic.com, sentry.io"
    echo
    cecho "To edit allowlist:" "$YELLOW"
    echo "  \$EDITOR $allowlist_file"
    echo
    cecho "Note:" "$WHITE"
    echo "  Changes take effect on next container start"
    echo "  Use --disable-firewall flag to bypass all restrictions"

    exit 0
}

_cmd_info() {
    # Compute project folder name early for paths
    local project_folder_name
    project_folder_name=$(get_project_folder_name "$PROJECT_DIR")
    IMAGE_NAME="claudebox-${project_folder_name}"
    PROJECT_SLOT_DIR="$HOME/.claudebox/projects/$project_folder_name"

    cecho "╔═══════════════════════════════════════════════════════════════════╗" "$CYAN"
    cecho "║                    ClaudeBox Information Panel                    ║" "$CYAN"
    cecho "╚═══════════════════════════════════════════════════════════════════╝" "$CYAN"
    echo

    # Current Project Info
    cecho "📁 Current Project" "$WHITE"
    echo "   Path:       $PROJECT_DIR"
    echo "   Project ID: $project_folder_name"
    echo "   Data Dir:   $PROJECT_SLOT_DIR"
    echo

    # ClaudeBox Installation
    cecho "📦 ClaudeBox Installation" "$WHITE"
    echo "   Script:  $SCRIPT_PATH"
    echo "   Symlink: $LINK_TARGET"
    echo

    # Saved CLI Flags
    cecho "🚀 Saved CLI Flags" "$WHITE"
    if [[ -f "$HOME/.claudebox/default-flags" ]]; then
        local saved_flags=()
        while IFS= read -r flag; do
            [[ -n "$flag" ]] && saved_flags+=("$flag")
        done <"$HOME/.claudebox/default-flags"
        if [[ ${#saved_flags[@]} -gt 0 ]]; then
            echo -e "   Flags: ${GREEN}${saved_flags[*]}${NC}"
        else
            echo -e "   ${YELLOW}No flags saved${NC}"
        fi
    else
        echo -e "   ${YELLOW}No saved flags${NC}"
    fi
    echo

    # Claude Commands
    cecho "📝 Claude Commands" "$WHITE"
    local cmd_count=0
    if [[ -d "$HOME/.claude/commands" ]]; then
        cmd_count=$(ls -1 "$HOME/.claude/commands"/*.md 2>/dev/null | wc -l)
    fi
    local project_cmd_count=0
    if [[ -e "$PROJECT_PARENT_DIR/commands" ]]; then
        project_cmd_count=$(ls -1 "$PROJECT_PARENT_DIR/commands"/*.md 2>/dev/null | wc -l)
    fi

    if [[ $cmd_count -gt 0 ]] || [[ $project_cmd_count -gt 0 ]]; then
        echo "   Host:    $cmd_count command(s)"
        if [[ $cmd_count -gt 0 ]] && [[ -d "$HOME/.claude/commands" ]]; then
            for cmd_file in "$HOME/.claude/commands"/*.md; do
                [[ -f "$cmd_file" ]] || continue
                echo "            - $(basename "$cmd_file" .md)"
            done
        fi
        echo "   Project: $project_cmd_count command(s) (shared)"
        if [[ $project_cmd_count -gt 0 ]] && [[ -e "$PROJECT_PARENT_DIR/commands" ]]; then
            for cmd_file in "$PROJECT_PARENT_DIR/commands"/*.md; do
                [[ -f "$cmd_file" ]] || continue
                echo "            - $(basename "$cmd_file" .md)"
            done
        fi
    else
        echo -e "   ${YELLOW}No custom commands found${NC}"
        echo -e "   Location: ~/.claude/commands/ (host), project/commands/ (shared)"
    fi
    echo

    # Project Profiles
    cecho "🛠️ Project Profiles & Packages" "$WHITE"
    local current_profile_file
    current_profile_file=$(get_profile_file_path)
    if [[ -f "$current_profile_file" ]]; then
        local current_profiles=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_profiles+=("$line")
        done < <(read_profile_section "$current_profile_file" "profiles")
        local current_packages=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_packages+=("$line")
        done < <(read_profile_section "$current_profile_file" "packages")

        if [[ ${#current_profiles[@]} -gt 0 ]]; then
            echo -e "   Installed:  ${GREEN}${current_profiles[*]}${NC}"
        else
            echo -e "   Installed:  ${YELLOW}None${NC}"
        fi

        if [[ ${#current_packages[@]} -gt 0 ]]; then
            echo "   Packages:   ${current_packages[*]}"
        fi
    else
        echo -e "   Status:     ${YELLOW}No profiles installed${NC}"
    fi

    echo -e "   Available:  ${CYAN}core${NC}, python, c, rust, go, javascript, java, ruby, php"
    echo -e "               database, devops, web, ml, security, embedded, networking"
    echo -e "   ${CYAN}Hint:${NC} Run 'claudebox profile' for profile help "
    echo

    cecho "🐳 Docker Status" "$WHITE"
    if [[ -n "${IMAGE_NAME:-}" ]] && docker image inspect "$IMAGE_NAME" &>/dev/null; then
        local image_info=$(docker images --filter "reference=$IMAGE_NAME" --format "{{.Size}}")
        echo -e "   Image:      ${GREEN}Ready${NC} ($IMAGE_NAME - $image_info)"

        local image_created=$(docker inspect "$IMAGE_NAME" --format '{{.Created}}' | cut -d'T' -f1)
        local layer_count=$(docker history "$IMAGE_NAME" --no-trunc --format "{{.CreatedBy}}" | wc -l)
        echo "   Created:    $image_created"
        echo "   Layers:     $layer_count"
    else
        echo -e "   Image:      ${YELLOW}Not built${NC}"
    fi

    local running_containers=$(docker ps --filter "ancestor=$IMAGE_NAME" -q 2>/dev/null)
    if [[ -n "$running_containers" ]]; then
        local container_count=$(echo "$running_containers" | wc -l)
        echo -e "   Containers: ${GREEN}$container_count running${NC}"

        for container_id in $running_containers; do
            local container_stats="$(docker stats --no-stream --format "{{.Container}}: {{.CPUPerc}} CPU, {{.MemUsage}}" "$container_id" 2>/dev/null || echo "")"
            if [[ -n "$container_stats" ]]; then
                echo "               - $container_stats"
            fi
        done
    else
        echo "   Containers: None running"
    fi
    echo

    # All Projects Summary
    cecho "📊 All Projects Summary" "$WHITE"
    local total_projects=$(ls -1d "$HOME/.claudebox/projects"/*/ 2>/dev/null | wc -l)
    echo "   Projects:   $total_projects total"

    local total_size=$(docker images --filter "reference=claudebox-*" --format "{{.Size}}" | awk '{
        size=$1; unit=$2;
        if (unit == "GB") size = size * 1024;
        else if (unit == "KB") size = size / 1024;
        total += size
    } END {
        if (total > 1024) printf "%.1fGB", total/1024;
        else printf "%.1fMB", total
    }')
    local image_count=$(docker images --filter "reference=claudebox-*" -q | wc -l)
    echo "   Images:     $image_count ClaudeBox images using $total_size"

    local docker_stats=$(docker system df --format "table {{.Type}}\t{{.Total}}\t{{.Active}}\t{{.Size}}\t{{.Reclaimable}}" 2>/dev/null | tail -n +2)
    if [[ -n "$docker_stats" ]]; then
        echo "   System:"
        while IFS=$'\t' read -r type total active size reclaim; do
            echo "               - $type: $total total, $active active ($size, $reclaim reclaimable)"
        done <<<"$docker_stats"
    fi
    echo

    exit 0
}

_cmd_status() {
    logo_small
    echo
    cecho "ClaudeBox Project Status" "$CYAN"
    echo
    
    # Project Information
    cecho "📂 Project Information" "$WHITE"
    echo "   Directory:    $(pwd)"
    
    if [[ -n "${PROJECT_PARENT_DIR:-}" ]]; then
        echo "   Parent:       $PROJECT_PARENT_DIR"
        local project_hash=$(basename "$PROJECT_PARENT_DIR")
        echo "   Hash:         $project_hash"
    fi
    echo
    
    # Current Profiles
    cecho "⚙️  Active Profiles" "$WHITE"
    local profiles_file="$PROJECT_PARENT_DIR/profiles.ini"
    if [[ -f "$profiles_file" ]]; then
        local current_profiles=()
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_profiles+=("$line")
        done < <(read_profile_section "$profiles_file" "profiles")
        
        if [[ ${#current_profiles[@]} -gt 0 ]]; then
            printf "   "
            for i in "${!current_profiles[@]}"; do
                printf "%s" "${current_profiles[$i]}"
                if [[ $i -lt $((${#current_profiles[@]} - 1)) ]]; then
                    printf ", "
                fi
            done
            printf "\n"
        else
            echo "   None configured"
        fi
    else
        echo "   None configured"
    fi
    echo
    
    # Docker Image Status
    cecho "🐳 Docker Image" "$WHITE"
    if [[ -n "${IMAGE_NAME:-}" ]]; then
        echo "   Name:         $IMAGE_NAME"
        
        if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
            local image_size=$(docker image inspect "$IMAGE_NAME" --format '{{.Size}}' | awk '{printf "%.1fMB", $1/1024/1024}')
            local image_created=$(docker image inspect "$IMAGE_NAME" --format '{{.Created}}' | cut -d'T' -f1)
            echo "   Status:       ✅ Built ($image_size, created $image_created)"
            
            # Show profile hash from image
            local image_profiles_hash=$(docker inspect "$IMAGE_NAME" --format '{{index .Config.Labels "claudebox.profiles"}}' 2>/dev/null || echo "")
            if [[ -n "$image_profiles_hash" ]]; then
                echo "   Profile Hash: $image_profiles_hash"
            fi
        else
            echo "   Status:       ❌ Not built (run 'claudebox' to build)"
        fi
    else
        echo "   Name:         Not set (no project detected)"
        echo "   Status:       ❌ No project configuration"
    fi
    echo
    
    # Container Slots
    cecho "📦 Container Slots" "$WHITE"
    local project_folder_name
    project_folder_name=$(get_project_folder_name "$PROJECT_DIR" 2>/dev/null || echo "NONE")
    
    if [[ "$project_folder_name" != "NONE" ]] && [[ -n "${PROJECT_PARENT_DIR:-}" ]]; then
        local slot_count=0
        local active_slots=0
        
        if [[ -d "$PROJECT_PARENT_DIR" ]]; then
            # Count slot directories
            for slot_dir in "$PROJECT_PARENT_DIR"/slot-*; do
                if [[ -d "$slot_dir" ]]; then
                    ((slot_count++))
                    local slot_name=$(basename "$slot_dir")
                    local container_name="claudebox-$(basename "$PROJECT_PARENT_DIR")-$slot_name"
                    
                    # Check if container is running
                    if docker ps --format '{{.Names}}' | grep -q "^$container_name$"; then
                        ((active_slots++))
                    fi
                fi
            done
        fi
        
        echo "   Total:        $slot_count slots"
        echo "   Active:       $active_slots running"
        
        if [[ $slot_count -eq 0 ]]; then
            echo "   Next Step:    Run 'claudebox create' to create first slot"
        fi
    else
        echo "   Status:       No slots (no project configuration)"
    fi
    echo
    
    # Quick Actions
    cecho "🚀 Quick Actions" "$WHITE"
    if [[ "$project_folder_name" == "NONE" ]]; then
        echo "   claudebox create    - Set up this project"
    elif ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
        echo "   claudebox           - Build image and launch Claude"
        echo "   claudebox create    - Create authenticated slot"
    else
        echo "   claudebox           - Launch Claude CLI"
        echo "   claudebox shell     - Open development shell"
        echo "   claudebox info      - Show detailed project info"
    fi
    echo
    
    exit 0
}

_cmd_where() {
    logo_small
    echo
    cecho "ClaudeBox Project Paths" "$CYAN"
    echo
    
    # Current Directory
    cecho "📍 Current Location" "$WHITE"
    echo "   Working Dir:  $(pwd)"
    echo "   Real Path:    $(realpath .)"
    echo
    
    # Project Configuration
    cecho "⚙️  Project Configuration" "$WHITE"
    if [[ -n "${PROJECT_PARENT_DIR:-}" ]]; then
        echo "   Parent Dir:   $PROJECT_PARENT_DIR"
        echo "   Project Hash: $(basename "$PROJECT_PARENT_DIR")"
        
        if [[ -f "$PROJECT_PARENT_DIR/profiles.ini" ]]; then
            echo "   Profiles:     $PROJECT_PARENT_DIR/profiles.ini"
        else
            echo "   Profiles:     Not created yet"
        fi
        
        if [[ -f "$PROJECT_PARENT_DIR/allowlist" ]]; then
            echo "   Allowlist:    $PROJECT_PARENT_DIR/allowlist"
        else
            echo "   Allowlist:    Not created yet"
        fi
    else
        echo "   Status:       No ClaudeBox project detected"
    fi
    echo
    
    # Container Slots
    cecho "📦 Container Slots" "$WHITE"
    if [[ -n "${PROJECT_PARENT_DIR:-}" ]] && [[ -d "$PROJECT_PARENT_DIR" ]]; then
        local found_slots=false
        for slot_dir in "$PROJECT_PARENT_DIR"/slot-*; do
            if [[ -d "$slot_dir" ]]; then
                if [[ "$found_slots" == "false" ]]; then
                    found_slots=true
                fi
                local slot_name=$(basename "$slot_dir")
                echo "   $slot_name:    $slot_dir"
            fi
        done
        
        if [[ "$found_slots" == "false" ]]; then
            echo "   Status:       No slots created"
        fi
    else
        echo "   Status:       No project detected"
    fi
    echo
    
    # Docker Information
    cecho "🐳 Docker Resources" "$WHITE"
    if [[ -n "${IMAGE_NAME:-}" ]]; then
        echo "   Image Name:   $IMAGE_NAME"
        
        if docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
            echo "   Image Status: ✅ Available"
        else
            echo "   Image Status: ❌ Not built"
        fi
    else
        echo "   Image Name:   Not set"
        echo "   Image Status: No project detected"
    fi
    
    echo "   Build Context: $HOME/.claudebox/docker-build-context"
    echo
    
    # Global ClaudeBox Paths
    cecho "🏠 Global ClaudeBox" "$WHITE"
    echo "   Install Root: $HOME/.claudebox"
    echo "   Projects:     $HOME/.claudebox/projects/"
    echo "   Commands:     $HOME/.claudebox/commands/"
    echo "   Default Flags: $HOME/.claudebox/default-flags"
    echo
    
    # Script Information
    cecho "📜 Script Information" "$WHITE"
    echo "   Script Path:  ${SCRIPT_PATH:-Unknown}"
    echo "   Script Dir:   ${CLAUDEBOX_SCRIPT_DIR:-Unknown}"
    echo "   Version:      ${CLAUDEBOX_VERSION:-Unknown}"
    echo
    
    exit 0
}

export -f _cmd_projects _cmd_allowlist _cmd_info _cmd_status _cmd_where
