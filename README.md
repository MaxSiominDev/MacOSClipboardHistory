# ClipboardHistory

macOS menu bar clipboard history. Hit ⌘⇧V to open it next to your text caret

## Install

```sh
brew tap maxsiomin/cliph
brew install --cask cliph
```

On first launch grant Accessibility in System Settings -> Privacy & Security -> Accessibility

## Use

- ⌘⇧V opens the panel near the caret
- `cliph` from a terminal opens it too
- Click a row to paste, hover and click ✕ to delete

History keeps the last 300 items for up to 2 days

## Build

Requires Xcode 26 and macOS 26

```sh
git clone https://github.com/MaxSiominDev/MacOSClipboardHistory.git
cd MacOSClipboardHistory
open ClipboardHistory.xcodeproj
```

## License

MIT, see [LICENSE](LICENSE)
