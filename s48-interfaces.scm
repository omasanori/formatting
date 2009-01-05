;;; -*- Mode: Scheme; scheme48-package: (config) -*-

;;;; Format Combinators, Version 1 (BETA)
;;;; Scheme48 Interfaces

(define-interface format-combinators-interface
  (export
    (define-format :syntax)
    format:bracketed
    format:bracketed-list
    format:call-with-output-port
    format:capturing
    format:capturing*
    format:char
    format:delayed
    format:display
    format:empty
    format:indentation
    format:indented-line
    format:join
    format:join/infix
    format:join/prefix
    format:join/suffix
    format:lookup-property
    format:line
    format:line-break
    format:line-start
    format:list
    format:named
    format:non-breaking-space
    format:number
    format:number-with-radix
    format:search-property
    format:sequence
    format:soft-break
    format:string
    format:with-alignment
    format:with-indentation
    format:with-modified-property
    format:with-property
    format:with-updated-property
    ))

(define-interface format-driver-interface
  (export
    format-options
    format-to-port
    format-to-string
    format-with-char-handler
    format-with-condensed-whitespace
    format-with-indentation
    format-with-indenter
    format-with-line-break-handler
    format-with-line-start-handler
    format-with-line-tracking
    format-with-property
    format-with-soft-break-handler
    format-with-string-handler
    format-with-tab-width
    space-indenter
    tab-indenter
    ))

(define-interface format-state-interface
  (export
    apply-format
    canonicalize-format
    format-state?
    format-state/char-handler
    format-state/display-handler
    format-state/insert-property
    format-state/line-break-handler
    format-state/line-start-handler
    format-state/lookup-property
    format-state/modify-property
    format-state/property
    format-state/search-property
    format-state/soft-break-handler
    format-state/string-handler
    format-state/update-property
    format-state-with-output-port
    format->procedure
    make-format-state
    procedure->format
    ))
