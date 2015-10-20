;;; highlight2clipboard.el --- Copy text to clipboard with highlighting.

;; Copyright (C) 2015 Anders Lindgren

;; Author: Anders Lindgren
;; Version: 0.0.2
;; Created: 2015-06-17
;; Package-Requires: ((htmlize "1.47"))
;; Keywords: tools

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Support for copying text with formatting information, like color,
;; to the system clipboard. Concretely, this allows you to paste
;; syntax highlighted source code into word processors and mail
;; editors.
;;
;; On MS-Windows, Ruby must be installed.
;;
;; Usage:
;;
;; * `M-x highlight2clipboard-copy-region-to-clipboard RET' -- Copy
;;   the region, with formatting, to the clipboard.
;;
;; * `M-x highlight2clipboard-copy-buffer-to-clipboard RET' -- Copy
;;   the buffer, with formatting, to the clipboard.
;;
;; * Highlight2clipboard mode -- Global minor mode, when enabled, all
;;   copies and cuts are exported, with formatting information, to the
;;   clipboard.
;;
;; Supported systems:
;;
;; Copying formatted text to the clipboard is highly system specific.
;; Currently, Mac OS X and MS-Windows are supported. Contributions for
;; other systems are most welcome.
;;
;; Known problems:
;;
;; Font Lock mode, the system providing syntax highlighting in Emacs,
;; use "lazy highlighting". Effectively, this mean that only the
;; visible parts of a buffer are highlighted. The problem with this is
;; that when copying text to the clipboard, only the highlighted parts
;; gets formatting information. To get around this, walk through the
;; buffer, use `highlight2clipboard-ensure-buffer-is-fontified', or
;; use one of the `highlight2clipboard-copy-' functions.
;;
;; This package generates some temporary files, which it does not
;; remove. It is assumed that the system temporary directory is
;; cleaned from time to time.

;; Implementation:
;;
;; This package use the package `htmlize' to create an HTML version of
;; a highlighted text. This is added as a new flavor to the clipboard,
;; allowing an application to pick the most suited version.

;;; Code:


(require 'htmlize)

(defgroup highlight2clipboard nil
  "Support for exporting formatted text to the clipboard."
  :group 'faces)


(defcustom highlight2clipboard-temporary-file-directory
  (or small-temporary-file-directory
      temporary-file-directory)
  "The location where this package place temporary files."
  :group 'highlight2clipboard)


;; Copy of the last copied text, used to prevent loss of text
;; properties when the text is pasted back into Emacs.
(defvar highlight2clipboard--last-text nil)

(defvar highlight2clipboard--original-interprocess-cut-function
  interprogram-cut-function)

(defvar highlight2clipboard--original-interprocess-paste-function
  interprogram-paste-function)

(defvar highlight2clipboard--directory
  (if load-file-name
      (file-name-directory load-file-name)
    default-directory))

(defvar highlight2clipboard--temp-file-base-name
  (expand-file-name (make-temp-name "h2c-")
                    highlight2clipboard-temporary-file-directory))


;; ------------------------------------------------------------
;; Interprogram functions
;;

(setq interprogram-cut-function 'highlight2clipboard-copy-to-clipboard)

;; --------------------

(defun highlight2clipboard-interprogram-paste-function ()
  (and highlight2clipboard--original-interprocess-paste-function
       (let ((clipboard
              (funcall
               highlight2clipboard--original-interprocess-paste-function)))
         (if (and highlight2clipboard--last-text
                  (string= clipboard highlight2clipboard--last-text))
             highlight2clipboard--last-text
           (setq highlight2clipboard--last-text nil)
           clipboard))))

(setq interprogram-paste-function
      'highlight2clipboard-interprogram-paste-function)


;; ------------------------------------------------------------
;; Global minor mode
;;

;;;###autoload
(define-minor-mode highlight2clipboard-mode
  "When active, cuts and copies are exported with formatting to the clipboard."
  nil
  nil
  nil
  :global t
  :group 'highlight2clipboard
  ;; This will issue an error on unsupported systems, preventing our
  ;; hooks to be installed.
  (highlight2clipboard-set-defaults)
  (setq interprogram-cut-function
        (if highlight2clipboard-mode
            'highlight2clipboard-copy-to-clipboard
          highlight2clipboard--original-interprocess-cut-function)))


;; ------------------------------------------------------------
;; Core functions.
;;

;;;###autoload
(defun highlight2clipboard-ensure-buffer-is-fontified ()
  "Ensure that the buffer is fontified."
  (interactive)
  (when (and font-lock-mode
             ;; Prevent clearing out face attributes explicitly
             ;; inserted by functions like `list-faces-display'.
             ;; (Font-lock mode is enabled, for some reason, in those
             ;; buffers.)
             (not (and (eq major-mode 'help-mode)
                       (not font-lock-defaults))))
    (font-lock-fontify-region (point-min) (point-max))))


