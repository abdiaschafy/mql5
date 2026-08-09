#!/usr/bin/env bash
set -uo pipefail

project_dir="$(cd "$(dirname "$0")/.." && pwd)"
wine_bin="${MT5_WINE_BIN:-/Applications/MetaTrader 5.app/Contents/SharedSupport/wine/bin/wine}"
wine_prefix="${MT5_WINEPREFIX:-$HOME/Library/Application Support/net.metaquotes.wine.metatrader5}"
metaeditor="${MT5_METAEDITOR:-C:\Program Files\MetaTrader 5\MetaEditor64.exe}"

if [[ ! -x "$wine_bin" ]]; then
  echo "MetaTrader 5 Wine introuvable: $wine_bin" >&2
  exit 1
fi
if [[ ! -d "$wine_prefix" ]]; then
  echo "Prefixe MetaTrader 5 introuvable: $wine_prefix" >&2
  exit 1
fi

stage_dir="$(mktemp -d /private/tmp/ict-sb-mql5.XXXXXX)"
case "$stage_dir" in
  /private/tmp/ict-sb-mql5.*) ;;
  *) echo "Repertoire temporaire inattendu: $stage_dir" >&2; exit 1 ;;
esac

cleanup() {
  rm -rf -- "$stage_dir"
}
trap cleanup EXIT

cp "$project_dir/ICT_SilverBullet_Core.mqh" "$stage_dir/"
cp "$project_dir/ICT_SilverBullet_Strategy.mq5" "$stage_dir/"
cp "$project_dir/ICT_SilverBullet_Signals.mq5" "$stage_dir/"

to_wine_path() {
  printf 'Z:%s' "$1" | sed 's|/|\\|g'
}

compile_source() {
  local filename="$1"
  local source_path="$stage_dir/$filename"
  local log_path="$stage_dir/${filename%.mq5}.log"
  local utf8_log="$log_path.utf8"
  local wine_source
  local wine_log
  wine_source="$(to_wine_path "$source_path")"
  wine_log="$(to_wine_path "$log_path")"

  env WINEPREFIX="$wine_prefix" WINEDEBUG=-all \
    "$wine_bin" "$metaeditor" \
    "/compile:$wine_source" "/log:$wine_log" >/dev/null 2>&1 || true

  if [[ ! -f "$log_path" ]]; then
    echo "$filename: journal MetaEditor absent" >&2
    return 1
  fi
  iconv -f UTF-16LE -t UTF-8 "$log_path" > "$utf8_log"
  if ! grep -q 'Result: 0 errors, 0 warnings' "$utf8_log"; then
    tail -30 "$utf8_log" >&2
    return 1
  fi
  grep 'Result:' "$utf8_log" | tail -1
}

compile_source ICT_SilverBullet_Strategy.mq5 || exit 1
compile_source ICT_SilverBullet_Signals.mq5 || exit 1
