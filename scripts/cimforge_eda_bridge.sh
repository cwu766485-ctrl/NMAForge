#!/usr/bin/env bash
# CIMForge one-command bridge for a user-owned WSL EDA environment.
# Run this inside WSL as the EDA user; Windows/Codex only writes command files
# under the shared bridge root.  No credentials or tool paths are embedded.
set -u

project_dir="${CIMFORGE_PROJECT_DIR:-$HOME/ic/CIMForge}"
bridge_root="${CIMFORGE_BRIDGE_ROOT:-/mnt/f/cimforge_eda_bridge}"
command_file="$bridge_root/command.sh"
active_file="$bridge_root/command.active"
result_file="$bridge_root/result.log"
status_file="$bridge_root/status.txt"
stop_file="$bridge_root/STOP"

mkdir -p "$bridge_root"
printf 'ready\nproject=%s\npid=%s\n' "$project_dir" "$$" > "$status_file"

while true; do
    if [[ -e "$stop_file" ]]; then
        rm -f "$stop_file"
        printf 'stopped\nproject=%s\npid=%s\n' "$project_dir" "$$" > "$status_file"
        exit 0
    fi

    if [[ -f "$command_file" ]]; then
        mv "$command_file" "$active_file"
        printf 'running\nproject=%s\npid=%s\n' "$project_dir" "$$" > "$status_file"
        (
            cd "$project_dir" || exit 127
            bash "$active_file"
        ) > "$result_file" 2>&1
        rc=$?
        rm -f "$active_file"
        printf 'ready\nproject=%s\nlast_exit=%s\n' "$project_dir" "$rc" > "$status_file"
    fi
    sleep 1
done
