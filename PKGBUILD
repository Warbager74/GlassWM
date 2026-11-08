pkgname=glasswm
pkgver=1.0.0
pkgrel=1
pkgdesc="Independent modern X11 window manager with liquid glass aesthetics"
arch=('x86_64')
url="https://github.com/local/glasswm"
license=('MIT')
depends=('libxcb' 'picom' 'rofi' 'polybar' 'feh' 'ttf-jetbrains-mono-nerd' 'kitty' 'python' 'xdotool')
makedepends=('rust' 'cargo')
source=()

build() {
  cd "$startdir"
  cargo build --release
}

package() {
  cd "$startdir"
  install -Dm755 "target/release/glasswm" "$pkgdir/usr/bin/glasswm"
  install -Dm644 "glasswm.desktop" "$pkgdir/usr/share/xsessions/glasswm.desktop"
  install -d "$pkgdir/etc/skel/.config/glasswm/rofi"
  install -d "$pkgdir/etc/skel/.config/glasswm/scripts"
  install -d "$pkgdir/etc/skel/.config/glasswm/wallpapers"
  install -Dm644 "dotfiles/config.toml" "$pkgdir/etc/skel/.config/glasswm/config.toml"
  install -Dm644 "dotfiles/picom.conf" "$pkgdir/etc/skel/.config/glasswm/picom.conf"
  install -Dm644 "dotfiles/polybar.ini" "$pkgdir/etc/skel/.config/glasswm/polybar.ini"
  install -Dm644 "dotfiles/rofi/spotlight.rasi" "$pkgdir/etc/skel/.config/glasswm/rofi/spotlight.rasi"
  install -Dm755 "dotfiles/autostart.sh" "$pkgdir/etc/skel/.config/glasswm/autostart.sh"
}
