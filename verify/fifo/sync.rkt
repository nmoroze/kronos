#lang rosette/safe

(require
 (prefix-in ! (combine-in (only-in racket/base for/list log raise-argument-error)
                          (only-in racket/math exact-ceiling)))
 rackunit
 rosutil
 (only-in yosys/lib select store)
 (only-in yosys get-field update-field update-fields))

(require
 "common.rkt"
 "../util/bv.rkt"
 "../util/rosette.rkt")

(provide verify-prim-fifo-sync)

(struct input (clr_i wdata wvalid rready)
  #:transparent)

(struct output (depth rdata rvalid wready)
  #:transparent)

(define non-reset-registers '(gen_normal_fifo.storage))

(define (clog2 x)
  (!exact-ceiling (!log x 2)))

(define (verify-prim-fifo-sync new-symbolic-fifo_s fifo_t registers outputs width depth)
  ; use contract?
  (unless (> depth 1)
    (!raise-argument-error
     'verify-prim-fifo-sync
     "number greater than 1 for depth"
     depth))

  ; parameterized in prim_fifo_sync.sv
  (define ptr-width (add1 (clog2 depth)))

  ; set parameters for FIFO util library
  (fifo-ptr-width ptr-width)
  (fifo-max-depth (bv depth ptr-width))

  (define (fresh-symbolic-input)
    (input (fresh-symbolic 'clr_i boolean?)
           (fresh-symbolic 'wdata (bitvector width))
           (fresh-symbolic 'wvalid boolean?)
           (fresh-symbolic 'rready boolean?)))

  ; step is same for spec and impl
  (define (step state input)
    (define with-inputs
      (update-fields state
                     (list (cons 'rst_ni #t)
                           (cons 'clr_i (input-clr_i input))
                           (cons 'wdata (input-wdata input))
                           (cons 'wvalid (input-wvalid input))
                           (cons 'rready (input-rready input)))))
    (fifo_t with-inputs))

  (define (reset state)
    (define with-reset
      (update-field state 'rst_ni #f))
    (overapproximate (fifo_t with-reset) non-reset-registers))

  (define (get-output state)
    (!for/list ([output outputs])
               ((cdr output) state)))

  (define (get-live-storage state)
    (define storage (get-field state 'gen_normal_fifo.storage))

    (define ptr-start (get-field state 'gen_normal_fifo.fifo_rptr))
    (define ptr-end   (get-field state 'gen_normal_fifo.fifo_wptr))
    (let loop ([rptr ptr-start]
               [acc '()]
               [fuel depth])
      (if (or (bveq rptr ptr-end) (eq? fuel 0))
          acc
          (let* ([i (ptr-idx rptr)]
                 [value (select storage i)])
            (loop (inc-ptr rptr) (cons value acc) (sub1 fuel))))))

  (define (get-regs state)
    (!for/list ([reg registers])
               ((cdr reg) state)))

  ; invariant that rptr and wptr have valid values (must be < depth)
  (define (invariant state)
    (define rptr (get-field state 'gen_normal_fifo.fifo_rptr))
    (define wptr (get-field state 'gen_normal_fifo.fifo_wptr))

    (and (bvult (ptr-val rptr) (fifo-max-depth))
         (bvult (ptr-val wptr) (fifo-max-depth))))

  (define (rel impl spec)
    (define impl-regs (get-regs impl))
    (define spec-regs (get-regs spec))

    ; for two states to be related, they must share all the same registers and the
    ; live portions of their 'storage' memory must be equivalent. this circuit
    ; contains no other memories.
    (and
     (invariant impl)
     (invariant spec)
     (equal? impl-regs spec-regs)
     (equal? (get-live-storage impl) (get-live-storage spec))))

  ; verification
  (define (verify-base-case)
    (define impl-init (reset (new-symbolic-fifo_s)))
    (define spec-init (update-field impl-init 'gen_normal_fifo.storage
                                    (build-zero-vector
                                     width
                                     (vector-length (get-field impl-init 'gen_normal_fifo.storage)))))

    (define impl-output (get-output impl-init))
    (define spec-output (get-output spec-init))

    (define res (verify (assert (and (rel impl-init spec-init)
                                     (equal? impl-output spec-output)))))

    (unsat? res))

  (define (verify-inductive-step)
    (define impl-pre (new-symbolic-fifo_s))
    (define spec-pre (new-symbolic-fifo_s))
    (define some-input (fresh-symbolic-input))
    (define impl-post (step impl-pre some-input))
    (define spec-post (step spec-pre some-input))
    (define impl-output (get-output impl-post))
    (define spec-output (get-output spec-post))

    (define res (verify
                 (begin
                   (assume (rel impl-pre spec-pre))
                   (assert
                    (and (rel impl-post spec-post)
                         (equal? impl-output spec-output))))))

    (unsat? res))

  (displayln "Checking base case...")
  (check-true (verify-base-case) "Failed to verify base case!")
  (displayln "Checking inductive step...")
  (check-true (verify-inductive-step) "Failed to verify inductive step!")

  (check-true (vc-assumes (vc))))

;; (module+ main
;;   (require "prim_fifo_sync_16_3.rkt")
;;   (verify-prim-fifo-sync
;;    new-symbolic-prim_fifo_sync_s
;;    prim_fifo_sync_t
;;    registers
;;    outputs
;;    16
;;    3))
