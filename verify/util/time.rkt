#lang racket/base

(require racket/format)
(require racket/function)
(require syntax/parse/define)

; Timing utilities, mostly based off rtl/shiva

(provide fmt-time just-time time)

(define (time* thunk)
  (define start (current-inexact-milliseconds))
  (define value (thunk))
  (define end (current-inexact-milliseconds))
  (values value (- end start)))

(define (just-time thunk)
  (define start (current-inexact-milliseconds))
  (define value (thunk))
  (define end (current-inexact-milliseconds))
  (- end start))

; take in time in ms and return time in seconds to 1 decimal place
(define (fmt-time time-ms)
  (~r (/ time-ms 1000) #:precision 1))

(define-simple-macro (time body ...)
  (time* (thunk body ...)))
