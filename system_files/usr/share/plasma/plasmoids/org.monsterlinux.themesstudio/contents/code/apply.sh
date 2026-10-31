#!/bin/bash
# Monster Themes Studio helper. The Studio calls this to change the desktop.
# Every action prints one line per result: "OK <what>" or "FAIL <what>".
#
#   apply.sh colors <colors-file-text> <accent-hex>
#   apply.sh fonts <family> <size> <bold 0|1> <mono-family> <smooth 0|1> <hinting none|slight|medium|full> <scale 100|112|125|150>
#   apply.sh glass <active%> <inactive%> <taskbar opaque|translucent|adaptive>
#   apply.sh iconset <square|rounded|round|THEME-NAME> <tela-color> <dark 0|1>
#   apply.sh cursor <theme>
#   apply.sh wallpaper <image|live> [path]
#   apply.sh motion <speed-factor> <wobbly 0|1> <lamp 0|1> <blur 0|1>
#   apply.sh appicon <desktop-file> <icon-png>      give one app a custom icon
#   apply.sh appicon-reset <desktop-id>              put the app's own icon back
#   apply.sh apps                                    list apps: id|name|icon|desktop-file
#   apply.sh classic <show|hide>                     show or hide KDE's own appearance pages
#   apply.sh list <cursors|iconthemes|wallpapers>
#   apply.sh mythemes <list|save ID JSON|delete ID>   your own saved themes

set -u
export PATH="$PATH:/usr/libexec:/usr/lib/libexec"
QDBUS=$(command -v qdbus6 || command -v qdbus-qt6 || command -v qdbus || true)
DATA="${XDG_DATA_HOME:-$HOME/.local/share}"
ok()   { echo "OK $*"; }
fail() { echo "FAIL $*"; }
kw()   { kwriteconfig6 "$@"; }
reconfigure_kwin() { [ -n "$QDBUS" ] && $QDBUS org.kde.KWin /KWin reconfigure >/dev/null 2>&1; }
plasma_js() { [ -n "$QDBUS" ] && $QDBUS org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$1" >/dev/null 2>&1; }

# KDE's own appearance pages that the Studio replaces
CLASSIC="kcm_wallpaper kcm_colors kcm_lookandfeel kcm_desktoptheme kcm_kwindecoration kcm_icons kcm_cursortheme kcm_splashscreen kcm_sddm kcm_style kcm_fonts kcm_fontinst kcm_animations"

act="${1:-}"; shift || true
case "$act" in
colors)
    mkdir -p "$DATA/color-schemes"
    printf '%s\n' "$1" > "$DATA/color-schemes/MonsterCustom.colors"
    # switch away first so KDE reloads the file even if it was already active
    plasma-apply-colorscheme BreezeDark >/dev/null 2>&1
    plasma-apply-colorscheme MonsterCustom >/dev/null 2>&1 && ok "Colors" || fail "Colors"
    plasma-apply-colorscheme --accent-color "$2" >/dev/null 2>&1 && ok "Accent color"
    plasma-apply-desktoptheme default >/dev/null 2>&1   # taskbar follows the colors
    ;;
fonts)
    fam="$1"; size="$2"; bold="$3"; mono="$4"; smooth="$5"; hint="$6"; scale="$7"
    f() { echo "$1,$2,-1,5,$3,0,0,0,0,0,0,0,0,0,0,1"; }
    kw --file kdeglobals --group General --key font        "$(f "$fam" "$size" 400)"
    kw --file kdeglobals --group General --key menuFont    "$(f "$fam" "$size" 400)"
    kw --file kdeglobals --group General --key toolBarFont "$(f "$fam" $((size>8?size-1:size)) 400)"
    kw --file kdeglobals --group General --key smallestReadableFont "$(f "$fam" $((size>9?size-2:8)) 400)"
    kw --file kdeglobals --group WM      --key activeFont  "$(f "$fam" "$size" $([ "$bold" = 1 ] && echo 700 || echo 400))"
    kw --file kdeglobals --group General --key fixed       "$(f "$mono" "$size" 400)"
    ok "Letters: $fam $size pt, terminal $mono"
    kw --file kdeglobals --group General --key XftAntialias "$([ "$smooth" = 1 ] && echo true || echo false)"
    case "$hint" in none) hs=hintnone;; medium) hs=hintmedium;; full) hs=hintfull;; *) hs=hintslight;; esac
    kw --file kdeglobals --group General --key XftHintStyle "$hs"
    kw --file kdeglobals --group General --key XftSubPixel rgb
    ok "Smooth letters: $([ "$smooth" = 1 ] && echo on || echo off), hinting $hint"
    dpi=$(( 96 * scale / 100 ))
    if [ "$scale" = 100 ]; then kw --file kcmfonts --group General --key forceFontDPI 0
    else kw --file kcmfonts --group General --key forceFontDPI "$dpi"; fi
    ok "Text scale $scale% (fully shows after logging out and in)"
    ;;
