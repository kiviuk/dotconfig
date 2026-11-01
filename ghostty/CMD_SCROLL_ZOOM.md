# Command + trackpad font zoom for Ghostty

`ghostty-cmd-scroll-zoom.swift` is a small macOS event-tap helper. It watches vertical scroll events, acts only while Ghostty (`com.mitchellh.ghostty`) is frontmost and Command is held, consumes the scroll event, and sends `Ctrl+=` / `Ctrl+-` shortcuts to Ghostty. Each shortcut changes the font size by 0.03 pt. Trackpad events accumulate to a 40-point threshold per step; wheel detents produce one step each.

## Install and permissions

Run:

```sh
~/.config/ghostty/install-cmd-scroll-zoom.sh
```

In **System Settings → Privacy & Security**, add `~/Applications/Ghostty Cmd Scroll Zoom.app` to both **Input Monitoring** and **Accessibility**, and enable it. The event tap needs Input Monitoring to observe scroll events. Accessibility permission allows it to post the font-size keystrokes. The LaunchAgent waits for both permissions and activates the event tap when they are granted.

Check its log:

```sh
tail -f ~/Library/Logs/ghostty-cmd-scroll-zoom.log
```

The LaunchAgent starts the helper at login. Command + vertical two-finger scrolling over Ghostty changes the font size. Other apps and unmodified scrolling pass through unchanged. Physical pinch gestures are not handled by this helper.

To adjust trackpad sensitivity, edit `~/.config/ghostty/cmd-scroll-zoom-scroll-threshold` and restart the helper. Lower values trigger smaller, more frequent steps. The Ghostty `increase_font_size` / `decrease_font_size` keybind amounts control each step size. Increase the threshold for less zoom per trackpad movement. The current font-size step is 0.03 pt.

## Remove

```sh
~/.config/ghostty/install-cmd-scroll-zoom.sh uninstall
```
