#!/bin/bash

set -e

merge_binaries() {
  X86DIR=$1
  ARMDIR=$2
  echo "Merging ARM64 binaries from $ARMDIR into fat binaries at $X86DIR..."

  IFS="
"
  pushd "$X86DIR"
  for X86BIN in $(find . -type f \( -name '*.dylib' -o -name '*.a' -o -perm +111 \)); do
    if file "$X86DIR/$X86BIN" | grep "Mach-O " >/dev/null; then
      ARMBIN="${ARMDIR}/${X86BIN}"
      echo "Merge $ARMBIN to $X86BIN..."
      lipo -create "$X86BIN" "$ARMBIN" -o "$X86BIN"
    fi
  done
  popd
}

if [ "$#" -ne 1 ]; then
    echo "Syntax: $0 <output directory>"
    exit 1
fi

export MACOSX_DEPLOYMENT_TARGET=11.0

NPROCS="$(getconf _NPROCESSORS_ONLN)"
SCRIPTDIR=$(realpath $(dirname "${BASH_SOURCE[0]}"))
INSTALLDIR="$1"
if [ "${INSTALLDIR:0:1}" != "/" ]; then
	INSTALLDIR="$PWD/$INSTALLDIR"
fi

FREETYPE=2.13.2
HARFBUZZ=8.3.1
SDL2=2.30.5
ZSTD=1.5.6
LIBPNG=1.6.43
LIBJPEG=9f
LIBWEBP=1.4.0
MOLTENVK=1.2.9
QT=6.7.2

SHADERC=2024.1
SHADERC_GLSLANG=142052fa30f9eca191aa9dcf65359fcaed09eeec
SHADERC_SPIRVHEADERS=5e3ad389ee56fca27c9705d093ae5387ce404df4
SHADERC_SPIRVTOOLS=dd4b663e13c07fea4fbb3f70c1c91c86731099f7
SPIRV_CROSS=vulkan-sdk-1.3.283.0
CPUINFO=05332fd802d9109a2a151ec32154b107c1e5caf9
DISCORD_RPC=842c15192041f8e71c512851834f4dadb1a554fb

mkdir -p deps-build
cd deps-build

export PKG_CONFIG_PATH="$INSTALLDIR/lib/pkgconfig:$PKG_CONFIG_PATH"
export LDFLAGS="-L$INSTALLDIR/lib $LDFLAGS"
export CFLAGS="-I$INSTALLDIR/include $CFLAGS"
export CXXFLAGS="-I$INSTALLDIR/include $CXXFLAGS"
CMAKE_COMMON=(
	-DCMAKE_BUILD_TYPE=Release
	-DCMAKE_SHARED_LINKER_FLAGS="-dead_strip -dead_strip_dylibs"
	-DCMAKE_PREFIX_PATH="$INSTALLDIR"
	-DCMAKE_INSTALL_PREFIX="$INSTALLDIR"
	-DCMAKE_INSTALL_NAME_DIR='$<INSTALL_PREFIX>/lib'
)
CMAKE_ARCH_X64=-DCMAKE_OSX_ARCHITECTURES="x86_64"
CMAKE_ARCH_ARM64=-DCMAKE_OSX_ARCHITECTURES="arm64"
CMAKE_ARCH_UNIVERSAL=-DCMAKE_OSX_ARCHITECTURES="x86_64;arm64"

