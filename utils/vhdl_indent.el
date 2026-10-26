;; Re-indent VHDL files as Emacs vhdl-mode does with this repo's .dir-locals.el, and replace tabs by spaces.
;; Batch use (utils/cleanup_ws.sh):  emacs -Q --batch -l utils/vhdl_indent.el FILE...
;; A file is rewritten only if it changes.
(require 'vhdl-mode)
(dolist (f command-line-args-left)
  (with-current-buffer (find-file-noselect f)
    (vhdl-mode)
    (setq indent-tabs-mode nil)
    (vhdl-set-offset 'arglist-close 0)
    (indent-region (point-min) (point-max))
    (untabify (point-min) (point-max))
    (when (buffer-modified-p) (save-buffer))
    (kill-buffer)))
(setq command-line-args-left nil)
