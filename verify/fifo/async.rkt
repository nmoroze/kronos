#lang rosette/safe

(require
 (prefix-in ! (combine-in (only-in racket/base
                                           for for/list hash-ref hash-set! hash-update! log
                                           make-hash parameterize struct-copy symbol->string)
                          (only-in racket/math exact-ceiling)
                          (only-in racket/string string-split)))
 rackunit
 rosutil
 (only-in yosys/lib select store)
 (only-in yosys get-field update-field update-fields))

(require "common.rkt"
         "../util/bv.rkt"
         "../util/rosette.rkt")

(provide verify-prim-fifo-async)

(define non-reset-registers
  '(
    storage_rest$0#data_q
    storage_rest$0#addr_q
    storage_rest$0#en_q
    storage_rest#0
    storage_rest#final
    ))

(define (clog2 x)
  (!exact-ceiling (!log x 2)))

(define (verify-prim-fifo-async new-symbolic-fifo_s fifo_t fix-mem registers
                                outputs width depth)
  (struct input (wvalid wdata rready)
    #:transparent)

  (struct output (wready wdepth rvalid rdata rdepth)
    #:transparent)

  ; parameterized in prim_fifo_async.sv
  (define ptr-width (add1 (clog2 depth)))

  ; set parameters for FIFO util library
  (fifo-ptr-width ptr-width)
  (fifo-max-depth (bv depth ptr-width))

  (define (fresh-symbolic-input)
    (input (fresh-symbolic 'wvalid boolean?)
           (fresh-symbolic 'wdata (bitvector width))
           (fresh-symbolic 'rready boolean?)))

  (define (reset state)
    (define with-reset
      (update-fields (fix-mem state)
                    (list (cons 'rst_rd_ni (bv 0 1))
                          (cons 'rst_wr_ni  (bv 0 1))
                          (cons 'clk_rd_i   #f)
                          (cons 'clk_wr_i   #f))))
      (overapproximate (fifo_t with-reset) non-reset-registers))

  (define (step state input #:clk-rd [clk-rd #t] #:clk-wr [clk-wr #t])
    (define with-inputs
      (update-fields (fix-mem state)
                     (list (cons 'rst_rd_ni (bv 1 1))
                           (cons 'rst_wr_ni (bv 1 1))
                           (cons 'clk_rd_i #f)
                           (cons 'clk_wr_i #f)
                           (cons 'wvalid  (input-wvalid input))
                           (cons 'wdata   (input-wdata  input))
                           (cons 'rready  (input-rready input)))))
    (define with-inputs* (fifo_t with-inputs))
    (define step-clk
      (update-fields (fix-mem with-inputs*)
                     (list (cons 'rst_rd_ni (bv 1 1))
                           (cons 'rst_wr_ni (bv 1 1))
                           (cons 'clk_rd_i clk-rd)
                           (cons 'clk_wr_i clk-wr))))
    (fix-mem (fifo_t step-clk)))

  (define (get-output state)
    (!for/list ([output outputs])
               ((cdr output) state)))

  ; Special version of select for use in get-live-storage: since the width of
  ; the "storage_rest" memory is Depth-1, and the pointer index is clog2(Depth),
  ; we might run into indexing issues where the index is too wide if Depth is a
  ; power of 2. We check for this case here, and truncate the index if needed --
  ; this shouldn't cause problems since we know the index should only be a legal
  ; value.
  (define (select* storage bvidx)
    (if (< (clog2 (vector-length storage)) (clog2 depth))
        (select storage (extract (sub1 (clog2 (vector-length storage))) 0 bvidx))
        (select storage bvidx)))

  (define (get-live-storage state)
    (define storage_first (get-field state 'storage_first#past_q_wire))
    (define storage_rest (get-field state 'storage_rest#0))

    (define ptr-start (get-field state 'fifo_rptr_sync#past_q_wire))
    (define ptr-end   (get-field state 'fifo_wptr#past_q_wire))
    (let loop ([rptr ptr-start]
               [acc '()]
               [fuel depth])
      (if (or (bveq rptr ptr-end) (eq? fuel 0))
          acc
          (let* ([i (ptr-idx rptr)]
                 [value (if (bvzero? i)
                            storage_first
                            (select* storage_rest (bvsub1 i)))])
            (loop (inc-ptr rptr) (cons value acc) (sub1 fuel))))))

  (define (get-regs state)
    (!for/list ([reg registers])
               ((cdr reg) state)))

  (define (rel impl spec)
    (define impl-regs (get-regs impl))
    (define spec-regs (get-regs spec))

    ; for two states to be related, they must share all the same registers and the
    ; live portions of their 'storage' memory must be equivalent. this circuit
    ; contains no other memories.
    (and
     (equal? impl-regs spec-regs)
     (equal? (get-live-storage impl) (get-live-storage spec))))

  (define (invariant state) (and
                             (invariant-fifo state)
                             (invariant-rst-edge-detect state)))

  (define (invariant-rst-edge-detect state)
    ; assumes reset inputs tied together
    (define past-rsts (filter
                       (lambda (r)
                         (let ([pieces (!string-split (!symbol->string (car r)) "#")])
                           (and (= (length pieces) 3) (equal? (second pieces) "past_arst"))))
                       registers))
    (define val ((cdr (first past-rsts)) state))
    (foldl (lambda (a b) (and a b)) #t
           (!for/list ([rst (rest past-rsts)])
                      (equal? val ((cdr rst) state)))))

  (define (legal-ptr ptr)
    (bvult (ptr-val ptr) (fifo-max-depth)))

  (define (invariant-fifo state)
    (define fifo-wptr#q (get-field state 'fifo_wptr#past_q_wire))
    (define fifo-wptr#d (get-field state 'fifo_wptr#past_d_wire))
    (define fifo-rptr-sync#q (get-field state 'fifo_rptr_sync#past_q_wire))
    (define fifo-rptr-sync#d (get-field state 'fifo_rptr_sync#past_d_wire))
    (define sync-rptr.q#q (gray2dec (get-field state 'sync_rptr.q#past_q_wire)))
    (define sync-rptr.q#d (gray2dec (get-field state 'sync_rptr.q#past_d_wire)))
    (define sync-rptr.intq#q (gray2dec (get-field state 'sync_rptr.intq#past_q_wire)))
    (define sync-rptr.intq#d (gray2dec (get-field state 'sync_rptr.intq#past_d_wire)))
    (define fifo-rptr-gray#q (gray2dec (get-field state 'fifo_rptr_gray#past_q_wire)))
    (define fifo-rptr-gray#d (gray2dec (get-field state 'fifo_rptr_gray#past_d_wire)))
    (define sync-wptr.q#q (gray2dec (get-field state 'sync_wptr.q#past_q_wire)))
    (define sync-wptr.q#d (gray2dec (get-field state 'sync_wptr.q#past_d_wire)))
    (define sync-wptr.intq#q (gray2dec (get-field state 'sync_wptr.intq#past_q_wire)))
    (define sync-wptr.intq#d (gray2dec (get-field state 'sync_wptr.intq#past_d_wire)))

    (define depth-fifo-wptr#q      (fifo-depth fifo-wptr#q fifo-wptr#d))
    (define depth-fifo-rptr-sync#d (fifo-depth fifo-rptr-sync#d fifo-wptr#d))
    (define depth-fifo-rptr-sync#q (fifo-depth fifo-rptr-sync#q fifo-wptr#d))
    (define depth-sync-rptr.q#d    (fifo-depth sync-rptr.q#d fifo-wptr#d))
    (define depth-sync-rptr.q#q    (fifo-depth sync-rptr.q#q fifo-wptr#d))
    (define depth-sync-rptr.intq#d (fifo-depth sync-rptr.intq#d fifo-wptr#d))
    (define depth-sync-rptr.intq#q (fifo-depth sync-rptr.intq#q fifo-wptr#d))
    (define depth-fifo-rptr-gray#d (fifo-depth fifo-rptr-gray#d fifo-wptr#d))
    (define depth-fifo-rptr-gray#q (fifo-depth fifo-rptr-gray#q fifo-wptr#d))
    (define depth-sync-wptr.q#d    (fifo-depth sync-wptr.q#d fifo-wptr#d))
    (define depth-sync-wptr.q#q    (fifo-depth sync-wptr.q#q fifo-wptr#d))
    (define depth-sync-wptr.intq#d (fifo-depth sync-wptr.intq#d fifo-wptr#d))
    (define depth-sync-wptr.intq#q (fifo-depth sync-wptr.intq#q fifo-wptr#d))

    (and
     ; pointers must have valid values to relative to each other
     (bvuge (fifo-max-depth)       depth-fifo-rptr-sync#q)
     (bvuge depth-fifo-rptr-sync#q depth-sync-rptr.q#q)
     (bvuge depth-sync-rptr.q#q    depth-sync-rptr.intq#q)
     (bvuge depth-sync-rptr.intq#q depth-fifo-rptr-gray#q)
     (bvuge depth-fifo-rptr-gray#q depth-sync-wptr.q#q)
     (bvuge depth-sync-wptr.q#q    depth-sync-wptr.intq#q)
     (bvuge depth-sync-wptr.intq#q depth-fifo-wptr#q)

     ; all pointer values must be "legal"
     (legal-ptr fifo-wptr#q)
     (legal-ptr fifo-wptr#d)
     (legal-ptr fifo-rptr-sync#q)
     (legal-ptr fifo-rptr-sync#d)
     (legal-ptr sync-rptr.q#q)
     (legal-ptr sync-rptr.q#d)
     (legal-ptr sync-rptr.intq#q)
     (legal-ptr sync-rptr.intq#d)
     (legal-ptr fifo-rptr-gray#q)
     (legal-ptr fifo-rptr-gray#d)
     (legal-ptr sync-wptr.q#q)
     (legal-ptr sync-wptr.q#d)
     (legal-ptr sync-wptr.intq#q)
     (legal-ptr sync-wptr.intq#d)

     ; gray-valued pointers should always be kept up to date with "normal" values
     (bveq
      fifo-wptr#q
      (gray2dec (get-field state 'fifo_wptr_gray#past_q_wire)))
     (bveq
      fifo-wptr#d
      (gray2dec (get-field state 'fifo_wptr_gray#past_d_wire)))
     (bveq
      (get-field state 'fifo_rptr#past_q_wire)
      fifo-rptr-gray#q)
     (bveq
      (get-field state 'fifo_rptr#past_d_wire)
      fifo-rptr-gray#d)
     ))

  (define (verify-base-case)
    (define impl-init (reset (new-symbolic-fifo_s)))
    (define spec-init (update-field impl-init 'storage_rest#0 (build-zero-vector width (vector-length (get-field impl-init 'storage_rest#0)))))
    (define res (verify (assert (and (rel impl-init spec-init)
                                     (equal? (get-output impl-init)
                                             (get-output spec-init))
                                     (invariant impl-init)
                                     (invariant spec-init)))))
    (define r (unsat? res))
    (unless r
      (define complete-soln (complete-solution res (append (symbolics impl-init)
                                                           (symbolics spec-init))))
      (define impl-conc (evaluate impl-init complete-soln))
      (define spec-conc (evaluate spec-init complete-soln))
      (printf "outputs equal? ~a~n" (equal? (get-output impl-conc)
                                            (get-output spec-conc)))
      (printf "impl and spec related? ~a~n" (rel impl-conc spec-conc))
      (printf "invariant impl: ~a~n" (invariant impl-conc))
      (printf "invariant spec: ~a~n" (invariant spec-conc)))
    r)

  (define (verify-inductive-step clk-rd clk-wr)
    (define impl-pre (new-symbolic-fifo_s))
    (define spec-pre (new-symbolic-fifo_s))
    (define some-input (fresh-symbolic-input))
    (define impl-post (step impl-pre some-input #:clk-rd clk-rd #:clk-wr clk-wr))
    (define spec-post (step spec-pre some-input #:clk-rd clk-rd #:clk-wr clk-wr))

    (define res (verify
                 (begin
                   (assume (and (rel impl-pre spec-pre)
                                (equal? (get-output impl-post) (get-output spec-post))
                                (invariant impl-pre)
                                (invariant spec-pre)))
                   (assert (and (invariant impl-post)
                                (invariant spec-post)
                                (equal? (get-output impl-post) (get-output spec-post))
                                (rel impl-post spec-post))))))
    (define r (unsat? res))
    (unless r
      (define complete-soln (complete-solution res (append (symbolics impl-pre)
                                                           (symbolics spec-pre)
                                                           (symbolics some-input)
                                                           (symbolics impl-post)
                                                           (symbolics spec-post))))
      (define impl-pre-conc (evaluate impl-pre complete-soln))
      (define spec-pre-conc (evaluate spec-pre complete-soln))
      (define input-conc (evaluate some-input complete-soln))
      (define impl-post-conc (evaluate impl-post complete-soln))
      (define spec-post-conc (evaluate spec-post complete-soln))
      (define output-equal (equal? (get-output impl-post-conc) (get-output spec-post-conc)))
      (printf "outputs equal? ~a~n" output-equal)
      (printf "spec and impl related? ~a~n" (rel spec-post-conc  impl-post-conc))
      (printf "impl invariant maintained? ~a~n" (invariant impl-post-conc))
      (printf "spec invariant maintained? ~a~n" (invariant spec-post-conc))
      (define inv-fifo (invariant-fifo impl-post-conc))
      (printf "invariant fifo? ~a~n" inv-fifo)
      (printf "impl-pre: ~v~n" impl-pre-conc)
      (printf "spec-pre: ~v~n" spec-pre-conc)
      (printf "input: ~v~n" input-conc)
      (printf "impl-post: ~v~n" impl-post-conc)
      (printf "spec-post: ~v~n" spec-post-conc)

      (unless output-equal
        (define impl-outputs (get-output impl-post-conc))
        (define spec-outputs (get-output spec-post-conc))
        (displayln impl-outputs)
        (displayln spec-outputs)

        ;; (define impl-wready (output-wready impl-outputs))
        ;; (define spec-wready (output-wready spec-outputs))
        ;; (unless (equal? impl-wready spec-wready)
        ;;   (printf "wready: ~a != ~a ~n" impl-wready spec-wready))

        ;; (define impl-wdepth (output-wdepth impl-outputs))
        ;; (define spec-wdepth (output-wdepth spec-outputs))
        ;; (unless (equal? impl-wdepth spec-wdepth)
        ;;   (printf "wdepth: ~a != ~a ~n" impl-wdepth spec-wdepth))

        ;; (define impl-rvalid (output-rvalid impl-outputs))
        ;; (define spec-rvalid (output-rvalid spec-outputs))
        ;; (unless (equal? impl-rvalid spec-rvalid)
        ;;   (printf "rvalid: ~a != ~a ~n" impl-rvalid spec-rvalid))

        ;; (define impl-rdata (output-rdata impl-outputs))
        ;; (define spec-rdata (output-rdata spec-outputs))
        ;; (unless (equal? impl-rdata spec-rdata)
        ;;   (printf "rdata: ~a != ~a ~n" impl-rdata spec-rdata))

        ;; (define impl-rdepth (output-rdepth impl-outputs))
        ;; (define spec-rdepth (output-rdepth spec-outputs))
        ;; (unless (equal? impl-rdepth spec-rdepth)
        ;;   (printf "rdepth: ~a != ~a ~n" impl-rdepth spec-rdepth))
        )

      (displayln "Relevant state:")
      (printf "fifo-rptr-sync#q [wr] - ~a => ~a ~n"
              (get-field impl-pre-conc 'fifo_rptr_sync#past_q_wire)
              (get-field impl-post-conc 'fifo_rptr_sync#past_q_wire))

      (printf "fifo-rptr-sync#d [wr] - ~a => ~a ~n"
              (get-field impl-pre-conc 'fifo_rptr_sync#past_d_wire)
              (get-field impl-post-conc 'fifo_rptr_sync#past_d_wire))
      (printf "fifo-depth: ~a~n" (fifo-depth
                                  (get-field impl-post-conc 'fifo_rptr_sync#past_q_wire)
                                  (get-field impl-post-conc 'fifo_wptr#past_d_wire)))
      (printf "sync-rptr.q#q    [wr] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'sync_rptr.q#past_q_wire))
              (gray2dec (get-field impl-post-conc 'sync_rptr.q#past_q_wire)))

      (printf "sync-rptr.q#d    [wr] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'sync_rptr.q#past_d_wire))
              (gray2dec (get-field impl-post-conc 'sync_rptr.q#past_d_wire)))
      (printf "fifo-depth: ~a~n" (fifo-depth
                                  (gray2dec (get-field impl-post-conc 'sync_rptr.q#past_q_wire))
                                  (get-field impl-post-conc 'fifo_wptr#past_d_wire)))

      (printf "sync-rptr.intq#q [wr] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'sync_rptr.intq#past_q_wire))
              (gray2dec (get-field impl-post-conc 'sync_rptr.intq#past_q_wire)))

      (printf "sync-rptr.intq#d [wr] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'sync_rptr.intq#past_d_wire))
              (gray2dec (get-field impl-post-conc 'sync_rptr.intq#past_d_wire)))

      (printf "rptr#q           [rd] - ~a => ~a ~n"
              (get-field impl-pre-conc 'fifo_rptr#past_q_wire)
              (get-field impl-post-conc 'fifo_rptr#past_q_wire))

      (printf "rptr#d           [rd] - ~a => ~a ~n"
              (get-field impl-pre-conc 'fifo_rptr#past_d_wire)
              (get-field impl-post-conc 'fifo_rptr#past_d_wire))

      (printf "fifo-depth: ~a~n" (fifo-depth
                                  (get-field impl-post-conc 'fifo_rptr#past_q_wire)
                                  (get-field impl-post-conc 'fifo_wptr#past_d_wire)))

      (printf "rptr-gray#q      [rd] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'fifo_rptr_gray#past_q_wire))
              (gray2dec (get-field impl-post-conc 'fifo_rptr_gray#past_q_wire)))

      (printf "rptr-gray#d      [rd] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'fifo_rptr_gray#past_d_wire))
              (gray2dec (get-field impl-post-conc 'fifo_rptr_gray#past_d_wire)))

      (printf "sync_wptr.q#q    [rd] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'sync_wptr.q#past_q_wire))
              (gray2dec (get-field impl-post-conc 'sync_wptr.q#past_q_wire)))


      (printf "sync_wptr.q#d    [rd] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'sync_wptr.q#past_d_wire))
              (gray2dec (get-field impl-post-conc 'sync_wptr.q#past_d_wire)))

      (printf "fifo-depth: ~a~n" (fifo-depth
                                  (gray2dec (get-field impl-post-conc 'sync_wptr.q#past_q_wire))
                                  (get-field impl-post-conc 'fifo_wptr#past_d_wire)))
      (printf "fifo-depth: ~a~n" (fifo-depth
                                  (gray2dec (get-field impl-post-conc 'sync_wptr.q#past_d_wire))
                                  (get-field impl-post-conc 'fifo_wptr#past_d_wire)))

      (printf "sync_wptr.intq#q [rd] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'sync_wptr.intq#past_q_wire))
              (gray2dec (get-field impl-post-conc 'sync_wptr.intq#past_q_wire)))

      (printf "sync_wptr.intq#d [rd] - ~a => ~a ~n"
              (gray2dec (get-field impl-pre-conc 'sync_wptr.intq#past_d_wire))
              (gray2dec (get-field impl-post-conc 'sync_wptr.intq#past_d_wire)))

      (printf "fifo-depth: ~a~n" (fifo-depth
                                  (gray2dec (get-field impl-post-conc 'sync_wptr.intq#past_q_wire))
                                  (get-field impl-post-conc 'fifo_wptr#past_d_wire)))
      (printf "fifo-depth: ~a~n" (fifo-depth
                                  (gray2dec (get-field impl-post-conc 'sync_wptr.intq#past_d_wire))
                                  (get-field impl-post-conc 'fifo_wptr#past_d_wire)))

      (printf "fifo_wptr#q      [wr] - ~a => ~a ~n"
              (get-field impl-pre-conc 'fifo_wptr#past_q_wire)
              (get-field impl-post-conc 'fifo_wptr#past_q_wire))
      (printf "fifo-depth: ~a~n" (fifo-depth
                                  (get-field impl-post-conc 'fifo_wptr#past_q_wire)
                                  (get-field impl-post-conc 'fifo_wptr#past_d_wire)))


      (printf "fifo_wptr#d      [wr] - ~a => ~a ~n"
              (get-field impl-pre-conc 'fifo_wptr#past_d_wire)
              (get-field impl-post-conc 'fifo_wptr#past_d_wire))


      (unless (rel impl-post-conc spec-post-conc)
        (!for ([reg registers])
              (let* ([name (car reg)]
                     [getter (cdr reg)]
                     [impl-val (getter impl-post-conc)]
                     [spec-val (getter spec-post-conc)])
                (unless (equal? impl-val spec-val)
                  (printf "~v: ~v != ~v ~n" name impl-val spec-val))))
        (define impl-live-storage (get-live-storage impl-post-conc))
        (define spec-live-storage (get-live-storage spec-post-conc))
        (unless (equal? impl-live-storage spec-live-storage)
          (printf "storage: ~v != ~v ~n" impl-live-storage spec-live-storage))))
    ;(printf "impl-pre: ~v~n" impl-pre-conc)
    ;(printf "spec-pre: ~v~n" spec-pre-conc)
    ;(printf "input: ~v~n" some-input)
    ;(printf "impl-post: ~v~n" impl-post-conc)
    ;(printf "spec-post: ~v~n" spec-post-conc))
    r)

  (displayln "Checking base case...")
  (check-true (verify-base-case) "Failed to verify base case!")
  (displayln "Checking inductive step read clock...")
  (check-true (verify-inductive-step #t #f) "Failed to verify inductive step!")
  (displayln "Checking inductive step write clock...")
  (check-true (verify-inductive-step #f #t) "Failed to verify inductive step!")
  (displayln "Checking inductive step both clocks...")
  (check-true (verify-inductive-step #t #t) "Failed to verify inductive step!")

  (check-true (vc-assumes (vc))))

;; (module+ main
;;   (require "prim_fifo_async_16_3.rkt")
;;   (verify-prim-fifo-async
;;    new-symbolic-prim_fifo_async_s
;;    prim_fifo_async_t
;;    fix-mem
;;    registers
;;    outputs
;;    16
;;    3))