;;;###autoload
(defun highlight2clipboard-copy-region-to-clipboard (beg end)
  "Copy region with formatting to system clipboard.

Unlike using Highlight2clipboard mode, this ensure that buffers
are fully fontified."
  (interactive "r")
  (highlight2clipboard-ensure-buffer-is-fontified)
  (highlight2clipboard-copy-to-clipboard
   (buffer-substring beg end)))


;;;###autoload
(defun highlight2clipboard-copy-buffer-to-clipboard ()
  "Copy buffer with formatting to system clipboard.

Unlike using Highlight2clipboard mode, this ensure that buffers
are fully fontified."
  (interactive)
  (highlight2clipboard-copy-region-to-clipboard (point-min) (point-max)))


(defun highlight2clipboard-copy-to-clipboard (text)
  "Copy TEXT with formatting to the system clipboard."
  (setq highlight2clipboard--last-text text)
  ;; Set the normal clipboard string(s).
  (when highlight2clipboard--original-interprocess-cut-function
    (funcall highlight2clipboard--original-interprocess-cut-function text))
  (highlight2clipboard-set-defaults)
  ;; Add a html version to the clipboard.
  (let ((file-name-html (concat highlight2clipboard--temp-file-base-name
                                ".html")))
    (with-temp-buffer
      (insert text)
      (let ((htmlize-output-type 'inline-css))
        (let ((html-buffer (htmlize-buffer)))
          (with-current-buffer html-buffer
            (let ((coding-system-for-write 'utf-8))
              (goto-char (point-min))
              (let ((p (if (re-search-forward "<pre>" nil t)
                           (prog1
                               (match-beginning 0)
                             ;; Remove extra newline.
                             (delete-char 1))
                         (point-min))))
                (goto-char p)
                (insert "<meta charset='utf-8'>")
                (goto-char (point-max))
                (let ((p2 (if (re-search-backward "</pre>\n" nil t)
                              (match-end 0)
                            (point-max))))
                  (write-region p p2 file-name-html nil :silent)))))
          (kill-buffer html-buffer))))
    (when highlight2clipboard--add-html-to-clipboard-function
      (funcall highlight2clipboard--add-html-to-clipboard-function
               file-name-html))))


;; ------------------------------------------------------------
;; System-specific support.
;;

(defvar highlight2clipboard--add-html-to-clipboard-function nil)

(defun highlight2clipboard-set-defaults ()
  "Set up highlight2clipboard, or issue an error if system not supported."
  (unless highlight2clipboard--add-html-to-clipboard-function
    (setq highlight2clipboard--add-html-to-clipboard-function
          (cond ((eq system-type 'darwin)
                 #'highlight2clipboard--add-html-to-clipboard-osx)
                ((memq system-type '(windows-nt cygwin))
                 #'highlight2clipboard--add-html-to-clipboard-w32)
                (t (error "Unsupported system: %s" system-type))))))


(defun highlight2clipboard--add-html-to-clipboard-osx (file-name)
  (call-process
   "python"
   nil
   0                                  ; <- Discard and don't wait
   nil
   (concat highlight2clipboard--directory
           "bin/highlight2clipboard-osx.py")
   file-name))


(defun highlight2clipboard--add-html-to-clipboard-w32 (file-name)
  (call-process
   "ruby"
   nil
   0                                  ; <- Discard and don't wait
   nil
   (concat highlight2clipboard--directory
           "bin/highlight2clipboard-w32.rb")
   file-name))

(provide 'highlight2clipboard)

;;; highlight2clipboard.el ends here
