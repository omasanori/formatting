;;; -*- Mode: Scheme; scheme48-package: (config) -*-

;;;; Formatting Tools, Version 1 (BETA)
;;;; Scheme48 Package Definitions

(define-structures
    ((format-combinators format-combinators-interface)
     (format-driver format-driver-interface)
     (format-state format-state-interface))
  (open scheme
        receiving
        srfi-6                          ;Basic String Ports
        srfi-9                          ;define-record-type
        srfi-23                         ;error
        (subset i/o (write-string))
        (subset big-util (no-op))
        )
  (optimize auto-integrate)

  (begin
    (define (char-break? char)
      (or (char=? char #\space)
          (char=? char #\newline)))

    (define (char-line-break? char)
      (char=? char #\newline))

    (define (string-search-line-break string start end)
      (and (< start end)
           (if (char-line-break? (string-ref string start))
               (+ start 1)
               (string-search-line-break string (+ start 1) end)))))

  (files format))
