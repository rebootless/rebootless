#!/bin/bash

# This script requires Nerd Fonts to be installed

RESET="\e[0m"
BOLD="\e[1m"
DIM="\e[38;2;110;110;110m"
RED="\e[38;2;168;0;48m"
WHITE="\e[38;2;255;255;255m"

L_CURVE="\ue0b6"
R_CURVE="\ue0b4"

C_DEBIAN="168;29;51"      # #A81D33
C_UBUNTU="233;84;32"      # #E95420
C_QEMU="127;90;240"       # #7F5AF0
C_VBOX="24;58;97"         # #183A61
C_DOCKER="36;150;237"     # #2496ED
C_PORTAINER="19;190;249"  # #13BEF9
C_PROM="230;82;44"        # #E6522C
C_GRAFANA="244;104;0"     # #F46800
C_BASH="78;170;37"        # #4EAA25
C_PYTHON="55;118;171"     # #3776AB
C_CPP="0;89;156"          # #00599C
C_GITHUB="36;41;47"       # #24292F
C_NGINX="0;150;57"        # #009639
C_KATE="61;174;233"       # #3DAEE9
C_KDEV="127;90;240"       # #7F5AF0
C_GIT="240;80;50"         # #F05032
C_ANSIBLE="238;0;0"       # #EE0000
C_OPENTOFU="255;218;24"   # #FFDA18

C_STATS_GITHUB="88;166;255"
C_STATS_SOCIAL="184;108;255"
C_STATS_LANGS="0;184;94"
C_STATS_ACTIVITY="255;170;0"

GITHUB_USER="rebootless"
COL=20

github_get() {
    curl -fsSL \
        -H "User-Agent: git-fetch.sh" \
        -H "Accept: application/vnd.github+json" \
        "$1"
}

print_label() {
    local label="$1"
    local pad=$(( COL - ${#label} - 1 ))
    printf "%b%s%b:%${pad}s" "$RED" "$label" "$RESET" ""
}

info() {
    print_label "$1"
    printf "%s\n" "$2"
}

badge() {
    local rgb="$1"
    local text="$2"

    local fg="\e[38;2;${rgb}m"
    local bg="\e[48;2;${rgb}m"

    printf "%b%b" "$fg" "$L_CURVE"
    printf "%b%b%s" "$bg" "$WHITE" "$text"
    printf "\e[49m%b%b%b" "$fg" "$R_CURVE" "$RESET"
}

row() {
    print_label "$1"; shift

    local printed=0
    while (( $# >= 2 )); do
        (( printed )) && printf " %b❯%b " "$DIM" "$RESET"
        badge "$1" "$2"
        shift 2
        printed=1
    done
    printf "\n"
}

palette() {
    local row1=(
    "$C_DEBIAN" "$C_UBUNTU" "$C_QEMU" "$C_VBOX"
    "$C_DOCKER" "$C_PORTAINER" "$C_PROM" "$C_GRAFANA"
    "$C_ANSIBLE"
    )

    local row2=(
    "$C_OPENTOFU" "$C_BASH" "$C_PYTHON" "$C_CPP"
    "$C_GITHUB" "$C_GIT" "$C_NGINX" "$C_KATE"
    "$C_KDEV"
    )

    local c
    for c in "${row1[@]}"; do
        printf "\e[48;2;%sm    %b" "$c" "$RESET"
    done
    printf "\n"

    for c in "${row2[@]}"; do
        printf "\e[48;2;%sm    %b" "$c" "$RESET"
    done
    printf "\n"
}

show_spinner() {
    local frames=('-' '\' '|' '/')
    local delay=0.1

    (
        while true; do
            for frame in "${frames[@]}"; do
                printf "\r[%s] Fetching GitHub API data..." "$frame"
                sleep $delay
            done
        done
    ) &
    SPINNER_PID=$!
}

hide_spinner() {
    kill "$SPINNER_PID" >/dev/null 2>&1
    wait "$SPINNER_PID" >/dev/null 2>&1
    printf "\r%-$(tput cols)s\r" " "
}

printf "\n"
printf "%b%b$GITHUB_USER%b@%bgithub%b\n" "$BOLD" "$RED" "$RESET" "$RED" "$RESET"
printf "%b–––––––––––––––––%b\n" "$DIM" "$RESET"

info "Whoami" "$GITHUB_USER"
info "Host"   "github.com"
info "Role"   "Linux SysAdmin"
info "Focus"  "Self-hosted · Automation · Observability"

show_spinner

GITHUB_API="$(github_get "https://api.github.com/users/$GITHUB_USER")"
GITHUB_REPOS="$(github_get "https://api.github.com/users/$GITHUB_USER/repos?per_page=100&type=owner&sort=updated")"

get_repos() { printf '%s\n' "$GITHUB_API" | grep '"public_repos"' | sed 's/[^0-9]//g'; }
get_followers() { printf '%s\n' "$GITHUB_API" | grep '"followers"' | head -n1 | sed 's/[^0-9]//g'; }
get_following() { printf '%s\n' "$GITHUB_API" | grep '"following"' | head -n1 | sed 's/[^0-9]//g'; }
get_stars() { printf '%s\n' "$GITHUB_REPOS" | grep '"stargazers_count"' | sed 's/[^0-9]//g' | awk '{s+=$1} END{print s+0}'; }
get_forks() { printf '%s\n' "$GITHUB_REPOS" | grep '"forks_count"' | sed 's/[^0-9]//g' | awk '{s+=$1} END{print s+0}'; }
get_last_push() { printf '%s\n' "$GITHUB_REPOS" | grep '"pushed_at"' | head -n1 | sed 's/.*"pushed_at": "//; s/T.*//; s/".*//'; }

get_top_languages() {
    declare -A langs
    local total=0

    while read -r url; do
        [ -z "$url" ] && continue

        echo "Fetching: $url" >&2

        response=$(
            curl -sS \
                -w '\nHTTP_CODE:%{http_code}' \
                -H "User-Agent: git-fetch.sh" \
                -H "Accept: application/vnd.github+json" \
                "$url"
        )

        code="${response##*HTTP_CODE:}"
        body="${response%HTTP_CODE:*}"

        if [[ "$code" != "200" ]]; then
            echo "HTTP $code" >&2
            echo "$body" >&2
            continue
        fi

        while read -r line; do
            [ -z "$line" ] && continue

            lang=$(echo "$line" | cut -d'"' -f2)
            bytes=$(echo "$line" | grep -o '[0-9]\+')

            [ -z "$lang" ] && continue
            [ -z "$bytes" ] && continue

            langs["$lang"]=$(( ${langs["$lang"]:-0} + bytes ))
            total=$(( total + bytes ))
        done < <(
            echo "$body" | grep -E '"[^"]+": [0-9]+'
        )

    done < <(
        echo "$GITHUB_REPOS" |
        grep '"languages_url"' |
        sed 's/.*"languages_url": "//; s/".*//'
    )

    if (( total == 0 )); then
        return
    fi

    for lang in "${!langs[@]}"; do
        percent=$(awk -v b="${langs[$lang]}" -v t="$total" \
            'BEGIN { printf "%.2f", (b/t)*100 }')

        icon=""
        case "$lang" in
            Shell|Bash|Makefile) icon="" ;;
            Python)              icon="" ;;
            "C++")               icon="" ;;
            C)                   icon="" ;;
            JavaScript)          icon="" ;;
            TypeScript)          icon="" ;;
            CSS)                 icon="" ;;
            HTML)                icon="" ;;
            Go)                  icon="" ;;
            Rust)                icon="" ;;
            Java)                icon="" ;;
            PHP)                 icon="" ;;
            Ruby)                icon="" ;;
            Lua)                 icon="" ;;
        esac

        echo "${lang}|${icon}|${percent}"
    done | sort -t'|' -k3 -nr | head -n 5
}