cat > SHASUMS <<EOF
12991c4e55c506dd7f9b765933e62fd2be2e06d421505d7950a132e4f1bb484d  freetype-$FREETYPE.tar.xz
19a54fe9596f7a47c502549fce8e8a10978c697203774008cc173f8360b19a9a  harfbuzz-$HARFBUZZ.tar.gz
f374f3fa29c37dfcc20822d4a7d7dc57e58924d1a5f2ad511bfab4c8193de63b  SDL2-$SDL2.tar.gz
8c29e06cf42aacc1eafc4077ae2ec6c6fcb96a626157e0593d5e82a34fd403c1  zstd-$ZSTD.tar.gz
6a5ca0652392a2d7c9db2ae5b40210843c0bbc081cbd410825ab00cc59f14a6c  libpng-$LIBPNG.tar.xz
61f873ec69e3be1b99535634340d5bde750b2e4447caa1db9f61be3fd49ab1e5  libwebp-$LIBWEBP.tar.gz
04705c110cb2469caa79fb71fba3d7bf834914706e9641a4589485c1f832565b  jpegsrc.v$LIBJPEG.tar.gz
f415a09385030c6510a936155ce211f617c31506db5fbc563e804345f1ecf56e  v$MOLTENVK.tar.gz
c5f22a5e10fb162895ded7de0963328e7307611c688487b5d152c9ee64767599  qtbase-everywhere-src-$QT.tar.xz
e1a1d8785fae67d16ad0a443b01d5f32663a6b68d275f1806ebab257485ce5d6  qtimageformats-everywhere-src-$QT.tar.xz
fb0d1286a35be3583fee34aeb5843c94719e07193bdf1d4d8b0dc14009caef01  qtsvg-everywhere-src-$QT.tar.xz
58e855ad1b2533094726c8a425766b63a04a0eede2ed85086860e54593aa4b2a  qttools-everywhere-src-$QT.tar.xz
9845780b5dc1b7279d57836db51aeaf2e4a1160c42be09750616f39157582ca9  qttranslations-everywhere-src-$QT.tar.xz
eb3b5f0c16313d34f208d90c2fa1e588a23283eed63b101edd5422be6165d528  shaderc-$SHADERC.tar.gz
aa27e4454ce631c5a17924ce0624eac736da19fc6f5a2ab15a6c58da7b36950f  shaderc-glslang-$SHADERC_GLSLANG.tar.gz
5d866ce34a4b6908e262e5ebfffc0a5e11dd411640b5f24c85a80ad44c0d4697  shaderc-spirv-headers-$SHADERC_SPIRVHEADERS.tar.gz
03ee1a2c06f3b61008478f4abe9423454e53e580b9488b47c8071547c6a9db47  shaderc-spirv-tools-$SHADERC_SPIRVTOOLS.tar.gz
3376a58abe186a695a50ff12697d210ce27673cea5de1a5090cb2b092b261414  SPIRV-Cross-$SPIRV_CROSS.tar.gz
74a8d9ae0b8b45b39d35708c873320de227bbfe01a46e4d2a91818b8877f4137  cpuinfo-$CPUINFO.tar.gz
acb111ebdb4f1459899b9c594be81ed284de23ac0f5376e5963aad16df98584f  discord-rpc-$DISCORD_RPC.tar.gz

EOF

curl -L \
	-o "freetype-$FREETYPE.tar.xz" "https://sourceforge.net/projects/freetype/files/freetype2/$FREETYPE/freetype-$FREETYPE.tar.xz/download" \
	-o "harfbuzz-$HARFBUZZ.tar.gz" "https://github.com/harfbuzz/harfbuzz/archive/refs/tags/$HARFBUZZ.tar.gz" \
	-O "https://github.com/libsdl-org/SDL/releases/download/release-$SDL2/SDL2-$SDL2.tar.gz" \
	-O "https://github.com/facebook/zstd/releases/download/v$ZSTD/zstd-$ZSTD.tar.gz" \
	-O "https://downloads.sourceforge.net/project/libpng/libpng16/$LIBPNG/libpng-$LIBPNG.tar.xz" \
	-O "https://ijg.org/files/jpegsrc.v$LIBJPEG.tar.gz" \
	-O "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-$LIBWEBP.tar.gz" \
	-O "https://github.com/KhronosGroup/MoltenVK/archive/refs/tags/v$MOLTENVK.tar.gz" \
	-O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtbase-everywhere-src-$QT.tar.xz" \
	-O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtimageformats-everywhere-src-$QT.tar.xz" \
	-O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qtsvg-everywhere-src-$QT.tar.xz" \
	-O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qttools-everywhere-src-$QT.tar.xz" \
	-O "https://download.qt.io/official_releases/qt/${QT%.*}/$QT/submodules/qttranslations-everywhere-src-$QT.tar.xz" \
	-o "shaderc-$SHADERC.tar.gz" "https://github.com/google/shaderc/archive/refs/tags/v$SHADERC.tar.gz" \
	-o "shaderc-glslang-$SHADERC_GLSLANG.tar.gz" "https://github.com/KhronosGroup/glslang/archive/$SHADERC_GLSLANG.tar.gz" \
	-o "shaderc-spirv-headers-$SHADERC_SPIRVHEADERS.tar.gz" "https://github.com/KhronosGroup/SPIRV-Headers/archive/$SHADERC_SPIRVHEADERS.tar.gz" \
	-o "shaderc-spirv-tools-$SHADERC_SPIRVTOOLS.tar.gz" "https://github.com/KhronosGroup/SPIRV-Tools/archive/$SHADERC_SPIRVTOOLS.tar.gz" \
	-o "SPIRV-Cross-$SPIRV_CROSS.tar.gz" "https://github.com/KhronosGroup/SPIRV-Cross/archive/refs/tags/$SPIRV_CROSS.tar.gz" \
	-o "cpuinfo-$CPUINFO.tar.gz" "https://github.com/pytorch/cpuinfo/archive/$CPUINFO.tar.gz" \
	-o "discord-rpc-$DISCORD_RPC.tar.gz" "https://github.com/stenzek/discord-rpc/archive/$DISCORD_RPC.tar.gz"

