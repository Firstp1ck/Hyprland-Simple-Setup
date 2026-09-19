# Live setup output

The output pane remains interactive while setup runs. Reading older output does not pause, restart or cancel the installer.

| Control | Action |
| --- | --- |
| Click inside Output | Focus the pane; its border and title show focus |
| Mouse wheel over Output | Scroll three displayed rows and pause automatic following |
| Click or drag the right scrollbar | Seek through retained output without jumping back to new messages |
| Up / Down while Output is focused | Scroll one displayed row |
| Page Up / Page Down | Scroll eight displayed rows |
| Home | Go to the oldest retained output |
| End or the Follow button | Return to the latest output and resume following |
| `v` or Details / Compact button | Switch view and resume following |
| Escape or click outside Output | Remove output focus |

Enter opens preflight only when Output is not focused, so reading output does not accidentally switch screens. Modal dialogs block output mouse interaction.

Long messages wrap into separately scrollable display rows. New messages do not move the view while you are reading older output. Each display history retains up to 5,000 source lines; once that limit is reached, the oldest lines are discarded from the view. The complete captured output is written separately to the path shown under **Full log**.

Log messages are handled in bounded batches with input checks between them, keeping build output from monopolizing the event loop. Mouse capture is disabled again when the TUI exits or panics. Keyboard scrolling remains available in terminals that do not report mouse events.

Clicking log text focuses the pane; it does not execute text or open links.
