#!/usr/bin/env bash
set -euo pipefail

# Public CatWorks releases share a repository with the independent Catpacity app.
repo="${CATWORKS_REPO:-kimyeonsik/catpacity}"
tag="${CATWORKS_TAG:-}"
channel="${CATWORKS_CHANNEL:-preview}"
requested_arch="${CATWORKS_ARCH:-auto}"
destination="${CATWORKS_INSTALL_DIR:-$HOME/Applications}"
download_mode="${CATWORKS_DOWNLOAD_MODE:-public}"
fail() { printf '%s\n' "CatWorks: $*" >&2; exit 1; }

[[ "$(uname -s)" == Darwin ]] || fail 'macOS 전용 설치 스크립트입니다.'
[[ "$(sw_vers -productVersion | cut -d. -f1)" -ge 13 ]] || fail 'macOS 13 이상이 필요합니다.'
[[ "$repo" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || fail 'CATWORKS_REPO는 owner/repository 형식이어야 합니다.'
[[ "$channel" == preview || "$channel" == stable ]] || fail 'CATWORKS_CHANNEL은 preview 또는 stable입니다.'
[[ "$download_mode" == public || "$download_mode" == gh ]] || fail 'CATWORKS_DOWNLOAD_MODE는 public 또는 gh입니다.'
[[ "$destination" == /* ]] || fail '설치 폴더는 절대경로여야 합니다.'
[[ "$requested_arch" == auto || "$requested_arch" == arm64 || "$requested_arch" == x64 || "$requested_arch" == universal ]] || fail '지원 아키텍처: auto, arm64, x64, universal.'
# Only an explicitly selected, separate authenticated repository permits legacy tags.
tag_prefix=catworks-
if [[ "$download_mode" == gh ]]; then
  command -v gh >/dev/null || fail '이 비공개 경로는 GitHub CLI(gh)와 gh auth login이 필요합니다.'
  gh auth status --hostname github.com >/dev/null 2>&1 || fail 'gh auth login 후 저장소에 접근 가능한 계정으로 다시 실행해 주세요.'
  [[ "$repo" == kimyeonsik/catpacity ]] || tag_prefix=''
fi
valid_tag() { [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ && "$1" == "$tag_prefix"* ]]; }
[[ -z "$tag" ]] || valid_tag "$tag" || fail '이 저장소의 CatWorks 릴리스 태그(catworks-*)만 설치할 수 있습니다.'

for location in "$destination" /Applications "$HOME/Applications"; do
  [[ ! -e "$location/CatWorks.app" && ! -L "$location/CatWorks.app" && ! -e "$location/Pixel Office.app" && ! -L "$location/Pixel Office.app" ]] \
    || fail "기존 앱을 덮어쓰지 않았습니다: $location. 업데이트는 기존 앱을 보관한 뒤 다시 설치해 주세요."
done

native_arch=x64
if [[ "$(uname -m)" == arm64 || "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == 1 ]]; then native_arch=arm64; fi
[[ "$requested_arch" == auto || "$requested_arch" == universal || "$requested_arch" == "$native_arch" ]] || fail '현재 Mac과 다른 아키텍처를 선택했습니다.'
temporary="$(mktemp -d "${TMPDIR:-/tmp}/catworks-install.XXXXXX")"
mounted=0
staged=''
cleanup() {
  [[ "$mounted" == 0 ]] || hdiutil detach "$temporary/mount" -quiet >/dev/null 2>&1 || true
  [[ -z "$staged" ]] || rm -rf "$staged"
  rm -rf "$temporary"
}
trap cleanup EXIT
json_value() { plutil -extract "$2" raw -expect "$3" -o - "$1" 2>/dev/null; }
api_json() {
  local endpoint="$1" output="$2"
  if [[ "$download_mode" == gh ]]; then
    gh api "$endpoint" -H 'Accept: application/vnd.github+json' > "$output" || fail 'GitHub 릴리스 정보를 읽지 못했습니다.'
  else
    curl -q --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
      --connect-timeout 20 --max-time 120 --max-filesize 8388608 \
      -H 'Accept: application/vnd.github+json' -H 'X-GitHub-Api-Version: 2022-11-28' \
      "https://api.github.com/$endpoint" -o "$output" || fail 'GitHub 릴리스 정보를 읽지 못했습니다. 네트워크 또는 공개 배포 상태를 확인해 주세요.'
  fi
  [[ "$(wc -c < "$output")" -le 8388608 ]] || fail '릴리스 정보가 허용 크기를 초과했습니다.'
}
release_allowed() {
  local file="$1" candidate draft prerelease
  candidate="$(json_value "$file" tag_name string)" || return 1
  valid_tag "$candidate" || return 1
  draft="$(json_value "$file" draft bool)" || return 1
  prerelease="$(json_value "$file" prerelease bool)" || return 1
  [[ "$draft" == false && ( "$channel" == preview || "$prerelease" == false ) ]]
}
release_json="$temporary/release.json"
if [[ -n "$tag" ]]; then
  api_json "repos/$repo/releases/tags/$tag" "$release_json"
  release_allowed "$release_json" || fail '선택한 릴리스의 태그 또는 배포 채널이 일치하지 않습니다.'
  [[ "$(json_value "$release_json" tag_name string)" == "$tag" ]] || fail '응답의 릴리스 태그가 일치하지 않습니다.'
else
  # Catpacity's latest release is not necessarily a CatWorks release. Scan bounded pages.
  for page in 1 2 3 4 5; do
    api_json "repos/$repo/releases?per_page=100&page=$page" "$temporary/releases-raw.json"
    { printf '{"releases":'; cat "$temporary/releases-raw.json"; printf '}'; } > "$temporary/releases.json"
    count="$(json_value "$temporary/releases.json" releases array)" || fail '릴리스 목록 형식이 올바르지 않습니다.'
    [[ "$count" -le 100 ]] || fail '릴리스 목록 크기가 올바르지 않습니다.'
    for ((index=0; index<count; index++)); do
      plutil -extract "releases.$index" json -o "$release_json" "$temporary/releases.json" 2>/dev/null || fail '릴리스 목록 항목이 올바르지 않습니다.'
      if release_allowed "$release_json"; then
        tag="$(json_value "$release_json" tag_name string)"
        break
      fi
    done
    [[ -z "$tag" && "$count" -eq 100 ]] || break
  done
fi
[[ -n "$tag" ]] || fail '설치 가능한 CatWorks 릴리스(catworks-*)를 찾지 못했습니다.'
[[ "$(json_value "$release_json" html_url string)" == "https://github.com/$repo/releases/tag/$tag" ]] || fail '릴리스 저장소 정보가 일치하지 않습니다.'
asset_count="$(json_value "$release_json" assets array)" || fail '릴리스 파일 목록이 올바르지 않습니다.'
[[ "$asset_count" -le 100 ]] || fail '릴리스 파일 수가 허용 범위를 초과했습니다.'
choose_asset() {
  local arch="$1" index item chosen='' count=0
  for ((index=0; index<asset_count; index++)); do
    item="$(json_value "$release_json" "assets.$index.name" string)" || continue
    if [[ "$item" =~ ^CatWorks-[0-9]+\.[0-9]+\.[0-9]+-(arm64|x64|universal)(-preview)?\.dmg$ ]]; then
      case "$item" in
        *"-$arch-preview.dmg") [[ "$channel" == preview ]] || continue ;;
        *"-$arch.dmg") ;;
        *) continue ;;
      esac
      chosen="$item"; count=$((count+1))
    fi
  done
  [[ "$count" -le 1 ]] || { printf '%s\n' 'CatWorks: 같은 아키텍처의 DMG가 여러 개여서 선택할 수 없습니다.' >&2; return 2; }
  [[ "$count" == 1 ]] || return 1
  printf '%s' "$chosen"
}
if [[ "$requested_arch" == auto ]]; then
  if asset="$(choose_asset universal)"; then :
  else
    choice_status=$?
    [[ "$choice_status" == 1 ]] || fail '릴리스 DMG 구성이 모호합니다.'
    asset="$(choose_asset "$native_arch")" || fail '이 Mac에 맞는 DMG가 없습니다.'
  fi
else
  asset="$(choose_asset "$requested_arch")" || fail '선택한 아키텍처의 DMG가 없습니다.'
fi
# Check exact names, uploaded state, IDs, lengths, and canonical URLs before any binary download.
asset_metadata() {
  local wanted="$1" limit="$2" index name found='' count=0
  for ((index=0; index<asset_count; index++)); do
    name="$(json_value "$release_json" "assets.$index.name" string)" || continue
    if [[ "$name" == "$wanted" ]]; then found="$index"; count=$((count+1)); fi
  done
  [[ "$count" == 1 ]] || fail "릴리스 파일이 없거나 중복되었습니다: $wanted"
  metadata_id="$(json_value "$release_json" "assets.$found.id" integer)" || fail '릴리스 파일 ID가 올바르지 않습니다.'
  metadata_size="$(json_value "$release_json" "assets.$found.size" integer)" || fail '릴리스 파일 크기가 올바르지 않습니다.'
  [[ "$metadata_id" =~ ^[1-9][0-9]*$ && "$metadata_size" -gt 0 && "$metadata_size" -le "$limit" ]] || fail '릴리스 파일 ID 또는 크기가 허용 범위를 벗어났습니다.'
  [[ "$(json_value "$release_json" "assets.$found.state" string)" == uploaded ]] || fail '릴리스 파일 업로드가 완료되지 않았습니다.'
  metadata_url="$(json_value "$release_json" "assets.$found.browser_download_url" string)" || fail '릴리스 파일 주소를 확인하지 못했습니다.'
  [[ "$metadata_url" == "https://github.com/$repo/releases/download/$tag/$wanted" ]] || fail '릴리스 파일 주소가 저장소·태그·파일명과 일치하지 않습니다.'
}
asset_metadata "$asset" 2147483648
dmg_id="$metadata_id"; dmg_size="$metadata_size"; dmg_url="$metadata_url"
asset_metadata "$asset.sha256" 512
checksum_id="$metadata_id"; checksum_size="$metadata_size"; checksum_url="$metadata_url"
download_asset() {
  local id="$1" url="$2" size="$3" output="$4"
  if [[ "$download_mode" == gh ]]; then
    gh api "repos/$repo/releases/assets/$id" -H 'Accept: application/octet-stream' > "$output" || fail '릴리스 파일을 다운로드하지 못했습니다.'
  else
    curl -q --fail --silent --show-error --location --proto '=https' --proto-redir '=https' \
      --connect-timeout 20 --max-time 1200 --max-filesize "$size" "$url" -o "$output" || fail '릴리스 파일을 다운로드하지 못했습니다.'
  fi
  [[ "$(wc -c < "$output")" -eq "$size" ]] || fail '다운로드 파일 크기가 릴리스 정보와 일치하지 않습니다.'
}
printf '%s\n' "CatWorks $tag 다운로드: $asset"
download_asset "$checksum_id" "$checksum_url" "$checksum_size" "$temporary/$asset.sha256"
download_asset "$dmg_id" "$dmg_url" "$dmg_size" "$temporary/$asset"
# Exactly one conventional sha256sum line; extra data must not be silently ignored.
[[ "$(awk 'END {print NR}' "$temporary/$asset.sha256")" == 1 ]] || fail '체크섬 파일 형식이 올바르지 않습니다.'
IFS=' ' read -r expected checksum_name < "$temporary/$asset.sha256" || fail '체크섬 파일 형식이 올바르지 않습니다.'
[[ "$expected" =~ ^[0-9a-f]{64}$ && "$checksum_name" == "$asset" ]] || fail '체크섬 파일 형식이 올바르지 않습니다.'
[[ "$(shasum -a 256 "$temporary/$asset" | cut -d' ' -f1)" == "$expected" ]] || fail '다운로드 체크섬이 일치하지 않습니다.'
mkdir "$temporary/mount"
hdiutil attach "$temporary/$asset" -readonly -nobrowse -mountpoint "$temporary/mount" -quiet
mounted=1
source_app="$temporary/mount/CatWorks.app"
[[ -d "$source_app" && ! -L "$source_app" ]] || fail 'DMG에서 CatWorks.app을 찾지 못했습니다.'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$source_app/Contents/Info.plist")" == io.pixeloffice.desktop ]] || fail '앱 식별자가 일치하지 않습니다.'
binary_archs="$(lipo -archs "$source_app/Contents/MacOS/CatWorks")" || fail '앱의 실행 아키텍처를 확인하지 못했습니다.'
native_slice=arm64
[[ "$native_arch" != x64 ]] || native_slice=x86_64
[[ " $binary_archs " == *" $native_slice "* ]] || fail '앱에 현재 Mac용 실행 코드가 없습니다.'
if [[ "$asset" == *-universal.dmg || "$asset" == *-universal-preview.dmg ]]; then
  [[ " $binary_archs " == *' arm64 '* && " $binary_archs " == *' x86_64 '* ]] || fail 'Universal 앱에 두 아키텍처가 모두 포함되지 않았습니다.'
fi
codesign --verify --deep --strict "$source_app" || fail '앱 서명 무결성을 확인하지 못했습니다.'
if [[ "$channel" == stable ]]; then
  spctl --assess --type execute "$source_app" || fail '서명·공증된 배포판인지 확인하지 못했습니다.'
else
  printf '%s\n' '프리뷰는 개발용 ad-hoc 서명입니다. Apple 공증 배포판이 아니며 macOS 보안 설정을 변경하지 않습니다.'
fi
mkdir -p "$destination"
staged="$(mktemp -d "$destination/.catworks-install.XXXXXX")"
ditto "$source_app" "$staged/CatWorks.app"
[[ ! -e "$destination/CatWorks.app" && ! -L "$destination/CatWorks.app" ]] || fail '설치 중 같은 이름의 앱이 생겼습니다. 기존 앱을 유지했습니다.'
mv -n "$staged/CatWorks.app" "$destination/"
[[ ! -e "$staged/CatWorks.app" ]] || fail '기존 앱을 덮어쓰지 않고 설치를 중단했습니다.'
printf '%s\n' "설치 완료: $destination/CatWorks.app" 'Finder에서 앱을 열어 주세요. 기존 업무 기록과 실행 중인 사무실 서버는 유지됩니다.'
