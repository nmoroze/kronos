#lang racket/base

(require rackunit)

(require "deterministic-start.rkt"
         "output-equivalence.rkt"
         "../util/time.rkt")

(define (verify-core-all)
  (define-values (success? final-state final-allowed-deps)
    (verify-core-det-start))
  (check-true success?)
  (check-true (verify-core-output-eqv-step))
  (check-true (verify-core-output-eqv-base final-state final-allowed-deps)))

(module+ main
  (define-values (_ t)
    (time (verify-core-all)))
  (printf "Core fully verified in ~as~n" (fmt-time t)))
