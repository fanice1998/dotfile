(require "helix/editor.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))

(provide shell git-add open-helix-scm open-init-scm)

(define (current-path)
  (let* ([focus (editor-focus)]
         [focus-doc-id (editor->doc-id focus)])
    (editor-document->path focus-doc-id)))

;;@doc
;; Run a shell command. Use % as the current file path.
(define (shell . args)
  (helix.run-shell-command
   (string-join
    (map (lambda (x)
           (if (equal? x "%")
               (current-path)
               x))
         args)
    " ")))

;;@doc
;; git add the current file
(define (git-add)
  (shell "git" "add" "%"))

;;@doc
;; Open helix.scm
(define (open-helix-scm)
  (helix.open (helix.static.get-helix-scm-path)))

;;@doc
;; Open init.scm
(define (open-init-scm)
  (helix.open (helix.static.get-init-scm-path)))
