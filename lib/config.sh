#!/usr/bin/env bash
# Configuration management including INI files and profile definitions.

# -------- INI file helpers ----------------------------------------------------
_read_ini() { # $1=file $2=section $3=key
    awk -F' *= *' -v s="[$2]" -v k="$3" '
    $0==s {in=1; next}
    /^\[/ {in=0}
    in && $1==k {print $2; exit}
  ' "$1" 2>/dev/null
}

# -------- Profile functions (Bash 3.2 compatible) -----------------------------
get_profile_packages() {
    case "$1" in
    core) echo "gcc g++ make git pkg-config libssl-dev libffi-dev zlib1g-dev tmux" ;;
    build-tools) echo "cmake ninja-build autoconf automake libtool" ;;
    shell) echo "rsync openssh-client man-db gnupg2 aggregate file" ;;
    networking) echo "iptables ipset iproute2 dnsutils" ;;
    c) echo "gdb valgrind clang clang-format clang-tidy cppcheck doxygen libboost-all-dev libcmocka-dev libcmocka0 lcov libncurses5-dev libncursesw5-dev" ;;
    openwrt) echo "rsync libncurses5-dev zlib1g-dev gawk gettext xsltproc libelf-dev ccache subversion swig time qemu-system-arm qemu-system-aarch64 qemu-system-mips qemu-system-x86 qemu-utils" ;;
    rust) echo "" ;;       # Rust installed via rustup
    python) echo "" ;;     # Managed via uv
    go) echo "" ;;         # Installed from tarball
    javascript) echo "" ;; # Installed via nvm
    java) echo "openjdk-17-jdk maven gradle ant" ;;
    ruby) echo "" ;; # Installed via mise in get_profile_ruby()
    php) echo "php php-cli php-fpm php-mysql php-pgsql php-sqlite3 php-curl php-gd php-mbstring php-xml php-zip composer" ;;
    database) echo "postgresql-client mysql-client sqlite3 redis-tools mongodb-clients" ;;
    devops) echo "docker.io docker-compose kubectl helm terraform ansible awscli" ;;
    web) echo "nginx apache2-utils httpie" ;;
    embedded) echo "gcc-arm-none-eabi gdb-multiarch openocd picocom minicom screen" ;;
    datascience) echo "r-base" ;;
    security) echo "nmap tcpdump wireshark-common netcat-openbsd john hashcat hydra" ;;
    ml) echo "" ;; # Just cmake needed, comes from build-tools now
    *) echo "" ;;
    esac
}

get_profile_description() {
    case "$1" in
    core) echo "Core Development Utilities (compilers, VCS, shell tools)" ;;
    build-tools) echo "Build Tools (CMake, autotools, Ninja)" ;;
    shell) echo "Optional Shell Tools (fzf, SSH, man, rsync, file)" ;;
    networking) echo "Network Tools (IP stack, DNS, route tools)" ;;
    c) echo "C/C++ Development (debuggers, analyzers, Boost, ncurses, cmocka)" ;;
    openwrt) echo "OpenWRT Development (cross toolchain, QEMU, distro tools)" ;;
    rust) echo "Rust Development (installed via rustup)" ;;
    python) echo "Python Development (managed via uv)" ;;
    go) echo "Go Development (installed from upstream archive)" ;;
    javascript) echo "JavaScript/TypeScript (Node installed via nvm)" ;;
    java) echo "Java Development (OpenJDK 17, Maven, Gradle, Ant)" ;;
    ruby) echo "Ruby Development (Ruby via mise with auto-detection, gems, native deps)" ;;
    php) echo "PHP Development (PHP + extensions + Composer)" ;;
    database) echo "Database Tools (clients for major databases)" ;;
    devops) echo "DevOps Tools (Docker, Kubernetes, Terraform, etc.)" ;;
    web) echo "Web Dev Tools (nginx, HTTP test clients)" ;;
    embedded) echo "Embedded Dev (ARM toolchain, serial debuggers)" ;;
    datascience) echo "Data Science (Python, Jupyter, R)" ;;
    security) echo "Security Tools (scanners, crackers, packet tools)" ;;
    ml) echo "Machine Learning (build layer only; Python via uv)" ;;
    *) echo "" ;;
    esac
}

