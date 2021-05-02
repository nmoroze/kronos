#lang rosette/safe

(require
 (prefix-in ! (combine-in (only-in racket/base for/list)
                          (only-in racket/set list->seteq seteq)))
 (only-in yosys get-field update-fields)
 rosutil)

(require
 "../clock-domains.rkt"
 (only-in
  "../../opentitan.rkt"
  new-symbolic-top_earlgrey_s
  new-zeroed-top_earlgrey_s
  top_earlgrey_t)
 "../util/circuit.rkt"
 "../util/rosette.rkt")

(provide verify-peripheral-output-determinism)

(define (get-outputs state outputs)
    (!for/list ([output outputs])
               ((cdr output) state)))

(define (verify-peripheral-output-determinism
  #:make-spec make-spec  ; yosys-module? => yosys-module?
  #:rel rel ; yosys-module? yosys-module? => boolean?
  #:inputs inputs ; (listof (or/c symbol (pair/c symbol any)))
  #:registers registers ; (listof symbol)
  #:outputs outputs ; (listof (pair/c symbol proc))
  )

  (define (verify-base-case)
    (define impl-init (new-init-soc))
    (define spec-init (make-spec impl-init))

    (define impl-outputs (get-outputs impl-init outputs))
    (define spec-outputs (get-outputs spec-init outputs))

    (define assertion (and (rel impl-init spec-init)
                           (equal? impl-outputs spec-outputs)))

    (define res (verify (assert assertion)))

    ; Output determinism base case: show that initial spec state and outputs are
    ; deterministic (no dependence on symbolics)
    (define deterministic-state
      (values-only-depend-on (get-fields spec-init registers) (!seteq)))

    (define deterministic-output
      (values-only-depend-on spec-outputs (!seteq)))

    (and (unsat? res)
         deterministic-state
         deterministic-output))

  (define (verify-inductive-step
           #:debug [debug #f])
    (define impl-pre (new-symbolic-top_earlgrey_s))
    (define spec-pre (new-symbolic-top_earlgrey_s))

    (define some-input (make-input inputs))

    (define impl* (step impl-pre some-input registers))
    (define spec* (step spec-pre some-input registers))

    (define post-input (make-input inputs))

    (define impl-post (update-fields impl* post-input))
    (define spec-post (update-fields spec* post-input))

    (define impl-outputs (get-outputs impl-post outputs))
    (define spec-outputs (get-outputs spec-post outputs))

    (define assumption (rel impl-pre spec-pre))
    (define assertion (and
                       (rel impl-post spec-post)
                       (equal? impl-outputs spec-outputs)))

    (define res (verify (begin (assume assumption)
                               (assert assertion))))

    ; Output determinism: show that the post-step spec state and outputs solely
    ; depend on the previous spec state and the inputs.
    (define deterministic-state
      (values-only-depend-on (get-fields spec-post registers)
                             (!list->seteq (append (symbolics spec-pre)
                                                   (symbolics some-input)
                                                   (symbolics post-input)))))
    (define deterministic-output
      (values-only-depend-on spec-outputs
                             (!list->seteq (append (symbolics spec-pre)
                                                   (symbolics some-input)
                                                   (symbolics post-input)))))
    (when (and (sat? res) debug)
      (define impl-post-concrete (evaluate impl-post res))
      (define spec-post-concrete (evaluate spec-post res))
      (printf "rel? ~a~n"(rel impl-post-concrete spec-post-concrete)))

    (and (unsat? res)
         deterministic-state
         deterministic-output))

  (define (verify-all)
    (define base-res (verify-base-case))
    (define step-res (verify-inductive-step))
    (and base-res step-res (vc-assumes (vc))))

  (verify-all))
