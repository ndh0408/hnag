#!/usr/bin/env bash
set -euo pipefail

pattern=${1:-minecraft}

if ! command -v docker > /dev/null 2>&1; then
  echo "Docker chưa cài đặt hoặc không thể truy cập." >&2
  exit 1
fi

matches=$(docker ps --format '{{.Names}}|{{.Image}}' | grep -Ei "$pattern|minecraft|paper|spigot|bukkit|fabric|forge" || true)
if [[ -z "$matches" ]]; then
  echo "Không tìm thấy container Docker liên quan tới Minecraft." >&2
  echo "Containers đang chạy:" >&2
  docker ps --format '  {{.Names}} {{.Image}}'
  exit 1
fi

echo "Đã tìm các container sau:"
printf '%s\n' "$matches" | sed 's/|/ -> /g'

read -rp 'Dừng và xóa các container này? [y/N] ' confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo 'Đã hủy.'
  exit 0
fi

printf '%s\n' "$matches" | cut -d'|' -f1 | while IFS= read -r name; do
  echo "Stopping $name..."
  docker stop "$name"
  echo "Removing $name..."
  docker rm "$name"
done

echo 'Đã tắt Minecraft container(s).'
