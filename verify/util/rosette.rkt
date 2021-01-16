#lang racket/base

(require
 (only-in racket/set set->list set-subtract)
 (prefix-in @ (combine-in rosette/safe rosutil))
 yosys/parameters
 (only-in yosys get-field update-fields))

; General utility code related to Rosette and Yosys, a la rtl/rosutil

(provide values-only-depend-on overapproximate get-fields print-state names->getters)

(define (values-only-depend-on values symbolics [invariant #t])
  (for/and ([i (in-naturals)]
            [v values])
    (let ([r (@unsat? (only-depends-on* v symbolics invariant))])
      (unless r
        (printf "idx ~a failed: ~a~n" i (set-subtract (@symbolics v) (set->list symbolics)))) r)))

(define (only-depends-on* value symbolics invariant)
  (if (not (vector? value))
      (@only-depends-on/unchecked value symbolics #:invariant invariant)
      (let ()
        (define any-failed
          (for/or ([v value])
            (define r (@only-depends-on/unchecked v symbolics #:invariant invariant))
            (if (@unsat? r) #f r)))
        (if (not any-failed)
            (@unsat)
            any-failed))))

(define (overapproximate s fields)
  (define updates
    (for/list ([i fields])
               (define v (get-field s i))
               (define v* (if (vector? v)
                              (@fresh-memory-like i v)
                              (@fresh-symbolic i (@type-of v))))
               (cons i v*)))
  (update-fields s updates))

(define (get-fields s fields)
  (for/list ([field fields])
    (get-field s field)))

(define (print-state s regs)
  (define to-output (map symbol->string regs))
  (parameterize ([field-filter (apply filter/or to-output)])
    (printf "~v~n" s)))

(define (names->getters names)
  (for/list ([name names])
    (cons name (lambda (s) (get-field s name)))))
