# This file was generated by GoReleaser. DO NOT EDIT.
class Kustomizer < Formula
  desc "Kustomize build, apply, prune command-line utility."
  homepage "https://kustomizer.dev/"
  version "0.2.1"
  bottle :unneeded

  if OS.mac?
    url "https://github.com/stefanprodan/kustomizer/releases/download/v0.2.1/kustomizer_0.2.1_darwin_amd64.tar.gz"
    sha256 "afb30c0b4caae50d7e8c671990fd7150a0fb4a160f90d16c760a268b092fe300"
  elsif OS.linux?
    if Hardware::CPU.intel?
      url "https://github.com/stefanprodan/kustomizer/releases/download/v0.2.1/kustomizer_0.2.1_linux_amd64.tar.gz"
      sha256 "0dcf3a2976fadf5961fc2ca4df914a207d4a483def1ee892d03d41450e1ea345"
    end
    if Hardware::CPU.arm?
      if Hardware::CPU.is_64_bit?
        url "https://github.com/stefanprodan/kustomizer/releases/download/v0.2.1/kustomizer_0.2.1_linux_arm64.tar.gz"
        sha256 "ce0e546e0f431425587b9630d31fb2735e953981e468b204d6e685b28b93a518"
      else
      end
    end
  end
  
  depends_on "kubectl" => :optional

  def install
    bin.install "kustomizer"
  end

  test do
    system "#{bin}/kustomizer --version"
  end
end