get_all_profile_names() {
    echo "core build-tools shell networking c openwrt rust python go javascript java ruby php database devops web embedded datascience security ml"
}

profile_exists() {
    local profile="$1"
    for p in $(get_all_profile_names); do
        [[ "$p" == "$profile" ]] && return 0
    done
    return 1
}

expand_profile() {
    case "$1" in
    c) echo "core build-tools c" ;;
    openwrt) echo "core build-tools openwrt" ;;
    ml) echo "core build-tools ml" ;;
    rust | go | python | php | ruby | java | database | devops | web | embedded | datascience | security | javascript)
        echo "core $1"
        ;;
    shell | networking | build-tools | core)
        echo "$1"
        ;;
    *)
        echo "$1"
        ;;
    esac
}

# -------- Profile file management ---------------------------------------------
get_profile_file_path() {
    # Use the parent directory name, not the slot name
    local parent_name=$(generate_parent_folder_name "$PROJECT_DIR")
    local parent_dir="$HOME/.claudebox/projects/$parent_name"
    mkdir -p "$parent_dir"
    echo "$parent_dir/profiles.ini"
}

read_config_value() {
    local config_file="$1"
    local section="$2"
    local key="$3"

    [[ -f "$config_file" ]] || return 1

    awk -F ' *= *' -v section="[$section]" -v key="$key" '
        $0 == section { in_section=1; next }
        /^\[/ { in_section=0 }
        in_section && $1 == key { print $2; exit }
    ' "$config_file"
}

read_profile_section() {
    local profile_file="$1"
    local section="$2"
    local result=()

    if [[ -f "$profile_file" ]] && grep -q "^\[$section\]" "$profile_file"; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^\[.*\]$ ]] && break
            result+=("$line")
        done < <(sed -n "/^\[$section\]/,/^\[/p" "$profile_file" | tail -n +2 | grep -v '^\[')
    fi

    printf '%s\n' "${result[@]}"
}

