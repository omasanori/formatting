;;; -*- Mode: Scheme -*-

;;;; Formatting Tools, Version 1 (BETA)

;;; Copyright (c) 2008, Taylor R. Campbell
;;;
;;; Redistribution and use in source and binary forms, with or without
;;; modification, are permitted provided that the following conditions
;;; are met:
;;;
;;; * Redistributions of source code must retain the above copyright
;;;   notice, this list of conditions and the following disclaimer.
;;;
;;; * Redistributions in binary form must reproduce the above copyright
;;;   notice, this list of conditions and the following disclaimer in
;;;   the documentation and/or other materials provided with the
;;;   distribution.
;;;
;;; * Neither the names of the authors nor the names of contributors
;;;   may be used to endorse or promote products derived from this
;;;   software without specific prior written permission.
;;;
;;; THIS SOFTWARE IS PROVIDED BY THE AUTHORS ``AS IS'' AND ANY EXPRESS
;;; OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
;;; WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED.  IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY
;;; DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
;;; DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
;;; INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
;;; WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
;;; NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
;;; SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

;;; This is a very simple formatting abstraction.  Its most salient
;;; lack is any sort of backward information flow, because it has no
;;; semblance of a constraint propagator, which would be necessary for
;;; a pretty-printer.

;++ Should this move in the direction of a constraint propagator or a
;++ monad?  Formats like SET-INDENTATION suggest a monad, but I am more
;++ inclined toward constraint propagation and using only
;++ WITH-INDENTATION.

(define (format-to-port output-port options format)
  (apply-format format (options (make-format-state output-port))))

(define (format-to-string options format)
  (let ((port (open-output-string)))
    (format-to-port port options format)
    (get-output-string port)))

(define (format-options . options)
  (reduce-right (lambda (option options)
                  (lambda (state)
                    (option (options state))))
                (format-null-option)
                options))

(define (format-null-option)
  (lambda (state)
    state))

(define (format-with-property key datum)
  (lambda (state)
    (format-state/insert-property state key datum)))

;;;; Format State

(define-record-type <format-state>
    (%make-format-state output-port properties)
    format-state?
  (output-port format-state/output-port)
  (properties format-state/properties))