shasum -a 256 --check SHASUMS

echo "Installing SDL2..."
rm -fr "SDL2-$SDL2"
tar xf "SDL2-$SDL2.tar.gz"
cd "SDL2-$SDL2"
cmake -B build "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DSDL_X11=OFF -DBUILD_SHARED_LIBS=ON
make -C build "-j$NPROCS"
make -C build install
cd ..

echo "Installing Zstd..."
rm -fr "zstd-$ZSTD"
tar xf "zstd-$ZSTD.tar.gz"
cd "zstd-$ZSTD"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" -DBUILD_SHARED_LIBS=ON -DZSTD_BUILD_PROGRAMS=OFF -B build-dir build/cmake
make -C build-dir "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" -DBUILD_SHARED_LIBS=ON -DZSTD_BUILD_PROGRAMS=OFF -B build-dir-arm64 build/cmake
make -C build-dir-arm64 "-j$NPROCS"
merge_binaries $(realpath build-dir) $(realpath build-dir-arm64)
make -C build-dir install
cd ..

echo "Installing libpng..."
rm -fr "libpng-$LIBPNG"
tar xf "libpng-$LIBPNG.tar.xz"
cd "libpng-$LIBPNG"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" -DBUILD_SHARED_LIBS=ON -DPNG_TESTS=OFF -DPNG_FRAMEWORK=OFF -B build
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" -DBUILD_SHARED_LIBS=ON -DPNG_TESTS=OFF -DPNG_ARM_NEON=on -DPNG_FRAMEWORK=OFF -B build-arm64
make -C build-arm64 "-j$NPROCS"
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..

echo "Building libjpeg..."
rm -fr "jpeg-$LIBJPEG"
tar xf "jpegsrc.v$LIBJPEG.tar.gz"
cd "jpeg-$LIBJPEG"
mkdir build
cd build
../configure --prefix="$INSTALLDIR" --disable-static --enable-shared --host="x86_64-apple-darwin" CFLAGS="-arch x86_64"
make "-j$NPROCS"
cd ..
mkdir build-arm64
cd build-arm64
../configure --prefix="$INSTALLDIR" --disable-static --enable-shared --host="aarch64-apple-darwin" CFLAGS="-arch arm64"
make "-j$NPROCS"
cd ..
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..

echo "Building FreeType without HarfBuzz..."
rm -fr "freetype-$FREETYPE"
tar xf "freetype-$FREETYPE.tar.xz"
cd "freetype-$FREETYPE"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DFT_REQUIRE_ZLIB=ON -DFT_REQUIRE_PNG=ON -DFT_DISABLE_BZIP2=TRUE -DFT_DISABLE_BROTLI=TRUE -DFT_DISABLE_HARFBUZZ=TRUE -B build
cmake --build build --parallel
cmake --install build
cd ..

echo "Building HarfBuzz..."
rm -fr "harfbuzz-$HARFBUZZ"
tar xf "harfbuzz-$HARFBUZZ.tar.gz"
cd "harfbuzz-$HARFBUZZ"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DHB_BUILD_UTILS=OFF -B build
cmake --build build --parallel
cmake --install build
cd ..

echo "Building FreeType with HarfBuzz..."
rm -fr "freetype-$FREETYPE"
tar xf "freetype-$FREETYPE.tar.xz"
cd "freetype-$FREETYPE"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -DFT_REQUIRE_ZLIB=ON -DFT_REQUIRE_PNG=ON -DFT_DISABLE_BZIP2=TRUE -DFT_DISABLE_BROTLI=TRUE -DFT_REQUIRE_HARFBUZZ=TRUE -B build
cmake --build build --parallel
cmake --install build
cd ..