glass)
    G=monster-glass
    RULES=$(kreadconfig6 --file kwinrulesrc --group General --key rules)
    case ",$RULES," in *",$G,"*) ;; *)
        COUNT=$(kreadconfig6 --file kwinrulesrc --group General --key count); COUNT=${COUNT:-0}
        kw --file kwinrulesrc --group General --key count $((COUNT+1))
        kw --file kwinrulesrc --group General --key rules "${RULES:+$RULES,}$G" ;;
    esac
    kw --file kwinrulesrc --group $G --key Description "Monster Linux see-through windows"
    kw --file kwinrulesrc --group $G --key wmclass '^(?!steam_app|steam|gamescope|xwaylandvideobridge|plasmawindowed|.*plasmawindowed|io\.github\.ublue_os\.yafti_gtk|.*yafti.*|org\.monsterlinux\..*|org\.kde\.konsole|konsole|.*\.exe).*'
    kw --file kwinrulesrc --group $G --key wmclassmatch 3
    kw --file kwinrulesrc --group $G --key types 33
    kw --file kwinrulesrc --group $G --key opacityactive "$1"
    kw --file kwinrulesrc --group $G --key opacityactiverule 2
    kw --file kwinrulesrc --group $G --key opacityinactive "$2"
    kw --file kwinrulesrc --group $G --key opacityinactiverule 2
    reconfigure_kwin && ok "See-through windows: $1% / $2% (games stay solid)"
    case "$3" in opaque) m=1;; translucent) m=2;; *) m=0;; esac
    plasma_js "panels().forEach(function(p){ p.currentConfigGroup=['General']; try { p.opacity = $m; } catch(e) {} ; p.writeConfig('panelOpacity', $m); p.reloadConfig(); });" \
        && ok "Taskbar: $3"
    ;;
iconset)
    shape="$1"; col="$2"; dark="$3"
    case "$shape" in
        square)  theme=$([ "$dark" = 1 ] && echo breeze-dark || echo breeze) ;;
        rounded) repo=Tela-icon-theme;        theme="Tela-$col$([ "$dark" = 1 ] && echo -dark)" ;;
        round)   repo=Tela-circle-icon-theme; theme="Tela-circle-$col$([ "$dark" = 1 ] && echo -dark)" ;;
        *)       theme="$shape" ;;
    esac
    if [ -n "${repo:-}" ] && [ ! -d "$DATA/icons/$theme" ]; then
        tmp=$(mktemp -d)
        if git clone -q --depth 1 "https://github.com/vinceliuice/$repo.git" "$tmp/$repo" >/dev/null 2>&1 \
           && (cd "$tmp/$repo" && ./install.sh "$col" >/dev/null 2>&1); then ok "Downloaded the $shape icon set"
        else fail "Couldn't download the $shape icon set. Check the internet and try again"; rm -rf "$tmp"; exit 0; fi
        rm -rf "$tmp"
    fi
    if plasma-changeicons "$theme" >/dev/null 2>&1; then
        ok "Icons: $theme"
        # keep the little-monster power buttons on top of the new icon set
        [ -x /usr/libexec/monster-power-icons ] && /usr/libexec/monster-power-icons "$theme" && ok "Monster power buttons kept"
    else fail "Icons: $theme"; fi
    ;;
cursor)
    plasma-apply-cursortheme "$1" >/dev/null 2>&1 && ok "Mouse pointer: $1" || fail "Mouse pointer: $1"
    ;;
wallpaper)
    if [ "$1" = live ]; then
        plasma_js "desktops().forEach(function(d){ d.wallpaperPlugin='org.monsterlinux.gloop.live'; });" \
            && ok "Wallpaper: Gloop with the moving eye" || fail "Moving wallpaper isn't installed (install the Monster Gloop theme)"
    else
        mkdir -p "$DATA/wallpapers/monster-studio"
        dest="$DATA/wallpapers/monster-studio/$(basename "$2")"
        cp -f "$2" "$dest" 2>/dev/null || dest="$2"
        plasma-apply-wallpaperimage "$dest" >/dev/null 2>&1 && ok "Wallpaper" || fail "Wallpaper"
        kw --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General --key Image "file://$dest"
        ok "Lock screen uses the same picture"
    fi
    ;;
