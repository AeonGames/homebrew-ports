class SkiaAeongui < Formula
  desc "Skia 2D graphics library built from source for AeonGUI on macOS"
  homepage "https://skia.org/"
  license "BSD-3-Clause"
  url "https://skia.googlesource.com/skia.git", branch: "chrome/m147", revision: "4502f88af90279ad2685528bd3cf7e90ab140f19"
  version "147-g4502f88af902"
  head "https://skia.googlesource.com/skia.git", branch: "main"

  depends_on "ninja" => :build
  depends_on "pkgconf" => :build
  depends_on "python@3.12" => :build

  depends_on "expat"
  depends_on "freetype"
  depends_on "harfbuzz"
  depends_on "icu4c"
  depends_on "jpeg-turbo"
  depends_on "libpng"
  depends_on "vulkan-loader"
  depends_on "webp"

  on_arm do
    resource "gn" do
      url "https://chrome-infra-packages.appspot.com/dl/gn/gn/mac-arm64/+/git_revision:b2afae122eeb6ce09c52d63f67dc53fc517dbdc8"
      sha256 "cbb260f2cf999f7d74da96b3828a061299c6337354dd6db642e778828576025c"
    end

    resource "ninja" do
      url "https://chrome-infra-packages.appspot.com/dl/infra/3pp/tools/ninja/mac-arm64/+/version:2@1.12.1.chromium.4"
      sha256 "c5e9b4ffab3b2edefbc41849fc81f116c8d047b258906becc061be9ecaf04afd"
    end
  end

  on_intel do
    resource "gn" do
      url "https://chrome-infra-packages.appspot.com/dl/gn/gn/mac-amd64/+/git_revision:b2afae122eeb6ce09c52d63f67dc53fc517dbdc8"
      sha256 "4bea817159f060980f1ca1d0400ef6cd2e0ab0ade66bb34e91aab9c2cffc9d83"
    end

    resource "ninja" do
      url "https://chrome-infra-packages.appspot.com/dl/infra/3pp/tools/ninja/mac-amd64/+/version:2@1.12.1.chromium.4"
      sha256 "9866e69dc0d1efccac019697213b5ab2e0332dcc629682f13733e0792ea95119"
    end
  end

  def install
    target_cpu = Hardware::CPU.arm? ? "arm64" : "x64"

    extra_cflags = [
      "-I#{Formula["icu4c"].opt_include}",
      "-I#{Formula["freetype"].opt_include}",
      "-I#{Formula["harfbuzz"].opt_include}",
      "-I#{Formula["harfbuzz"].opt_include}/harfbuzz",
      "-I#{Formula["libpng"].opt_include}",
      "-I#{Formula["jpeg-turbo"].opt_include}",
      "-I#{Formula["webp"].opt_include}",
      "-I#{Formula["expat"].opt_include}",
      "-I#{Formula["vulkan-loader"].opt_include}"
    ]

    extra_ldflags = [
      "-L#{Formula["icu4c"].opt_lib}",
      "-L#{Formula["freetype"].opt_lib}",
      "-L#{Formula["harfbuzz"].opt_lib}",
      "-L#{Formula["libpng"].opt_lib}",
      "-L#{Formula["jpeg-turbo"].opt_lib}",
      "-L#{Formula["webp"].opt_lib}",
      "-L#{Formula["expat"].opt_lib}",
      "-L#{Formula["vulkan-loader"].opt_lib}"
    ]

    gn_list = lambda { |arr| "[#{arr.map { |v| "\"#{v}\"" }.join(",")}]" }

    gn_args = [
      "is_official_build=true",
      "is_component_build=false",
      "target_cpu=\"#{target_cpu}\"",
      "cc=\"clang\"",
      "cxx=\"clang++\"",
      "skia_use_dawn=false",
      "skia_use_vulkan=true",
      "skia_use_gl=false",
      "skia_use_metal=true",
      "skia_use_dng_sdk=false",
      "skia_use_perfetto=false",
      "skia_use_piex=false",
      "skia_use_system_expat=true",
      "skia_use_system_freetype2=true",
      "skia_use_system_harfbuzz=true",
      "skia_use_system_icu=true",
      "skia_use_system_libjpeg_turbo=true",
      "skia_use_system_libpng=true",
      "skia_use_system_libwebp=true",
      "skia_use_system_zlib=true",
      "extra_cflags=#{gn_list.call(extra_cflags)}",
      "extra_ldflags=#{gn_list.call(extra_ldflags)}"
    ].join(" ")

    # Homebrew builds run in a network-restricted sandbox. Stage GN/Ninja from
    # resources downloaded during the fetch phase, then run the build offline.
    (buildpath/"bin").mkpath
    (buildpath/"third_party/ninja").mkpath

    resource("gn").stage do
      cp "gn", buildpath/"bin/gn"
    end

    resource("ninja").stage do
      cp "ninja", buildpath/"third_party/ninja/ninja"
    end

    chmod 0755, buildpath/"bin/gn"
    chmod 0755, buildpath/"third_party/ninja/ninja"

    system "bin/gn", "gen", "out/Static", "--args=#{gn_args}"
    system "third_party/ninja/ninja", "-C", "out/Static", "skia"

    lib.install "out/Static/libskia.a"
    include.install Dir["include/*"]

    (lib/"pkgconfig").mkpath
    (lib/"pkgconfig"/"skia.pc").write <<~EOS
      prefix=#{prefix}
      exec_prefix=${prefix}
      libdir=${exec_prefix}/lib
      includedir=${prefix}/include

      Name: skia
      Description: Skia 2D graphics library
      Version: #{version}
      Libs: -L${libdir} -lskia
      Cflags: -I${includedir}
    EOS
  end

  test do
    assert_predicate lib/"libskia.a", :exist?
    assert_predicate include/"core/SkCanvas.h", :exist?
  end

  def caveats
    <<~EOS
      This formula is pinned to Skia stable chrome/m147.

      Example usage from this repository:
        ./tools/homebrew/install-skia-via-local-tap.sh

      Manual local tap workflow:
        brew tap aeongui/ports file://$PWD/tools/homebrew/homebrew-ports
        brew install --build-from-source aeongui/ports/skia-aeongui

      If you want tip-of-tree instead:
        brew reinstall --HEAD --build-from-source aeongui/ports/skia-aeongui

      After install, point your build to:
        SKIA_ROOT=#{opt_prefix}
        PKG_CONFIG_PATH=#{opt_lib}/pkgconfig:$PKG_CONFIG_PATH

      Vulkan backend notes:
        - Formula links against Homebrew's vulkan-loader (MoltenVK based on macOS).
        - Ensure your runtime can find Vulkan loader/layers if running outside Homebrew env.
    EOS
  end
end
