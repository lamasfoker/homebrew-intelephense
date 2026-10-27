class TrailCode < Formula
  desc "Context layer for coding agents — installed with a private, vendored Node.js runtime"
  homepage "https://github.com/trailhq/Trail-Code"
  url "https://registry.npmjs.org/@trailhq/trail-code/-/trail-code-0.27.0.tgz"
  sha256 "2e61797211e7013055d9ada468f3ff53b828fd75c5c8e83d189405b96f577cad"
  license "MIT"

  livecheck do
    url "https://registry.npmjs.org/@trailhq%2ftrail-code"
    strategy :npm
  end

  # Vendored Node.js runtime. This formula intentionally does NOT `depends_on "node"` —
  # trail is installed and run only against this private copy, never against any
  # Node.js the user has on PATH (system, nvm, volta, etc).
  resource "node" do
    on_macos do
      on_arm do
        url "https://nodejs.org/dist/v24.22.1/node-v24.22.1-darwin-arm64.tar.gz"
        sha256 "89c682593d76cd44233fa53b1563264e7de9cbb189cad169135c5b4fadfbc0a7"
      end
      on_intel do
        url "https://nodejs.org/dist/v24.22.1/node-v24.22.1-darwin-x64.tar.gz"
        sha256 "d132557e7ee2b85af08b0c8c34338e65c6430f2238d01f727728ef42dc83b035"
      end
    end
  end

  def install
    node_dir = libexec/"node"
    resource("node").stage node_dir

    node = node_dir/"bin/node"
    npm_cli = node_dir/"lib/node_modules/npm/bin/npm-cli.js"

    # The native tree-sitter modules (tree-sitter-kotlin has no prebuilt binary) compile in their
    # install scripts with a bare `node`, so the vendored runtime must be first on PATH.
    ENV.prepend_path "PATH", node_dir/"bin"
    # `brew install` must not send the install event that `npm i -g` sends.
    ENV["DO_NOT_TRACK"] = "1"

    # Install the packed tarball, not the directory: a directory install is a symlink into buildpath.
    system node, npm_cli, "pack", "--ignore-scripts"
    system node, npm_cli, "install", "--global", "--prefix=#{libexec}", "--no-audit", "--no-fund",
           buildpath.glob("*.tgz").first

    package = libexec/"lib/node_modules/@trailhq/trail-code"
    inreplace package/"dist/bin/trail.js", "#!/usr/bin/env node", "#!#{node}"

    # A symlink, not a wrapper: the agent hook shims find the package by following `trail` on PATH.
    bin.install_symlink libexec/"bin/trail"
  end

  test do
    ENV["DO_NOT_TRACK"] = "1"
    node = libexec/"node/bin/node"
    package = libexec/"lib/node_modules/@trailhq/trail-code"

    assert_equal version.to_s, shell_output("#{bin}/trail --version").strip

    # A missing native grammar makes trail fall back to WASM without failing, so check them directly.
    cd package do
      system node, "-e", "require('tree-sitter'); require('tree-sitter-kotlin'); require('tree-sitter-php')"
    end

    (testpath/"src").mkpath
    (testpath/"src/Greeter.php").write "<?php\nclass Greeter { public function hi() { return 'hi'; } }\n"
    (testpath/"src/Main.kt").write "fun main() { println(\"hi\") }\n"
    system "git", "init", "--quiet", testpath
    system "git", "-C", testpath, "add", "."
    assert_match "parsed: 2 of 2 files", shell_output("#{bin}/trail build #{testpath}")
  end
end
