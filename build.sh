#!/bin/sh

if [ "$INSIDE_DOCKER_CONTAINER" != "1" ]; then
    echo "Must be run in docker container"
    exit 1
fi

echo 'Building in docker container'

set -e
mkdir -p /mnt/raspotify
cd /mnt/raspotify

# Install most recent version of rust
curl https://sh.rustup.rs -sSf | sh -s -- -y
export PATH="/root/.cargo/bin/:$PATH"
export CARGO_TARGET_DIR="/build"
export CARGO_HOME="/build/cache"

# Install the gcc wrapper in container into cargo
mkdir -p /.cargo
echo '[target.armv7-unknown-linux-gnueabihf]' > /.cargo/config
echo 'linker = "gcc-wrapper"' >> /.cargo/config
rustup target add armv7-unknown-linux-gnueabihf

# Optimize our build
export RUSTFLAGS="-C target-cpu=cortex-a53 -C target-feature=+v8,+vfp4,+neon,-d16"

# Get the git rev of raspotify for .deb versioning
RASPOTIFY_GIT_VER="$(git describe --tags --always --dirty 2>/dev/null || echo unknown)"

if [ ! -d librespot ]; then
    echo "No directory named librespot exists! Cloning..."
    git clone git://github.com/librespot-org/librespot.git
fi

# Get the git rev of librespot for .deb versioning
cd librespot
LIBRESPOT_GIT_REV="$(git rev-parse --short HEAD 2>/dev/null || echo unknown)"
LIBRESPOT_DEB_VER="$(TZ=UTC git show --quiet --date='format-local:%Y%m%dT%H%M%SZ' --format="%cd.%h" "$LIBRESPOT_GIT_REV" 2>/dev/null || echo "unknown")"

# Build librespot
cargo build --release --target armv7-unknown-linux-gnueabihf --no-default-features --features 'alsa-backend jackaudio-backend'

# Copy librespot to pkg root
cd /mnt/raspotify
mkdir -p raspotify/usr/bin
cp -v /build/armv7-unknown-linux-gnueabihf/release/librespot raspotify/usr/bin

exit 0

# Strip dramatically decreases the size -- Disabled so we get tracebacks
#arm-linux-gnueabihf-strip raspotify/usr/bin/librespot

# Compute final package version + filename for Debian control file
DEB_PKG_VER="${RASPOTIFY_GIT_VER}~librespot.${LIBRESPOT_DEB_VER}"
DEB_PKG_NAME="raspotify_${DEB_PKG_VER}_armhf.deb"
echo "$DEB_PKG_NAME"

jinja2 \
        -D "VERSION=$DEB_PKG_VER" \
        -D "RUST_VERSION=$(rustc -V)" \
        -D "RASPOTIFY_AUTHOR=$RASPOTIFY_AUTHOR" \
    control.debian.tmpl > raspotify/DEBIAN/control

# Copy over copyright files
DOC_DIR="raspotify/usr/share/doc/raspotify"
mkdir -p "$DOC_DIR"
cp -v LICENSE "$DOC_DIR/copyright"
cp -v librespot/LICENSE "$DOC_DIR/librespot.copyright"

# Markdown to plain text for readme
pandoc -f markdown -t plain --columns=80 README.md \
    | sed 's/LICENSE/copyright/' | unidecode -e utf8 > "$DOC_DIR/readme"


# Finally, build debian package
dpkg-deb -b raspotify "$DEB_PKG_NAME"

# Perm fixup. Not needed on macOS, but is on Linux
chown -R "$PERMFIX_UID:$PERMFIX_GID" /mnt/raspotify 2> /dev/null

echo "Package built as $DEB_PKG_NAME"
