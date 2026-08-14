class Intelephense < Formula
  desc "PHP language server (LSP) — installed with a private, vendored Node.js runtime"
  homepage "https://intelephense.com"
  url "https://registry.npmjs.org/intelephense/-/intelephense-1.18.5.tgz"
  sha256 "9c945dfeec2f030108da34c9c1d9e6c692cfd5d0cf5933f13b8651f7b9f943f1"
  # Intelephense is proprietary freemium software (docs: https://github.com/bmewburn/intelephense-docs).
  license :cannot_represent

  livecheck do
    url "https://registry.npmjs.org/intelephense"
    strategy :npm
  end

  # Vendored Node.js runtime. This formula intentionally does NOT `depends_on "node"` —
  # intelephense is installed and run only against this private copy, never against any
  # Node.js the user has on PATH (system, nvm, volta, etc).
  resource "node" do
    on_macos do
      on_arm do
        url "https://nodejs.org/dist/v24.19.0/node-v24.19.0-darwin-arm64.tar.gz"
        sha256 "8294b7aa9b03997481c06babf1e8b270c859358f27da57a11509afe537ac381d"
      end
      on_intel do
        url "https://nodejs.org/dist/v24.19.0/node-v24.19.0-darwin-x64.tar.gz"
        sha256 "d1b5e999db158c62fe8f7267a4476b035d8bd93b1a605bac24a3f0dd166e3316"
      end
    end
  end

  def install
    node_dir = libexec/"node"
    resource("node").stage node_dir

    node = node_dir/"bin/node"
    npm_cli = node_dir/"lib/node_modules/npm/bin/npm-cli.js"

    # Some transitive npm dependencies (e.g. protobufjs) run their own `node scripts/...`
    # postinstall steps, which need a bare `node` resolvable on PATH. Prepend the vendored
    # runtime so that's still ONLY our private copy — never any `node` the caller might have.
    ENV.prepend_path "PATH", node_dir/"bin"
    system node, npm_cli, "install", "--production", "--no-audit", "--no-fund"

    libexec.install buildpath.children

    (bin/"intelephense").write <<~SH
      #!/bin/bash
      exec "#{node}" "#{libexec}/lib/intelephense.js" "$@"
    SH
  end

  test do
    require "timeout"

    request = <<~JSON
      {"jsonrpc":"2.0","id":1,"method":"initialize","params":{"processId":null,"rootUri":null,"capabilities":{}}}
    JSON
    body = request.strip
    message = "Content-Length: #{body.bytesize}\r\n\r\n#{body}"

    output = IO.popen([bin/"intelephense", "--stdio"], "r+") do |io|
      io.write(message)
      io.close_write
      Timeout.timeout(30) { io.read(200) }
    end

    assert_match "jsonrpc", output.to_s
  end
end
