#!/bin/sh
printf '\033c\033]0;%s\a' LeftAliened
base_path="$(dirname "$(realpath "$0")")"
"$base_path/LeftAliened.x86_64" "$@"