TOP_LANGS_DATA=$(get_top_languages)

hide_spinner

printf "\n"

row "OS" \
    "$C_DEBIAN"    " Debian" \
    "$C_UBUNTU"    " Ubuntu"

row "Virtualization" \
    "$C_QEMU"      " QEMU/KVM" \
    "$C_VBOX"      " VirtualBox"

row "Containers" \
    "$C_DOCKER"    " Docker" \
    "$C_PORTAINER" " Portainer"

row "Observability" \
    "$C_PROM"      " Prometheus" \
    "$C_GRAFANA"   " Grafana"

row "Infrastructure" \
    "$C_ANSIBLE"   "󱂚 Ansible" \
    "$C_OPENTOFU"  "󱁢 OpenTofu"

row "Languages" \
    "$C_BASH"      " Bash" \
    "$C_PYTHON"    " Python" \
    "$C_CPP"       " C++"

row "Version Control" \
    "$C_GIT"       " Git"

row "CI/CD" \
    "$C_GITHUB"    " GitHub Actions"

row "Web Server" \
    "$C_NGINX"     " Nginx"

row "IDE" \
    "$C_KDEV"      " KDevelop" \
    "$C_KATE"      " Kate"

printf "\n"

row "GitHub Stats" \
    "$C_STATS_GITHUB" " Repos $(get_repos)" \
    "$C_STATS_GITHUB" " Stars $(get_stars)" \
    "$C_STATS_GITHUB" " Forks $(get_forks)"

row "Social" \
    "$C_STATS_SOCIAL" " Followers $(get_followers)" \
    "$C_STATS_SOCIAL" " Following $(get_following)"

print_label "Top Languages"

printed=0
while IFS='|' read -r lang icon percent; do
    [ -z "$lang" ] && continue

    (( printed )) && printf " %b❯%b " "$DIM" "$RESET"

    badge "$C_STATS_LANGS" "$icon $lang ${percent}%"

    printed=1
done <<< "$TOP_LANGS_DATA"

printf "\n"

row "Activity" \
    "$C_STATS_ACTIVITY" " Last push $(get_last_push)"

printf "\n"

palette