(define (make-format-state output-port)
  (%make-format-state output-port '()))

(define (format-state-with-output-port state output-port)
  (%make-format-state output-port (format-state/properties state)))

(define (format-state/property state key)
  (assq key (format-state/properties state)))

(define (format-state/search-property state key if-found if-not-found)
  (cond ((format-state/property state key)
         => (lambda (property)
              (if-found (cdr property))))
        (else (if-not-found))))

(define (format-state/lookup-property state key default)
  (cond ((format-state/property state key) => cdr)
        (else default)))

;;;;; Editing Format State

(define (format-state/modify-properties state modifier)
  (%make-format-state (format-state/output-port state)
                      (modifier (format-state/properties state))))

(define (format-state/update-property state key if-found if-not-found)
  (format-state/modify-properties state
    (lambda (properties)
      (let recur ((properties properties))
        (if (pair? properties)
            (if (eq? key (caar properties))
                (if-found (cdar properties)
                          (lambda (datum)   ;Replace
                            (cons (cons key datum) (cdr properties)))
                          (lambda ()        ;Delete
                            (cdr properties)))
                (cons (car properties) (recur (cdr properties))))
            (if-not-found (lambda (datum)   ;Insert
                            (cons (cons key datum) '()))
                          (lambda ()        ;Ignore
                            '())))))))

(define (format-state/insert-property state key datum)
  (format-state/update-property state key
    (lambda (datum* replace delete)
      datum* delete                     ;ignore
      (replace datum))
    (lambda (insert ignore)
      ignore                            ;ignore
      (insert datum))))

(define (format-state/delete-property state key)
  (format-state/update-property state key
    (lambda (datum replace delete)
      datum replace                     ;ignore
      (delete))
    (lambda (insert ignore)
      insert                            ;ignore
      (ignore))))

(define (format-state/modify-property state key default modifier)
  (format-state/update-property state key
    (lambda (datum replace delete)
      delete                            ;ignore
      (replace (modifier datum)))
    (lambda (insert ignore)
      ignore                            ;ignore
      (insert (modifier default)))))

;;;;; Format-State Properties

(define (format-with-string-handler handler)
  (format-with-property 'STRING-HANDLER handler))

(define (format-state/string-handler state)
  (format-state/lookup-property state 'STRING-HANDLER default-string-handler))

(define default-string-handler
  (lambda (state string)
    (write-string string (format-state/output-port state))
    state))

(define (format-with-char-handler handler)
  (format-with-property 'CHAR-HANDLER handler))

(define (format-state/char-handler state)
  (format-state/lookup-property state
                                'CHAR-HANDLER
                                default-char-handler))

(define default-char-handler
  (lambda (state char)
    (write-char char (format-state/output-port state))
    state))

(define (format-with-display-handler handler)
  (format-with-property 'DISPLAY-HANDLER handler))

(define (format-state/display-handler state)
  (format-state/lookup-property state
                                'DISPLAY-HANDLER
                                default-display-handler))

(define default-display-handler
  (lambda (state object)
    (display object (format-state/output-port state))
    state))

;;;;; Breaks

(define (format-with-soft-break-handler handler)
  (format-with-property 'SOFT-BREAK-HANDLER handler))

(define (format-state/soft-break-handler state)
  (format-state/lookup-property state
                                'SOFT-BREAK-HANDLER
                                default-soft-break-handler))

(define default-soft-break-handler
  (lambda (state)
    (write-char #\space (format-state/output-port state))
    state))

(define (format-with-line-break-handler handler)
  (format-with-property 'LINE-BREAK-HANDLER handler))

(define (format-state/line-break-handler state)
  (format-state/lookup-property state
                                'LINE-BREAK-HANDLER
                                default-line-break-handler))

(define default-line-break-handler
  (lambda (state)
    (newline (format-state/output-port state))
    state))

(define (format-with-line-start-handler handler)
  (format-with-property 'LINE-START-HANDLER handler))

(define (format-state/line-start-handler state)
  (format-state/lookup-property state
                                'LINE-START-HANDLER
                                default-line-start-handler))

(define default-line-start-handler
  (lambda (state)
    (newline (format-state/output-port state))
    state))

;;;; Line Tracking

(define (format-with-line-tracking initial-line initial-column)
  (if (not (or initial-line initial-column))
      (error "No line or column to track!"))
  (format-options
   (if initial-line
       (format-with-property 'LINE initial-line)
       (format-null-option))
   (if initial-column
       (format-with-property 'COLUMN initial-column)
       (format-null-option))
   (format-with-property 'BROKEN? #f)
   (format-with-string-handler line-tracking-string-handler)
   (format-with-char-handler line-tracking-char-handler)
   (format-with-soft-break-handler line-tracking-soft-break-handler)
   (format-with-line-break-handler line-tracking-line-break-handler)
   (format-with-line-start-handler line-tracking-line-start-handler)))

(define (track-string-break state string)
  (let ((length (string-length string)))
    (if (> length 0)
        (track-char-break state (string-ref string (- length 1)))
        state)))

(define (track-char-break state char)
  (format-state/insert-property state 'BROKEN? (char-break? char)))

(define (line-tracking-string-handler state string)
  (write-string string (format-state/output-port state))
  (let ((state (track-string-break state string)))
    (let ((line (format-state/line state))
          (column (format-state/column state)))
      (cond ((and line column)
             (track-line-and-column state string line column))
            (line
             (track-line state string line))
            (column
             (track-column state string column))
            (else state)))))

(define (track-line-and-column state string line column)
  (let loop ((index 0) (line line) (column column))
    (cond ((string-search-line-break string index (string-length string))
           => (lambda (index*)
                (loop index* (+ line 1) 0)))
          (else
           (let* ((state (format-state/set-line state line))
                  (state ((lambda (column)
                            (format-state/set-column state column))
                          (+ column (- (string-length string) index)))))
             state)))))

(define (track-line state string line)
  (let loop ((index 0) (line line))
    (cond ((string-search-line-break string index (string-length string))
           => (lambda (index*)
                (loop index* (+ line 1))))
          (else
           (format-state/set-line state line)))))

(define (track-column state string column)
  (let loop ((index 0) (column column))
    (cond ((string-search-line-break string index (string-length string))
           => (lambda (index*)
                (loop index* 0)))
          (else
           ((lambda (column)
              (format-state/set-column state column))
            (+ column (- (string-length string)
                         index)))))))

(define (line-tracking-char-handler state char)
  (write-char char (format-state/output-port state))
  (let ((state (track-char-break state char)))
    (if (char-line-break? char)
        (format-state/reset-column (format-state/advance-line state))
        (format-state/advance-column state))))

(define (line-tracking-soft-break-handler state)
  (if (format-state/lookup-property state 'BROKEN? #f)
      state
      (let ((column (format-state/column state)))
        (if column
            (if (positive? column)
                (line-tracking-char-handler state #\space)
                state)
            (line-tracking-char-handler state #\space)))))

(define (line-tracking-line-break-handler state)
  (newline (format-state/output-port state))
  (format-state/reset-column (format-state/advance-line state)))

(define (line-tracking-line-start-handler state)
  (let ((line (format-state/line state))
        (column (format-state/column state)))
    (if column
        (if (positive? column)
            ((format-state/line-break-handler state) state)
            state)
        ((format-state/line-break-handler state) state))))

;;;;; Line and Column State

(define (format-state/line state)
  (format-state/lookup-property state 'LINE #f))

(define (format-state/set-line state line)
  (format-state/insert-property state 'LINE line))

(define (format-state/advance-line state)
  (format-state/update-property state 'LINE
    (lambda (line replace delete)
      delete                            ;ignore
      (replace (+ line 1)))
    (lambda (insert ignore)
      insert                            ;ignore
      (ignore))))

(define (format-state/column state)
  (format-state/lookup-property state 'COLUMN #f))

(define (format-state/set-column state column)
  (format-state/insert-property state 'COLUMN column))

(define (format-state/advance-column state)
  (format-state/update-property state 'COLUMN
    (lambda (column replace delete)
      delete                            ;ignore
      (replace (+ column 1)))
    (lambda (insert ignore)
      insert                            ;ignore
      (ignore))))

(define (format-state/reset-column state)
  (format-state/update-property state 'COLUMN
    (lambda (column replace delete)
      column delete                     ;ignore
      (replace 0))
    (lambda (insert ignore)
      insert                            ;ignore
      (ignore))))

;;;; Tabbing and Indentation

;++ Do something with the tab width...

(define (format-with-tab-width tab-width)
  (format-with-property 'TAB-WIDTH tab-width))

(define (format-state/tab-width state)
  (format-state/lookup-property state 'TAB-WIDTH 8))

(define (format-state/set-tab-width state tab-width)
  (format-state/update-property state 'TAB-WIDTH
    (lambda (tab-width* replace delete)
      tab-width* delete                 ;ignore
      (replace tab-width))
    (lambda (insert ignore)
      ignore                            ;ignore
      (insert tab-width))))

(define (format-with-indenter indenter)
  (format-with-property 'INDENTER indenter))

(define (format-state/indenter state)
  (format-state/lookup-property state 'INDENTER space-indenter))

(define space-indenter
  (lambda (amount)
    (format:string (make-string amount #\space))))

(define (format-with-indentation initial-indentation)
  (format-with-property 'INDENTATION initial-indentation))

(define (format-state/indentation state)
  (format-state/lookup-property state 'INDENTATION #f))

(define (format-state/set-indentation state indentation)
  (format-state/insert-property state 'INDENTATION indentation))

(define (format-state/adjust-indentation state adjustment)
  (format-state/update-property state 'INDENTATION
    (lambda (indentation replace delete)
      delete                            ;ignore
      (replace (+ indentation adjustment)))
    (lambda (insert ignore)
      insert                            ;ignore
      (ignore))))

;++ Implement a right margin, for soft breaks.  There should be a
;++ distinct right margin and break threshold -- or, well, what we
;++ really want is constraint propagation..

;;;; Condensed Whitespace

(define (format-with-condensed-whitespace)
  (format-options
   (format-with-property 'BROKEN? #t)
   (format-with-tab-width 1)
   (format-with-indenter condensed-indenter)
   (format-with-char-handler condensed-char-handler)
   (format-with-string-handler condensed-string-handler)
   (format-with-soft-break-handler condensed-soft-break-handler)
   (format-with-line-break-handler condensed-line-break-handler)
   (format-with-line-start-handler condensed-line-start-handler)))

(define (condensed-indenter amount)
  amount                                ;ignore
  (format:soft-break))

(define (condensed-char-handler state char)
  (write-char char (format-state/output-port state))
  (format-state/insert-property state 'BROKEN? (char-break? char)))

(define (condensed-string-handler state string)
  (if (zero? (string-length string))
      state
      (begin
        (write-string string (format-state/output-port state))
        (format-state/insert-property
         state
         'BROKEN?
         (char-break? (string-ref string (+ -1 (string-length string))))))))

(define (condensed-soft-break-handler state)
  (if (format-state/lookup-property state 'BROKEN? #f)
      state
      (begin
        (write-char #\space (format-state/output-port state))
        (format-state/insert-property state 'BROKEN? #t))))

(define (condensed-line-break-handler state)
  (if (not (format-state/lookup-property state 'BROKEN? #f))
      (begin
        (write-char #\space (format-state/output-port state))
        (format-state/insert-property state 'BROKEN? #t))
      state))

(define (condensed-line-start-handler state)
  (condensed-line-break-handler state))

;;;; Format Abstraction

;;; This page should be the only part of the formatting abstraction
;;; that knows that formats really are procedures.
;;;
;;; (This abstraction is rather weak, though; the existence of
;;; PROCEDURE->FORMAT implies that we are really not doing any sort of
;;; constraint propagation.)

(define (apply-format format state)
  (cond ((procedure? format)
         (format state))
        ((string? format)
         ((format-state/string-handler state) state format))
        ((char? format)
         ((format-state/char-handler state) state format))
        ((list? format)
         (for-each (lambda (subformat)
                     (apply-format subformat state))
                   format))
        (else
         (apply-format (format:display format) state))))

(define (format->procedure format)
  (cond ((procedure? format) format)
        ((string? format) (format:string format))
        ((char? format) (format:char format))
        ((list? format) (format:list format))
        (else (format:display format))))

(define (procedure->format procedure) procedure)

(define (canonicalize-format format)
  (procedure->format (format->procedure format)))

;;;; Basic Formatters

(define (format:empty)
  (procedure->format
   (lambda (state)
     state)))

(define (format:string string)
  (procedure->format
   (lambda (state)
     ((format-state/string-handler state) state string))))

(define (format:char char)
  (procedure->format
   (lambda (state)
     ((format-state/char-handler state) state char))))

(define (format:display object)
  (procedure->format
   (lambda (state)
     ((format-state/display-handler state) state object))))

(define (format:sequence . formats)
  (format:list formats))

(define (format:bracketed left-bracket right-bracket . formats)
  (format:bracketed-list left-bracket right-bracket formats))

(define (format:bracketed-list left-bracket right-bracket format-list)
  (format:sequence left-bracket
                   (format:list format-list)
                   right-bracket))

(define (format:call-with-output-port receiver)
  (procedure->format
   (lambda (state)
     ((format-state/string-handler state)
      state
      (let ((output-port (open-output-string)))
        (receiver output-port)
        (get-output-string output-port))))))

;;;; Formatting Lists

(define (format:list format-list)
  (procedure->format
   (reduce-map-right (lambda (first second)
                       (lambda (state)
                         (second (first state))))
                     format->procedure
                     (format->procedure (format:empty))
                     format-list)))

(define (format:join prefix infix suffix formats)
  (format:list
   (cons prefix
         (if (pair? formats)
             (if (pair? (cdr formats))
                 (let ((infix (canonicalize-format infix)))
                   (let loop ((in formats) (out '()))
                     (let ((in (cdr in))
                           (out (cons infix (cons (car in) out))))
                       (if (pair? (cdr in))
                           (loop in out)
                           (reverse (cons suffix (cons (car in) out)))))))
                 (cons (car formats) (cons suffix '())))
             (cons suffix '())))))

(define (format:join/infix infix formats)
  (format:list
   (if (and (pair? formats)
            (pair? (cdr formats)))
       (let ((infix (canonicalize-format infix)))
         (let loop ((in formats) (out '()))
           (let ((in (cdr in))
                 (out (cons infix (cons (car in) out))))
             (if (pair? (cdr in))
                 (loop in out)
                 (reverse (cons (car in) out))))))
       formats)))

(define (format:join/prefix prefix formats)
  (format:list
   (let ((prefix (canonicalize-format prefix)))
     (let loop ((in formats) (out '()))
       (if (pair? in)
           (loop (cdr in) (cons (car in) (cons prefix out)))
           (reverse out))))))

(define (format:join/suffix suffix formats)
  (format:list
   (let ((suffix (canonicalize-format suffix)))
     (let loop ((in formats) (out '()))
       (if (pair? in)
           (loop (cdr in) (cons suffix (cons (car in) out)))
           (reverse out))))))

;++ columnar

;;;; Lines & Breaks

(define (format:non-breaking-space)
  (format:char #\space))

(define (format:soft-break)
  (procedure->format
   (lambda (state)
     ((format-state/soft-break-handler state) state))))

(define (format:line-start)
  (procedure->format
   (lambda (state)
     ((format-state/line-start-handler state) state))))

(define (format:line-break)
  (procedure->format
   (lambda (state)
     ((format-state/line-break-handler state) state))))

(define (format:line . formats)
  (format:bracketed-list (format:line-start) (format:line-start) formats))

(define (format:indentation)
  (procedure->format
   (lambda (state)
     (cond ((format-state/indentation state)
            => (lambda (indentation)
                 (apply-format ((format-state/indenter state)
                                indentation)
                               state)))
           (else state)))))

(define (format:indented-line . formats)
  (format:line (format:indentation) (format:list formats)))

(define (format:with-indentation adjustment . formats)
  (format:with-updated-property 'INDENTATION
      (lambda (indentation replace delete)
        delete                          ;ignore
        (replace (+ indentation adjustment)))
      (lambda (insert ignore)
        insert                          ;ignore
        (ignore))
    (format:list formats)))

(define (format:with-alignment . formats)
  (procedure->format
   (lambda (state)
     ((lambda (body)
        (format-state/search-property state 'INDENTATION
          (lambda (indentation)
            (format-state/insert-property (body) 'INDENTATION indentation))
          (lambda ()
            (format-state/delete-property (body) 'INDENTATION))))
      (lambda ()
        (apply-format (format:list formats)
                      (cond ((format-state/column state)
                             => (lambda (column)
                                  (format-state/set-indentation state column)))
                            (else state))))))))

;;;; Capturing and Dynamic State

(define (format:capturing* format receiver)
  (procedure->format
   (lambda (state)
     (let* ((port (open-output-string))
            (redirected-state (format-state-with-output-port state port))
            (post-state (apply-format format redirected-state))
            (output (get-output-string port))
            (format* (receiver output post-state)))
       (apply-format format* state)))))

(define (format:capturing format receiver)
  (format:capturing* format
    (lambda (output post-state)
      post-state                        ;ignore
      (receiver output))))

;;; Unfortunately, the UPDATE signature does not allow for this to be
;;; done in a nice way, because the call to REPLACE or DELETE must be
;;; in a tail position, so there is no way to modify the state *and* to
;;; branch the enclosing control flow; thus, we must use SEARCH.

(define (format:with-updated-property key if-found if-not-found format)
  (lambda (state)
    (format-state/search-property state key
      (lambda (original-datum)
        (let* ((updated-state
                (if-found original-datum
                          (lambda (datum)
                            (format-state/insert-property state key datum))
                          (lambda ()
                            (format-state/delete-property state key))))
               (post-state (apply-format format updated-state)))
          (format-state/insert-property post-state key original-datum)))
      (lambda ()
        (let* ((updated-state
                (if-not-found (lambda (datum)
                                (format-state/insert-property state key datum))
                              (lambda () state)))
               (post-state (apply-format format updated-state)))
          (format-state/delete-property post-state key))))))

(define (format:with-modified-property key default modifier format)
  (format:with-updated-property key
      (lambda (datum replace delete)
        delete                          ;ignore
        (replace (modifier datum)))
      (lambda (insert ignore)
        ignore                          ;ignore
        (insert (modifier default)))
    format))

(define (format:with-property key datum format)
  (format:with-modified-property key
      datum                             ;This is really a dummy.
      (lambda (original-datum)
        original-datum                  ;ignore
        datum)
    format))

(define (format:search-property key if-found if-not-found)
  (procedure->format
   (lambda (state)
     (apply-format
      (format-state/search-property state key if-found if-not-found)
      state))))

(define (format:lookup-property key . default)
  (procedure->format
   (lambda (state)
     (apply-format
      (format-state/lookup-property state key (format:list default))
      state))))

;;;; Numbers

;++ Add format state for current radix.
;++ Implement precision, style, other cruft, mumble mumble mumble...

(define (format:number number)
  (format:string (number->string number)))

(define (format:number-with-radix number radix)
  (format:string (number->string number radix)))

;;;; Building Custom Formats

(define (format:delayed thunk)
  (procedure->format
   (let ()
     (define (format state)
       (set! format
             (canonicalize-format
              (let ((format (thunk)))
                (set! thunk #f)
                format)))
       (format state))
     (lambda (state)
       (format state)))))

;++ insert tracing cruft

(define (format:named name format)
  (procedure->format
   (lambda (state)
     (no-op name)
     (apply-format format state))))

(define-syntax named-format
  (syntax-rules ()
    ((NAMED-FORMAT name format)
     ;; Try our hardest to associate the name with debugging
     ;; information: name both lambdas here, and put it in their
     ;; environments.
     (LET* ((THE-NAME 'name)
            (THE-FORMAT
             (FORMAT:DELAYED
              (LETREC ((name (LAMBDA () (NO-OP THE-NAME) format)))
                name))))
       (DEFINE (name STATE)
         (NO-OP THE-NAME)
         (APPLY-FORMAT THE-FORMAT STATE))
       (PROCEDURE->FORMAT name)))))

(define-syntax define-format
  (syntax-rules ()
    ((DEFINE-FORMAT (name . bvl) format)
     (DEFINE (name . bvl)
       (NAMED-FORMAT name format)))
    ((DEFINE-FORMAT name format)
     (DEFINE name
       (NAMED-FORMAT name format)))))

;;;; Random Utilities

(define (reduce-right operator identity list)
  (if (pair? list)
      (fold-right operator (car list) (cdr list))
      identity))

(define (reduce-map-right operator mapper identity list)
  (if (pair? list)
      (let recur ((list list))
        (if (pair? (cdr list))
            (operator (mapper (car list))
                      (recur (cdr list)))
            (mapper (car list))))
      identity))

(define (fold-right combiner base-case list)
  (if (pair? list)
      (combiner (car list) (fold-right combiner base-case (cdr list)))
      base-case))

(define (fold-map-right combiner mapper base-case list)
  (if (pair? list)
      (combiner (mapper (car list))
                (fold-map-right combiner mapper base-case (cdr list)))
      base-case))