echo "Installing WebP..."
rm -fr "libwebp-$LIBWEBP"
tar xf "libwebp-$LIBWEBP.tar.gz"
cd "libwebp-$LIBWEBP"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" -B build \
	-DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF \
	-DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF -DBUILD_SHARED_LIBS=ON
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" -B build-arm64 \
	-DWEBP_BUILD_ANIM_UTILS=OFF -DWEBP_BUILD_CWEBP=OFF -DWEBP_BUILD_DWEBP=OFF -DWEBP_BUILD_GIF2WEBP=OFF -DWEBP_BUILD_IMG2WEBP=OFF \
	-DWEBP_BUILD_VWEBP=OFF -DWEBP_BUILD_WEBPINFO=OFF -DWEBP_BUILD_WEBPMUX=OFF -DWEBP_BUILD_EXTRAS=OFF -DBUILD_SHARED_LIBS=ON
make -C build-arm64 "-j$NPROCS"
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..

# MoltenVK already builds universal binaries, nothing special to do here.
echo "Installing MoltenVK..."
rm -fr "MoltenVK-${MOLTENVK}"
tar xf "v$MOLTENVK.tar.gz"
cd "MoltenVK-${MOLTENVK}"
./fetchDependencies --macos
make macos
cp Package/Latest/MoltenVK/dynamic/dylib/macOS/libMoltenVK.dylib "$INSTALLDIR/lib/"
cd ..

echo "Installing Qt Base..."
rm -fr "qtbase-everywhere-src-$QT"
tar xf "qtbase-everywhere-src-$QT.tar.xz"
cd "qtbase-everywhere-src-$QT"
# since we don't have a direct reference to QtSvg, it doesn't deployed directly from the main binary
# (only indirectly from iconengines), and the libqsvg.dylib imageformat plugin does not get deployed.
# We could run macdeployqt twice, but that's even more janky than patching it.
patch -u src/tools/macdeployqt/shared/shared.cpp <<EOF
--- shared.cpp
+++ shared.cpp
@@ -1119,14 +1119,8 @@
         addPlugins(QStringLiteral("networkinformation"));
     }
 
-    // All image formats (svg if QtSvg is used)
-    const bool usesSvg = deploymentInfo.containsModule("Svg", libInfix);
-    addPlugins(QStringLiteral("imageformats"), [usesSvg](const QString &lib) {
-        if (lib.contains(QStringLiteral("qsvg")) && !usesSvg)
-            return false;
-        return true;
-    });
-
+    // All image formats
+    addPlugins(QStringLiteral("imageformats"));
     addPlugins(QStringLiteral("iconengines"));
 
     // Platforminputcontext plugins if QtGui is in use
EOF
cmake -B build "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DFEATURE_dbus=OFF -DFEATURE_framework=OFF -DFEATURE_icu=OFF -DFEATURE_opengl=OFF -DFEATURE_sql=OFF -DFEATURE_gssapi=OFF -DFEATURE_system_png=ON -DFEATURE_system_jpeg=ON -DFEATURE_system_zlib=ON -DFEATURE_system_freetype=ON -DFEATURE_system_harfbuzz=ON
make -C build "-j$NPROCS"
make -C build install
cd ..

echo "Installing Qt SVG..."
rm -fr "qtsvg-everywhere-src-$QT"
tar xf "qtsvg-everywhere-src-$QT.tar.xz"
cd "qtsvg-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL"
make "-j$NPROCS"
make install
cd ../..

echo "Installing Qt Image Formats..."
rm -fr "qtimageformats-everywhere-src-$QT"
tar xf "qtimageformats-everywhere-src-$QT.tar.xz"
cd "qtimageformats-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DFEATURE_system_webp=ON
make "-j$NPROCS"
make install
cd ../..

echo "Installing Qt Tools..."
rm -fr "qttools-everywhere-src-$QT"
tar xf "qttools-everywhere-src-$QT.tar.xz"
cd "qttools-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DFEATURE_assistant=OFF -DFEATURE_clang=OFF -DFEATURE_designer=ON -DFEATURE_kmap2qmap=OFF -DFEATURE_linguist=ON -DFEATURE_pixeltool=OFF -DFEATURE_pkg_config=OFF -DFEATURE_qev=OFF -DFEATURE_qtattributionsscanner=OFF -DFEATURE_qtdiag=OFF -DFEATURE_qtplugininfo=OFF
make "-j$NPROCS"
make install
cd ../..

echo "Installing Qt Translations..."
rm -fr "qttranslations-everywhere-src-$QT"
tar xf "qttranslations-everywhere-src-$QT.tar.xz"
cd "qttranslations-everywhere-src-$QT"
mkdir build
cd build
"$INSTALLDIR/bin/qt-configure-module" .. -- "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL"
make "-j$NPROCS"
make install
cd ../..