update_profile_section() {
    local profile_file="$1"
    local section="$2"
    shift 2
    local new_items=("$@")

    local existing_items=()
    readarray -t existing_items < <(read_profile_section "$profile_file" "$section")

    local all_items=()
    for item in "${existing_items[@]}"; do
        [[ -n "$item" ]] && all_items+=("$item")
    done

    for item in "${new_items[@]}"; do
        local found=false
        for existing in "${all_items[@]}"; do
            [[ "$existing" == "$item" ]] && found=true && break
        done
        [[ "$found" == "false" ]] && all_items+=("$item")
    done

    {
        if [[ -f "$profile_file" ]]; then
            awk -v sect="$section" '
                BEGIN { in_section=0; skip_section=0 }
                /^\[/ {
                    if ($0 == "[" sect "]") { skip_section=1; in_section=1 }
                    else { skip_section=0; in_section=0 }
                }
                !skip_section { print }
                /^\[/ && !skip_section && in_section { in_section=0 }
            ' "$profile_file"
        fi

        echo "[$section]"
        for item in "${all_items[@]}"; do
            echo "$item"
        done
        echo ""
    } >"${profile_file}.tmp" && mv "${profile_file}.tmp" "$profile_file"
}

get_current_profiles() {
    local profiles_file="${PROJECT_PARENT_DIR:-$HOME/.claudebox/projects/$(generate_parent_folder_name "$PWD")}/profiles.ini"
    local current_profiles=()

    if [[ -f "$profiles_file" ]]; then
        while IFS= read -r line; do
            [[ -n "$line" ]] && current_profiles+=("$line")
        done < <(read_profile_section "$profiles_file" "profiles")
    fi

    printf '%s\n' "${current_profiles[@]}"
}

# -------- Profile installation functions for Docker builds -------------------
get_profile_core() {
    local packages=$(get_profile_packages "core")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_build_tools() {
    local packages=$(get_profile_packages "build-tools")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_shell() {
    local packages=$(get_profile_packages "shell")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_networking() {
    local packages=$(get_profile_packages "networking")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_c() {
    local packages=$(get_profile_packages "c")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_openwrt() {
    local packages=$(get_profile_packages "openwrt")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_rust() {
    cat <<'EOF'
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/home/claude/.cargo/bin:$PATH"
EOF
}

get_profile_python() {
    cat <<'EOF'
# Python profile - uv already installed in base image
# Python venv and dev tools are managed via entrypoint flag system
EOF
}

get_profile_go() {
    cat <<'EOF'
RUN wget -O go.tar.gz https://golang.org/dl/go1.21.0.linux-amd64.tar.gz && \
    tar -C /usr/local -xzf go.tar.gz && \
    rm go.tar.gz
ENV PATH="/usr/local/go/bin:$PATH"
EOF
}

get_profile_javascript() {
    cat <<'EOF'
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash
ENV NVM_DIR="/home/claude/.nvm"
RUN . $NVM_DIR/nvm.sh && nvm install --lts
USER claude
RUN bash -c "source $NVM_DIR/nvm.sh && npm install -g typescript eslint prettier yarn pnpm"
USER root
EOF
}

get_profile_java() {
    local packages=$(get_profile_packages "java")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

# Detect Ruby version from project files or environment
detect_ruby_version() {
    local ruby_version=""
    # Use PROJECT_DIR if available (set by main.sh), otherwise use pwd or argument
    local project_dir="${1:-${PROJECT_DIR:-$(pwd)}}"

    # 1. Check environment variable override (highest priority)
    if [[ -n "${CLAUDEBOX_RUBY_VERSION:-}" ]]; then
        ruby_version="${CLAUDEBOX_RUBY_VERSION}"
        if [[ "$VERBOSE" == "true" ]]; then
            printf "Using Ruby version from CLAUDEBOX_RUBY_VERSION: %s\n" "$ruby_version" >&2
        fi
        echo "$ruby_version"
        return 0
    fi

    # 2. Check .ruby-version file (compatible with rbenv, rvm, chruby, mise)
    if [[ -f "$project_dir/.ruby-version" ]]; then
        ruby_version=$(head -n1 "$project_dir/.ruby-version" | tr -d '[:space:]')
        if [[ -n "$ruby_version" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                printf "Using Ruby version from .ruby-version: %s\n" "$ruby_version" >&2
            fi
            echo "$ruby_version"
            return 0
        fi
    fi

    # 3. Check mise.toml file (mise/rtx)
    if [[ -f "$project_dir/mise.toml" ]] || [[ -f "$project_dir/.mise.toml" ]]; then
        local mise_file="$project_dir/mise.toml"
        [[ -f "$project_dir/.mise.toml" ]] && mise_file="$project_dir/.mise.toml"
        # Look for ruby = "3.x.x" or ruby = { version = "3.x.x" }
        ruby_version=$(grep -E '^ruby[[:space:]]*=' "$mise_file" 2>/dev/null |
            sed -E 's/^ruby[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/' |
            sed -E 's/^ruby[[:space:]]*=[[:space:]]*\{[[:space:]]*version[[:space:]]*=[[:space:]]*"([^"]+)".*/\1/' |
            head -n1)
        if [[ -n "$ruby_version" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                printf "Using Ruby version from mise.toml: %s\n" "$ruby_version" >&2
            fi
            echo "$ruby_version"
            return 0
        fi
    fi

    # 4. Check .tool-versions file (asdf/mise)
    if [[ -f "$project_dir/.tool-versions" ]]; then
        ruby_version=$(grep '^ruby[[:space:]]' "$project_dir/.tool-versions" 2>/dev/null | awk '{print $2}' | head -n1)
        if [[ -n "$ruby_version" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                printf "Using Ruby version from .tool-versions: %s\n" "$ruby_version" >&2
            fi
            echo "$ruby_version"
            return 0
        fi
    fi

    # 5. Check Gemfile for ruby directive
    if [[ -f "$project_dir/Gemfile" ]]; then
        # Look for patterns like: ruby "3.2.0", ruby '3.2.0', or ruby "~> 3.2"
        ruby_version=$(grep -E "^[[:space:]]*ruby[[:space:]]+['\"]" "$project_dir/Gemfile" 2>/dev/null |
            sed -E "s/^[[:space:]]*ruby[[:space:]]+['\"]([^'\"]+)['\"].*/\1/" |
            head -n1)
        # Remove version operators like ~>, >=, etc.
        ruby_version=$(echo "$ruby_version" | sed -E 's/^[~><=]+[[:space:]]*//')
        if [[ -n "$ruby_version" ]]; then
            if [[ "$VERBOSE" == "true" ]]; then
                printf "Using Ruby version from Gemfile: %s\n" "$ruby_version" >&2
            fi
            echo "$ruby_version"
            return 0
        fi
    fi

    # 6. Default to latest stable Ruby
    ruby_version="3.4.5"
    if [[ "$VERBOSE" == "true" ]]; then
        printf "No Ruby version specified, using default: %s\n" "$ruby_version" >&2
    fi
    echo "$ruby_version"
}

get_profile_ruby() {
    local ruby_version
    ruby_version=$(detect_ruby_version)

    # Strip 'ruby-' prefix if present (common in some .ruby-version files)
    ruby_version="${ruby_version#ruby-}"

    # Validate Ruby version format (basic check)
    if ! echo "$ruby_version" | grep -qE '^[0-9]+\.[0-9]+(\.[0-9]+)?$'; then
        printf "Warning: Invalid Ruby version format '%s', using default 3.4.5\n" "$ruby_version" >&2
        ruby_version="3.4.5"
    fi

    cat <<EOF
# Install Ruby build dependencies
RUN apt-get update && apt-get install -y \\
    autoconf bison build-essential \\
    libssl-dev libyaml-dev libreadline-dev zlib1g-dev \\
    libncurses5-dev libffi-dev libgdbm-dev libdb-dev \\
    libsqlite3-dev libxml2-dev libxslt1-dev libcurl4-openssl-dev \\
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install mise and Ruby ${ruby_version} as claude user
# Combines mise installation, configuration, and Ruby setup in one layer
USER claude
WORKDIR /home/claude
RUN curl https://mise.run | sh && \\
    export PATH="/home/claude/.local/bin:\$PATH" && \\
    /home/claude/.local/bin/mise settings set experimental true && \\
    /home/claude/.local/bin/mise settings set idiomatic_version_file_enable_tools ruby && \\
    /home/claude/.local/bin/mise settings set trusted_config_paths /workspace && \\
    /home/claude/.local/bin/mise use --global ruby@${ruby_version} && \\
    /home/claude/.local/bin/mise exec -- gem update --system --no-document && \\
    /home/claude/.local/bin/mise exec -- gem install bundler --no-document && \\
    echo 'export PATH="/home/claude/.local/bin:\$PATH"' >> /home/claude/.bashrc && \\
    echo 'export PATH="/home/claude/.local/bin:\$PATH"' >> /home/claude/.zshrc && \\
    echo 'eval "\$(/home/claude/.local/bin/mise activate bash)"' >> /home/claude/.bashrc && \\
    echo 'eval "\$(/home/claude/.local/bin/mise activate zsh)"' >> /home/claude/.zshrc && \\
    echo "gem: --no-document --user-install" > /home/claude/.gemrc

# Switch back to root for remaining setup
USER root
WORKDIR /workspace

# Set up mise and Ruby environment paths
ENV PATH="/home/claude/.local/bin:/home/claude/.local/share/mise/shims:\${PATH}"
ENV MISE_GLOBAL_CONFIG_FILE="/home/claude/.config/mise/config.toml"
ENV MISE_DATA_DIR="/home/claude/.local/share/mise"
ENV MISE_CACHE_DIR="/home/claude/.cache/mise"
ENV GEM_HOME="/home/claude/.gem"
ENV PATH="/home/claude/.gem/bin:\${PATH}"
EOF

    # Check if Gemfile exists in the project and add bundle install
    if [[ -f "${PROJECT_DIR}/Gemfile" ]]; then
        cat <<EOF

# Copy and install project gems (optimizes Docker layer caching)
COPY --chown=claude:claude Gemfile* /tmp/bundle/
USER claude
WORKDIR /tmp/bundle
RUN bundle install --jobs 4 --retry 3 || true
USER root
WORKDIR /workspace
EOF
    fi

    echo ""
}

get_profile_php() {
    local packages=$(get_profile_packages "php")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_database() {
    local packages=$(get_profile_packages "database")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_devops() {
    local packages=$(get_profile_packages "devops")

    # Install prerequisites for all repositories if needed
    if [[ "$packages" == *"docker"* ]] || [[ "$packages" == *"terraform"* ]] || [[ "$packages" == *"helm"* ]] || [[ "$packages" == *"kubectl"* ]]; then
        cat <<'EOF'
# Install prerequisites for repositories
RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    wget \
    apt-transport-https && \
    apt-get clean

EOF
    fi

    # Set up Docker repository if Docker packages are requested
    if [[ "$packages" == *"docker"* ]]; then
        cat <<'EOF'
# Add Docker's official GPG key and repository
RUN install -m 0755 -d /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    chmod a+r /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

EOF
    fi

    # Set up Kubernetes repository if kubectl is requested
    if [[ "$packages" == *"kubectl"* ]]; then
        cat <<'EOF'
# Add Kubernetes official GPG key and repository for kubectl
RUN mkdir -p -m 755 /etc/apt/keyrings && \
    curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.33/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg && \
    echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.33/deb/ /' | \
    tee /etc/apt/sources.list.d/kubernetes.list && \
    chmod 644 /etc/apt/sources.list.d/kubernetes.list

EOF
    fi

    # Set up Helm repository if requested
    if [[ "$packages" == *"helm"* ]]; then
        cat <<'EOF'
# Add Helm's official GPG key and repository
RUN curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | tee /usr/share/keyrings/helm.gpg > /dev/null && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | \
    tee /etc/apt/sources.list.d/helm-stable-debian.list

EOF
    fi

    # Set up Terraform repository if requested
    if [[ "$packages" == *"terraform"* ]]; then
        cat <<'EOF'
# Add HashiCorp's official GPG key and repository for Terraform
RUN wget -O - https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list

EOF
    fi

    # Install packages - Docker packages will be mapped to their official equivalents
    if [[ -n "$packages" ]]; then
        # Replace docker.io with docker-ce packages and add docker-compose-plugin
        local docker_packages=""
        local other_packages=""

        for pkg in $packages; do
            case "$pkg" in
            docker.io)
                docker_packages="docker-ce docker-ce-cli containerd.io docker-buildx-plugin"
                ;;
            docker-compose)
                docker_packages="$docker_packages docker-compose-plugin"
                ;;
            *)
                other_packages="$other_packages $pkg"
                ;;
            esac
        done

        if [[ -n "$docker_packages" || -n "$other_packages" ]]; then
            echo "# Install DevOps tools"
            echo "RUN apt-get update && apt-get install -y \\"
            if [[ -n "$docker_packages" ]]; then
                for pkg in $docker_packages; do
                    echo "    $pkg \\"
                done
            fi
            if [[ -n "$other_packages" ]]; then
                for pkg in $other_packages; do
                    echo "    $pkg \\"
                done
            fi
            echo "    && apt-get clean"
        fi
    fi
}

get_profile_web() {
    local packages=$(get_profile_packages "web")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_embedded() {
    local packages=$(get_profile_packages "embedded")
    if [[ -n "$packages" ]]; then
        cat <<'EOF'
RUN apt-get update && apt-get install -y gcc-arm-none-eabi gdb-multiarch openocd picocom minicom screen && apt-get clean
USER claude
RUN ~/.local/bin/uv tool install platformio
USER root
EOF
    fi
}

get_profile_datascience() {
    local packages=$(get_profile_packages "datascience")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_security() {
    local packages=$(get_profile_packages "security")
    if [[ -n "$packages" ]]; then
        echo "RUN apt-get update && apt-get install -y $packages && apt-get clean"
    fi
}

get_profile_ml() {
    # ML profile just needs build tools which are dependencies
    echo "# ML profile uses build-tools for compilation"
}

export -f _read_ini get_profile_packages get_profile_description get_all_profile_names profile_exists expand_profile
export -f get_profile_file_path read_config_value read_profile_section update_profile_section get_current_profiles
export -f get_profile_core get_profile_build_tools get_profile_shell get_profile_networking get_profile_c get_profile_openwrt
export -f get_profile_rust get_profile_python get_profile_go get_profile_javascript get_profile_java get_profile_ruby
export -f get_profile_php get_profile_database get_profile_devops get_profile_web get_profile_embedded get_profile_datascience
export -f get_profile_security get_profile_ml
