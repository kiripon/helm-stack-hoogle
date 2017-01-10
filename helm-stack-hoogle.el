;;; helm-stack-hoogle.el --- helm source with stack                                 -*- lexical-binding: t; -*-

;; Copyright (C) 2016  Hirotada Kiriyama

;; Author:  Hirotada Kiriyama <painapoo@gmail.com>
;; Keywords: haskell programming stack hoogle

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

;;; Commentary: before launching helm-stack-hoogle, do "stack install hoogle".

(require 'helm)
(defgroup helm-stack-hoogle nil
  "Use helm to navigate query results from Hoogle(stack)"
  :group 'helm)

(defvar-local helm-stack-hoogle--use-stack t)

;;;###autoload
(defun helm-stack-hoogle ()
  (interactive)
  (helm :sources
        (helm-build-sync-source "Hoogle"
          :init (lambda () (setq helm-stack-hoogle--use-stack (helm-stack-hoogle--stack-hoogle-available-p)))
          :candidates #'helm-stack-hoogle--set-candidates
          :action (helm-make-actions "Open in browser" #'browse-url)
          :volatile t)
        :prompt "Stack Hoogle: "
        :buffer "*Stack Hoogle search*"))

(defun helm-stack-hoogle--stack-hoogle-available-p ()
  (with-temp-buffer
    (apply #'call-process "stack" nil t nil (list "hoogle" "--no-setup"))
    (goto-char (point-min))
    (not (re-search-forward "No Hoogle database" nil t))))

(defun helm-stack-hoogle--set-candidates ()
  (let ((items (helm-stack-hoogle--get-candidates helm-pattern)))
    (mapcar #'helm-stack-hoogle--to-candidate-item items)))

(defun helm-stack-hoogle--propertize-decl (string)
  (with-temp-buffer
    (let ((flycheck-checkes nil)
          (haskell-mode-hook nil))
      (haskell-mode))
    (insert string)
    (font-lock-ensure)
    (buffer-string)))

(defun helm-stack-hoogle--to-candidate-item (candidate)
  (let ((module (plist-get candidate :module))
        (fundecl (format "%s :: %s"
                         (plist-get candidate :funname)
                         (plist-get candidate :type))))
    (cons (format "%s %s" module (helm-stack-hoogle--propertize-decl fundecl))
          (plist-get candidate :url))))

(defun helm-stack-hoogle--get-candidates (query &optional num)
  "returns list of plist"
  (let* ((ncount (or num helm-candidate-number-limit))
         (cmd (if helm-stack-hoogle--use-stack "stack" "hoogle"))
         (args (append (if helm-stack-hoogle--use-stack
                           (list "hoogle" "--"))
                       (list "search" "-l")
                       (if ncount (list "-n" (int-to-string ncount)))
                       (list query)))
         candidates)
    (with-temp-buffer
      (apply #'call-process cmd nil t nil args)
      (goto-char (point-min))
      (while (not (eobp))
        (when (looking-at helm-stack-hoogle--result-regexp)
          (let* ((modname (match-string 1))
                 (funname (match-string 2))
                 (type    (match-string 3))
                 (url     (match-string-no-properties 4))
                 (item    (list :module modname :funname funname :type type :url url)))
            (push item candidates)))
        (forward-line 1))
      (nreverse candidates))))
(defconst helm-stack-hoogle--result-regexp
  (string-join
   '("^\\([[:upper:][:alnum:].]*\\)"
     "\\([[:lower:]][[:alnum:]]*\\)"
     "::"
     "\\(.*\\)"
     "--"
     "\\(.*\\)"
     )
   " "))

(provide 'helm-stack-hoogle)

;;; helm-stack-hoogle.el ends here