motion)
    kw --file kdeglobals --group KDE --key AnimationDurationFactor "$1"
    kw --file kwinrc --group Plugins --key wobblywindowsEnabled "$([ "$2" = 1 ] && echo true || echo false)"
    kw --file kwinrc --group Plugins --key magiclampEnabled "$([ "$3" = 1 ] && echo true || echo false)"
    [ "$3" = 1 ] && kw --file kwinrc --group Plugins --key squashEnabled false
    kw --file kwinrc --group Plugins --key blurEnabled "$([ "$4" = 1 ] && echo true || echo false)"
    reconfigure_kwin
    ok "Motion: speed x$1, wobbly $([ "$2" = 1 ] && echo on || echo off), magic lamp $([ "$3" = 1 ] && echo on || echo off), blur $([ "$4" = 1 ] && echo on || echo off)"
    ;;
apps)
    for dir in "$DATA/applications" /var/lib/flatpak/exports/share/applications "$DATA/flatpak/exports/share/applications" /usr/share/applications; do
        [ -d "$dir" ] || continue
        for f in "$dir"/*.desktop; do
            [ -f "$f" ] || continue
            grep -qiE '^(NoDisplay|Hidden)=true' "$f" && continue
            grep -q '^Type=Application' "$f" || continue
            name=$(grep -m1 '^Name=' "$f" | cut -d= -f2-); icon=$(grep -m1 '^Icon=' "$f" | cut -d= -f2-)
            echo "$(basename "$f")|$name|$icon|$f"
        done
    done | awk -F'|' '!seen[$1]++' | sort -t'|' -k2,2f
    ;;
appicon)
    src="$1"; png="$2"; id=$(basename "$src")
    mkdir -p "$DATA/applications"
    [ "$(realpath -m "$src")" = "$(realpath -m "$DATA/applications/$id")" ] || cp -f "$src" "$DATA/applications/$id"
    grep -q '^X-Monster-OriginalIcon=' "$DATA/applications/$id" || \
        sed -i "0,/^Icon=/{s|^Icon=\(.*\)|Icon=\1\nX-Monster-OriginalIcon=\1|}" "$DATA/applications/$id"
    sed -i "0,/^Icon=/{s|^Icon=.*|Icon=$png|}" "$DATA/applications/$id"
    kbuildsycoca6 >/dev/null 2>&1
    ok "New icon for $(grep -m1 '^Name=' "$DATA/applications/$id" | cut -d= -f2-)"
    ;;
appicon-reset)
    f="$DATA/applications/$1"
    if [ -f "$f" ] && grep -q '^X-Monster-OriginalIcon=' "$f"; then
        orig=$(grep -m1 '^X-Monster-OriginalIcon=' "$f" | cut -d= -f2-)
        sed -i "0,/^Icon=/{s|^Icon=.*|Icon=$orig|}; /^X-Monster-OriginalIcon=/d" "$f"
        kbuildsycoca6 >/dev/null 2>&1; ok "Original icon restored"
    else ok "This app already has its original icon"; fi
    ;;
classic)
    for m in $CLASSIC; do
        if [ "$1" = show ]; then kw --file kdeglobals --group "KDE Control Module Restrictions" --key "$m" --delete
        else kw --file kdeglobals --group "KDE Control Module Restrictions" --key "$m" false; fi
    done
    [ "$1" = show ] && ok "KDE's own appearance pages are back in System Settings" || ok "Only Monster Themes Studio is shown in Appearance & Style"
    ;;
list)
    case "$1" in
        cursors)    for d in /usr/share/icons/* "$DATA"/icons/* "$HOME"/.icons/*; do [ -d "$d/cursors" ] && basename "$d"; done | sort -u ;;
        iconthemes) for d in /usr/share/icons/* "$DATA"/icons/*; do case "$(basename "$d")" in Monster-Wrap|Monster-Login) continue;; esac; [ -f "$d/index.theme" ] && grep -q '^Directories=' "$d/index.theme" && basename "$d"; done | sort -u ;;
        wallpapers) for d in /usr/share/wallpapers/* "$DATA"/wallpapers/*; do
                        if [ -d "$d/contents/images" ]; then ls -S "$d"/contents/images/* 2>/dev/null | head -n1
                        elif [ -f "$d" ]; then echo "$d"; fi
                    done ;;
    esac
    ;;
mythemes)
    D="$DATA/monster-themes"; mkdir -p "$D"
    case "${1:-list}" in
        list)   for f in "$D"/*.json; do [ -f "$f" ] && { tr -d '\n' < "$f"; echo; }; done ;;
        save)   id=$(printf '%s' "$2" | tr -cd 'a-z0-9-'); [ -n "$id" ] || { fail "Theme name"; exit 0; }
                printf '%s\n' "$3" > "$D/$id.json" && ok "Saved" || fail "Couldn't save the theme" ;;
        delete) id=$(printf '%s' "$2" | tr -cd 'a-z0-9-'); rm -f "$D/$id.json"; ok "Deleted" ;;
    esac
    ;;
*) echo "usage: see the top of this file" ;;
esac
exit 0
