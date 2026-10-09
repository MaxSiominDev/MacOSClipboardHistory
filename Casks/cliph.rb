# The installed copy lives in MaxSiominDev/homebrew-cliph; this one is edited
# alongside the source so the two stay in sync.
cask "cliph" do
  version "1.0.3"
  sha256 "fef8774ed7b9303eb250dc857ab060c8b0eba264559ef9132616401bb769f9ec"

  url "https://github.com/MaxSiominDev/MacOSClipboardHistory/releases/download/v#{version}/ClipboardHistory.zip",
      verified: "github.com/MaxSiominDev/MacOSClipboardHistory/"
  name "ClipboardHistory"
  desc "Clipboard history manager that lives in the menu bar"
  homepage "https://github.com/MaxSiominDev/MacOSClipboardHistory"

  depends_on macos: ">= :tahoe"

  app "ClipboardHistory.app"
  binary "#{appdir}/ClipboardHistory.app/Contents/Resources/cliph"

  uninstall quit:       "dev.maxsiomin.cliph",
            login_item: "ClipboardHistory"

  zap trash: [
    "~/Library/Application Support/ClipboardHistory",
    "~/Library/Preferences/dev.maxsiomin.cliph.plist",
    "~/Library/Caches/dev.maxsiomin.cliph",
  ]
end
