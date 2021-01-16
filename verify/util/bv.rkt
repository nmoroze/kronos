#lang rosette/safe

(require (prefix-in ! (only-in racket/base build-list)))

(provide build-zero-vector bvwidth vector->bv)

; Bitvector utilities

(define (build-zero-vector width depth)
  (list->vector (!build-list depth (lambda (_) (bv 0 width)))))

(define (bvwidth b)
  (length (bitvector->bits b)))

(define (vector->bv v)
  (define l (vector->list v))
  (foldl concat (first l) (rest l)))
