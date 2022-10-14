## RELPy v0.2.0

### New features

* BREAKING CHANGE: `word_delimiters` is now a `Array(Char)` property instead of `Regex` to return in a overridden function.
* `ctrl-n`, `ctrl-p` keybinding for navigate histories (#1), thank @zw963!
* `delete_after`, `delete_before` (`ctrl-k`, `ctrl-u`) (#2), thank @zw963!
* `move_word_forward`, `move_word_backward` (`alt-f`/`ctrl-right`, `alt-b`/`ctrl-left`) (#2), thank @zw963!
* `delete_word`, `word_back` (`alt-backspace`/`ctrl-backspace`, `alt-d`/`ctrl-delete`) (#2), thank @zw963!
* `delete` or `eof` on `ctrl-d` (#2), thank @zw963!
* Bind `ctrl-b`/`ctrl-f` with move cursor backward/forward (#2), thank @zw963!.

### Bug fixs
* Fix ioctl window size magic number on darwin and bsd (#3), thank @shinzlet!

### Internal
* Refactor: move word functions (`delete_word`, `move_word_forward`, etc.) from `Reader` to the `ExpressionEditor`.
* Add this CHANGELOG.


## RELPy v0.1.0
First version extracted from IC.

### New features
* Multiline input
* History
* Pasting of large expressions
* Hook for Syntax highlighting
* Hook for Auto formatting
* Hook for Auto indentation
* Hook for Auto completion (Experimental)
