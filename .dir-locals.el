;; Emacs settings for this repo:  wrap at 100 columns (default 70; M-q, auto-fill),
;; two spaces after a sentence;  VHDL indentation as
;; utils/cleanup_ws.sh applies it (vhdl-mode defaults, spaces only, a closing paren at the level of the line that
;; opened it).
((nil . ((fill-column . 100)
         (sentence-end-double-space . t)))
 (vhdl-mode . ((indent-tabs-mode . nil)
               (eval . (vhdl-set-offset 'arglist-close 0)))))