echo "Building shaderc..."
rm -fr "shaderc-$SHADERC"
tar xf "shaderc-$SHADERC.tar.gz"
cd "shaderc-$SHADERC"
cd third_party
tar xf "../../shaderc-glslang-$SHADERC_GLSLANG.tar.gz"
mv "glslang-$SHADERC_GLSLANG" "glslang"
tar xf "../../shaderc-spirv-headers-$SHADERC_SPIRVHEADERS.tar.gz"
mv "SPIRV-Headers-$SHADERC_SPIRVHEADERS" "spirv-headers"
tar xf "../../shaderc-spirv-tools-$SHADERC_SPIRVTOOLS.tar.gz"
mv "SPIRV-Tools-$SHADERC_SPIRVTOOLS" "spirv-tools"
cd ..
patch -p1 < "$SCRIPTDIR/shaderc-changes.patch"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DSHADERC_SKIP_TESTS=ON -DSHADERC_SKIP_EXAMPLES=ON -DSHADERC_SKIP_COPYRIGHT_CHECK=ON -B build
make -C build "-j$NPROCS"
make -C build install
cd ..

echo "Building SPIRV-Cross..."
rm -fr "SPIRV-Cross-$SPIRV_CROSS"
tar xf "SPIRV-Cross-$SPIRV_CROSS.tar.gz"
cd "SPIRV-Cross-$SPIRV_CROSS"
patch -p1 < "$SCRIPTDIR/spirv-cross-changes.patch"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DSPIRV_CROSS_SHARED=ON -DSPIRV_CROSS_STATIC=OFF -DSPIRV_CROSS_CLI=OFF -DSPIRV_CROSS_ENABLE_TESTS=OFF -DSPIRV_CROSS_ENABLE_GLSL=ON -DSPIRV_CROSS_ENABLE_HLSL=OFF -DSPIRV_CROSS_ENABLE_MSL=ON -DSPIRV_CROSS_ENABLE_CPP=OFF -DSPIRV_CROSS_ENABLE_REFLECT=OFF -DSPIRV_CROSS_ENABLE_C_API=ON -DSPIRV_CROSS_ENABLE_UTIL=ON -B build
cmake --build build --parallel
cmake --install build
cd ..

echo "Building cpuinfo..."
rm -fr "cpuinfo-$CPUINFO"
tar xf "cpuinfo-$CPUINFO.tar.gz"
cd "cpuinfo-$CPUINFO"
patch -p1 < "$SCRIPTDIR/cpuinfo-changes.patch"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_X64" -DCPUINFO_LIBRARY_TYPE=shared -DCPUINFO_RUNTIME_TYPE=shared -DCPUINFO_LOG_LEVEL=error -DCPUINFO_LOG_TO_STDIO=ON -DCPUINFO_BUILD_TOOLS=OFF -DCPUINFO_BUILD_UNIT_TESTS=OFF -DCPUINFO_BUILD_MOCK_TESTS=OFF -DCPUINFO_BUILD_BENCHMARKS=OFF -DUSE_SYSTEM_LIBS=ON -B build
make -C build "-j$NPROCS"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_ARM64" -DCPUINFO_LIBRARY_TYPE=shared -DCPUINFO_RUNTIME_TYPE=shared -DCPUINFO_LOG_LEVEL=error -DCPUINFO_LOG_TO_STDIO=ON -DCPUINFO_BUILD_TOOLS=OFF -DCPUINFO_BUILD_UNIT_TESTS=OFF -DCPUINFO_BUILD_MOCK_TESTS=OFF -DCPUINFO_BUILD_BENCHMARKS=OFF -DUSE_SYSTEM_LIBS=ON -B build-arm64
make -C build-arm64 "-j$NPROCS"
merge_binaries $(realpath build) $(realpath build-arm64)
make -C build install
cd ..

echo "Building discord-rpc..."
rm -fr "discord-rpc-$DISCORD_RPC"
tar xf "discord-rpc-$DISCORD_RPC.tar.gz"
cd "discord-rpc-$DISCORD_RPC"
cmake "${CMAKE_COMMON[@]}" "$CMAKE_ARCH_UNIVERSAL" -DBUILD_SHARED_LIBS=ON -B build
cmake --build build --parallel
cmake --install build
cd ..

echo "Cleaning up..."
cd ..
rm -rf deps-build
