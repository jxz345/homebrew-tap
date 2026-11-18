# frozen_string_literal: true

# Pinned Mimo dependency. Installing it does not qualify Mimo protected routing.
class MihomoAT11934 < Formula
  desc "Pinned Mihomo runtime for Mimo"
  homepage "https://github.com/MetaCubeX/mihomo"
  version "1.19.34"
  license "GPL-3.0-only"
  depends_on :macos
  depends_on arch: :arm64
  keg_only :versioned_formula

  on_arm do
    url "https://github.com/MetaCubeX/mihomo/releases/download/v1.19.34/mihomo-darwin-arm64-v1.19.34.gz"
    sha256 "1a7a20eca63fbbaec90137717465bfde488d0db2a3a79b8fadebf9b2545b6e4c"
  end

  def install
    bin.install "mihomo-darwin-arm64" => "mihomo"
  end

  test do
    assert_match "Mihomo Meta v1.19.34 ", shell_output("#{bin}/mihomo -v")
  end
end
