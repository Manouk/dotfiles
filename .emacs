;;;
;;; Setup directory structure
;;;

;;; Create proper directory names with trailing backslash
(defun mm/join-dirs (prefix suffix)
  "Joins prefix and suffix into a directory"
  (file-name-as-directory (concat prefix suffix)))

;;; Define and create missing directories
(defconst mm/emacs-dir (mm/join-dirs (getenv "HOME") "/.emacs.d"))
(defconst mm/tmp-dir (mm/join-dirs mm/emacs-dir ".tmp"))
(defconst mm/backups-dir (mm/join-dirs mm/tmp-dir "backups"))
(defconst mm/autosaves-dir (mm/join-dirs mm/tmp-dir "autosaves"))
(defconst mm/elisp-dir (mm/join-dirs mm/emacs-dir ".tmp"))

(let ((dirs (list mm/tmp-dir mm/backups-dir mm/autosaves-dir mm/elisp-dir)))
  (dolist (dir dirs)
    (when (not (file-exists-p dir))
      (message "Make directory: %s" dir)
      (make-directory dir))))

;;; Move emacs menu configuration file
(setq custom-file (expand-file-name "custom.el" mm/emacs-dir))
(when (file-exists-p custom-file) (load custom-file))

;;; Setup load path for packages not available via the package manager
(add-to-list 'load-path mm/elisp-dir)

;;;
;;; Setup backup and autosave
;;;

;;; Move backup and autosave directories to emacs folder
(setq backup-directory-alist `((".*" . ,mm/backups-dir))
      auto-save-file-name-transforms `((".*" ,mm/autosaves-dir)))

;;; Always copy backups to avoid breaking symlinks
(setq backup-by-copying t)

;;; Delete older versions
(setq delete-old-versions t
      kept-new-versions 2
      kept-old-versions 2)

;;; Use version number in the filename
(setq version-control t)

;;;
;;; Interface tweaks
;;;

;;; yes or no?
(fset 'yes-or-no-p 'y-or-n-p)

;;; Show modifier typed almost immediately
(setq echo-keystrokes 0.1)

;;; Fix scroll point in the center
(setq scroll-conservatively 10000
      scroll-preserve-screen-position t)

;;; Remove all bars
(dolist (mode '(menu-bar-mode tool-bar-mode scroll-bar-mode))
  (when (fboundp mode) (funcall mode -1)))

;;; Show line and column number
(line-number-mode 1)
(column-number-mode 1)

;;; No tooltips and dialog boxes
(when (display-graphic-p) (tooltip-mode -1))
(when (display-graphic-p) (setq use-dialog-box nil))

;;; Remove startup screen
(setq inhibit-startup-screen t)

;;; Remove scratch message
(setq initial-scratch-message "")

;;;
;;; Package manager
;;;

(require 'package)

(setq package-archives '(("org"       . "http://orgmode.org/elpa/")
                         ("gnu"       . "http://elpa.gnu.org/packages/")
                         ("melpa"     . "http://melpa.org/packages/")))

(package-initialize)
(package-refresh-contents)

(unless (package-installed-p 'use-package)
  (package-refresh-contents)
  (package-install 'use-package))

(require 'use-package)

;;;
;;; Elisp enhancements, dash and s for strings, f for files
;;;

(require 'cl)
(use-package dash
  :ensure t
  :config (eval-after-load "dash" '(dash-enable-font-lock)))

(use-package s
  :ensure t)

(use-package f
  :ensure t)

;;;
;;; Editing settings
;;;

;;; Set fill to the modern default
(setq-default fill-column 80)

;;; Dont use double space after period
(setq-default sentence-end-double-space nil)

;;; Always have a trailing newline
(setq require-final-new-line t)

;;; Cleanup whitespaces when saving a file
(add-hook 'write-file-hooks 'delete-trailing-whitespace)

;;; Disable tabs
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)

;;; Tabs do indent first then completion
(setq-default tab-always-indent 'complete)

;;; Stop cursor from going over the prompt in the minibuffer
(setq minibuffer-prompt-properties (add-to-list 'minibuffer-prompt-properties 'minibuffer-avoid-prompt))
(setq minibuffer-prompt-properties (add-to-list 'minibuffer-prompt-properties 'point-entered))

;;; Smart beginning of line
(defadvice move-beginning-of-line (around smarter-bol activate)
  ;; Move to requested line if needed.
  (let ((arg (or (ad-get-arg 0) 1)))
    (when (/= arg 1)
      (forward-line (1- arg))))
  ;; Move to indentation on first call, then to actual BOL on second.
  (let ((pos (point)))
    (back-to-indentation)
    (when (= pos (point))
      ad-do-it)))

;;;
;;; Modernize Emacs
;;;

;;; Increase garbage collection threshold
(setq gc-cons-threshold 50000000)

;;;
;;; Sane occur
;;;
(defun occur-dwim ()
  "Call `occur' with a sane default."
  (interactive)
  (push (if (region-active-p)
            (buffer-substring-no-properties
             (region-beginning)
             (region-end))
          (let ((sym (thing-at-point 'symbol)))
            (when (stringp sym)
              (regexp-quote sym))))
        regexp-history)
  (call-interactively 'occur))

;;;
;;; Bookmarks
;;;
(use-package bookmark
  :init
  (setq bookmark-default-file (expand-file-name ".emacs.bmk" mm/tmp-dir)))

;;;
;;; Tramp
;;;

(use-package tramp
  :init
  (setq tramp-default-method "ssh"))

;;;
;;; Eshell
;;;

;;; Bookmark eshell buffers
(use-package eshell-bookmark
  :ensure t)

;;; Eshell up command
(use-package eshell-up
  :ensure t)

;;; Move eshell file out of the way
(setq eshell-directory-name (mm/join-dirs mm/tmp-dir "eshell"))

;;; Commands wanting a pager dont need it
(setenv "PAGER" "cat")

;;; Any key jump to prompt
(use-package eshell
  :init
  (setq ;; eshell-buffer-shorthand t ...  Can't see Bug#19391
   eshell-scroll-to-bottom-on-input 'all
   eshell-error-if-no-glob t
   eshell-hist-ignoredups t
   eshell-save-history-on-exit t
   eshell-prefer-lisp-functions nil
   eshell-destroy-buffer-when-process-dies t))

;;; Visual commands
(use-package eshell
  :init
  (add-hook 'eshell-mode-hook
            (lambda ()
              (add-to-list 'eshell-visual-commands "ssh")
              (add-to-list 'eshell-visual-commands "top"))))

;;; Use counsel for history search
(add-hook 'eshell-mode-hook
          (lambda ()
            (eshell-cmpl-initialize)
            (define-key eshell-mode-map [remap eshell-previous-matching-input] 'counsel-esh-history)))

;;; Aliases
(add-hook 'eshell-mode-hook (lambda ()
    (eshell/alias "e" "find-file $1")
    (eshell/alias "ff" "find-file $1")
    (eshell/alias "emacs" "find-file $1")
    (eshell/alias "ee" "find-file-other-window $1")
    (eshell/alias "d" "dired $1")
    (eshell/alias "ll" "ls -rtlh")))

;;; Clear shell
(defun eshell/clear ()
  "Clear the eshell buffer."
  (let ((inhibit-read-only t))
    (erase-buffer)
    (eshell-send-input)))

;;; Fancy prompt
(defun pwd-replace-home (pwd)
  "Replace home in PWD with tilde (~) character."
  (interactive)
  (let* ((home (expand-file-name (getenv "HOME")))
         (home-len (length home))
         (p4-home "/cygwin/c/Perforce")
         (p4-home-len (length p4-home)))
    (if (and
         (>= (length pwd) home-len)
         (equal home (substring pwd 0 home-len)))
        (concat "~" (substring pwd home-len))
      (if (and
         (>= (length pwd) p4-home-len)
         (equal p4-home (substring pwd 0 p4-home-len)))
        (concat "~/perforce" (substring pwd p4-home-len))
        pwd))))

(defun pwd-shorten-dirs (pwd)
  "Shorten all directory names in PWD except the last two."
  (let ((p-lst (split-string pwd "/")))
    (if (> (length p-lst) 2)
        (concat
         (mapconcat (lambda (elm) (if (zerop (length elm)) ""
                                    (if (string-match-p ":" elm) elm
                                      (substring elm 0 1))))
                    (butlast p-lst 2)
                    "/")
         "/"
         (mapconcat (lambda (elm) elm)
                    (last p-lst 2)
                    "/"))
      pwd)))  ;; Otherwise, we just return the PWD

(defun split-directory-prompt (directory)
  (if (string-match-p ".*/.*" directory)
      (list (file-name-directory directory) (file-name-base directory))
    (list "" directory)))

(defun eshell/eshell-local-prompt-function ()
  "A prompt for eshell that works locally (in that is assumes
that it could run certain commands) in order to make a prettier,
more-helpful local prompt."
  (interactive)
  (let* ((pwd        (eshell/pwd))
         (directory (split-directory-prompt
                     (pwd-shorten-dirs
                      (pwd-replace-home pwd))))
         (parent (car directory))
         (name   (cadr directory))
         (for-bars   `(:weight bold))
         (for-parent `(:foreground "dark orange"))
         (for-dir    `(:foreground "orange" :weight bold)))
    (concat
     (propertize "["      'face for-bars)
     (propertize parent   'face for-parent)
     (propertize name     'face for-dir)
     (propertize "]"      'face for-bars)
     (propertize "\n"     'face for-bars)
     (propertize (if (= (user-uid) 0) " #" " $") 'face `(:weight ultra-bold))
     (propertize " "    'face `(:weight bold)))))

(setq-default eshell-prompt-function #'eshell/eshell-local-prompt-function)

;;;
;;; Jumping to windows
;;;

(use-package ace-window
  :ensure t
  :init
    (setq aw-keys '(?a ?s ?d ?f ?j ?k ?l ?o))
    (global-set-key (kbd "M-o") 'ace-window)
    :diminish ace-window-mode)

;;;
;;; which-key displays key bindings as you type
;;;

(use-package which-key
  :ensure t
  :defer 10
  :diminish which-key-mode
  :config

  ;; Replacements for how KEY is replaced when which-key displays
  ;;   KEY → FUNCTION
  ;; Eg: After "C-c", display "right → winner-redo" as "▶ → winner-redo"
  (setq which-key-key-replacement-alist
        '(("<\\([[:alnum:]-]+\\)>" . "\\1")
          ("left"                  . "◀")
          ("right"                 . "▶")
          ("up"                    . "▲")
          ("down"                  . "▼")
          ("delete"                . "DEL") ; delete key
          ("\\`DEL\\'"             . "BS") ; backspace key
          ("next"                  . "PgDn")
          ("prior"                 . "PgUp"))

        ;; Replacements for how part or whole of FUNCTION is replaced:
        which-key-description-replacement-alist
        '(("Prefix Command" . "prefix")
          ("\\`projectile-" . "𝓟/")
          ("\\`org-babel-"  . "ob/"))

        ;; Underlines commands to emphasize some functions:
        which-key-highlighted-command-list
        '("\\(rectangle-\\)\\|\\(-rectangle\\)"
          "\\`org-"))

  ;; Change what string to display for a given *complete* key binding
  ;; Eg: After "C-x", display "8 → +unicode" instead of "8 → +prefix"
  (which-key-add-key-based-replacements
    "C-x 8"   "unicode"
    "C-c p s" "projectile-search"
    "C-c p 4" "projectile-other-buffer-"
    "C-x a"   "abbrev/expand"
    "C-x r"   "rect/reg"
    "C-c C-v" "org-babel")

  (which-key-mode 1))

;;;
;;; Solarized theme
;;;

(use-package solarized-theme
  :ensure t
  :config
  (setq solarized-distinct-fringe-background t)
  (setq solarized-use-variable-pitch nil)
  (setq solarized-scale-org-headlines nil)
  (setq solarized-high-contrast-mode-line nil)
  (load-theme 'solarized-dark t))

;;;
;;; ivy, swiper and counsel
;;;

(use-package ivy
  :ensure t
  :diminish ivy-mode
  :init
  (setq ivy-use-virtual-buffers t)
  (setq ivy-count-format "(%d/%d) ")
  :bind
  ("C-x b" . ivy-switch-buffer)
  :config
  (ivy-mode 1)
  (bind-key "C-c C-r" 'ivy-resume))

(use-package swiper
  :ensure t
  :bind
  ("C-s" . swiper))

(use-package counsel
  :ensure t
  :bind
  ("M-x" . counsel-M-x)
  ("C-x C-f" . counsel-find-file)
  ("C-c k" . counsel-ag))

;;;
;;; projectile
;;;

(use-package projectile
  :ensure t
  :bind-keymap
  ("C-c p" . projectile-command-map)
  :config
  (projectile-global-mode)
  (setq projectile-mode-line
        '(:eval (format " [%s]" (projectile-project-name))))
  (setq projectile-remember-window-configs t)
  (setq projectile-completion-system 'ivy))

;;;
;;; Keyboard bindings
;;;

;;; Burry buffer, remove it from window and send it to the bottom of the stack
(global-set-key (kbd "C-c y") 'bury-buffer)

;;; Revert buffer
(global-set-key (kbd "C-c r") 'revert-buffer)

;;; Use ibuffer
(global-set-key (kbd "C-x C-b") 'ibuffer)

;;; Remap occur to occur-dwim
(global-unset-key (kbd "M-s o"))
(global-set-key (kbd "M-s o") 'occur-dwin)

;;; Fullscreen
(global-set-key (kbd "<f11>") 'toggle-frame-fullscreen)
