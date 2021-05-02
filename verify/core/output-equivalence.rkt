#lang rosette/safe

(require
 (prefix-in ! (only-in racket/base for for/list in-naturals))
 rosutil
 shiva
 (only-in yosys get-field update-field update-fields))

(require
 "common.rkt"
 (except-in "../../opentitan.rkt" inputs)
 "../util/rosette.rkt")

(provide verify-core-output-eqv-base verify-core-output-eqv-step)

(define (invariant-rxf state)
  (define rxf-ctrl-st (get-field state 'spi_device.u_rxf_ctrl.st))
  (define sram-write (get-field state 'spi_device.u_rxf_ctrl.sram_write))
  (equal? (equal? rxf-ctrl-st (bv 5 3)) ; StWrite
          (equal? sram-write (bv 1 1))))

(define (rel-rxf impl spec)
  (define impl-sram_wdata (get-field impl 'spi_device.u_rxf_ctrl.sram_wdata))
  (define spec-sram_wdata (get-field spec 'spi_device.u_rxf_ctrl.sram_wdata))

  (define byte-enable (get-field impl 'spi_device.u_rxf_ctrl.byte_enable))
  (define rxf-ctrl-st (get-field impl 'spi_device.u_rxf_ctrl.st))

  (and
   (invariant-rxf impl)
   (invariant-rxf spec)
   (if (equal? rxf-ctrl-st (bv 5 3)) ; StWrite
       (equal? impl-sram_wdata spec-sram_wdata)
       (and
        (if (equal? (extract 0 0 byte-enable) (bv 1 1))
            (equal? (extract 7 0 impl-sram_wdata) (extract 7 0 spec-sram_wdata))
            #t)
        (if (equal? (extract 1 1 byte-enable) (bv 1 1))
            (equal? (extract 15 8 impl-sram_wdata) (extract 15 8 spec-sram_wdata))
            #t)
        (if (equal? (extract 2 2 byte-enable) (bv 1 1))
            (equal? (extract 23 16 impl-sram_wdata) (extract 23 16 spec-sram_wdata))
            #t)
        (if (equal? (extract 3 3 byte-enable) (bv 1 1))
            (equal? (extract 31 24 impl-sram_wdata) (extract 31 24 spec-sram_wdata))
            #t)))))

(define (invariant-txf state)
  (define txf-ctrl-st (get-field state 'spi_device.u_txf_ctrl.st))
  (define rxf-ctrl-st (get-field state 'spi_device.u_rxf_ctrl.st))
  (define txf-sram-req (get-field state 'spi_device.u_txf_ctrl.sram_req))
  (define rxf-sram-req (get-field state 'spi_device.u_rxf_ctrl.sram_req))
  (define sram-valid (get-field state 'spi_device.u_memory_2p.b_rvalid_sram))

  (and
   (equal? (equal? txf-ctrl-st (bv 1 3)) ; StRead
           (equal? txf-sram-req (bv 1 1)))
   (if (or (equal? rxf-ctrl-st (bv 3 3)) ; StRead
           (equal? rxf-ctrl-st (bv 5 3))) ; StWrite
       (equal? rxf-sram-req (bv 1 1))
       (equal? rxf-sram-req (bv 0 1)))
   (if (not (or
             (bveq rxf-ctrl-st (bv 4 3))   ;StModify
             (bvuge txf-ctrl-st (bv 2 3))))
       (equal? sram-valid (bv 0 1))
       #t)))

(define (rel-txf impl spec)
  (define rxf-ctrl-st (get-field impl 'spi_device.u_rxf_ctrl.st))
  (define txf-ctrl-st (get-field impl 'spi_device.u_txf_ctrl.st))
  (define impl-b_rdata_o (get-field impl 'spi_device.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o))
  (define spec-b_rdata_o (get-field spec 'spi_device.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o))
  (define impl-sram_rdata_q (get-field impl 'spi_device.u_txf_ctrl.sram_rdata_q))
  (define spec-sram_rdata_q (get-field spec 'spi_device.u_txf_ctrl.sram_rdata_q))

  (and
   (invariant-txf impl)
   (invariant-txf spec)
   (if (or
        (bveq rxf-ctrl-st (bv 4 3))   ;StModify
        (bvuge txf-ctrl-st (bv 2 3))) ;StRead
       (equal? impl-b_rdata_o spec-b_rdata_o)
       #t)
   (if (bvuge txf-ctrl-st (bv 3 3)) ; StPush
       (equal? impl-sram_rdata_q spec-sram_rdata_q)
       #t)))

; rel minus state equality
(define (rel-pre impl spec)
  (and
   (rel-rxf impl spec)
   (rel-txf impl spec)))

(define (rel impl spec)
  (define impl-safe-state (get-fields impl filtered-state-names))
  (define spec-safe-state (get-fields spec filtered-state-names))
  (and
   (equal? impl-safe-state spec-safe-state)
   (rel-pre impl spec)))

(define (outputs-equal? impl spec)
  (define impl-outputs (get-outputs impl))
  (define spec-outputs (get-outputs spec))
  (equal? impl-outputs spec-outputs))

(define (new-symbolic-input)
  (define sn (new-zeroed-top_earlgrey_s))
  (append
   (list (cons 'rst_ni #t))
   (!for/list ([i inputs]) ; append reset just in case it's not present
              (cond
                [(pair? i) i] ; pre-set value
                [else ; symbol
                 (define v (get-field sn i))
                 (cons i (if (vector? v)
                             (fresh-memory-like i v)
                             (fresh-symbolic i (type-of v))))]))))

(define (step state input)
  (top_earlgrey_t
   (update-fields state input)))

(define (get-outputs state)
  (!for/list ([output output-getters-phase-2])
             ((cdr output) state)))

(define (display-field f impl-pre-concrete spec-pre-concrete impl-post-concrete spec-post-concrete)
  (printf "impl pre  ~a: ~a~n" f (get-field impl-pre-concrete  f))
  ;; (printf "spec pre  ~a: ~a~n" f (get-field spec-pre-concrete  f))
  (printf "impl post ~a: ~a~n" f (get-field impl-post-concrete f))
  ;; (printf "spec post ~a: ~a~n" f (get-field spec-post-concrete f))
  )

(define (verify-core-output-eqv-base impl allowed-dependencies)
  (define impl-sram-wdata (get-field impl 'spi_device.u_rxf_ctrl.sram_wdata))
  (define byte-enable (get-field impl 'spi_device.u_rxf_ctrl.byte_enable))
  (define spec-updates
    (list
     (cons 'spi_device.u_rxf_ctrl.sram_wdata
           (concat
            (if (equal? (extract 3 3 byte-enable) (bv 1 1))
                (extract 31 24 impl-sram-wdata)
                (bv 0 8))
            (if (equal? (extract 2 2 byte-enable) (bv 1 1))
                (extract 23 16 impl-sram-wdata)
                (bv 0 8))
            (if (equal? (extract 1 1 byte-enable) (bv 1 1))
                (extract 15 8 impl-sram-wdata)
                (bv 0 8))
            (if (equal? (extract 0 0 byte-enable) (bv 1 1))
                (extract 7 0 impl-sram-wdata)
                (bv 0 8))))
     (cons 'spi_device.u_txf_ctrl.sram_rdata_q (bv 0 32))
     (cons 'spi_device.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o (bv 0 39))))

  (define spec (update-fields impl spec-updates))

  (and
   (unsat? (verify (assert (rel impl spec))))
   (unsat? (check-deterministic-state spec all-state-getters allowed-dependencies 'none))))

(define (verify-core-output-eqv-step)
  (define impl-pre
    (update-field (new-symbolic-top_earlgrey_s)
                  'u_rom_rom.gen_mem_generic.u_impl_generic.mem
                  rom-data))

  ; we copy over all symbolic values from impl-pre that are considered equal by
  ; the relation function. this lets us just use `rel-pre` in the solver query
  ; assumption. this is a performance optimization -- if we assume `rel`
  ; instead, the query doesn't finish with a large RAM.
  (define spec-pre
    (update-fields (new-symbolic-top_earlgrey_s)
                   (!for/list ([i filtered-state-names])
                              (cons i (get-field impl-pre i)))))

  (define some-input (new-symbolic-input))
  (define impl-post (step impl-pre some-input))
  (define spec-post (step spec-pre some-input))

  (define res (verify (begin (assume (rel-pre impl-pre spec-pre))
                             (assert (and (rel impl-post spec-post)
                                          (outputs-equal? impl-post spec-post))))))

  (when (sat? res)
    (define impl-pre-concrete (evaluate impl-pre (complete-solution res (symbolics impl-pre))))
    (define spec-pre-concrete (evaluate spec-pre (complete-solution res (symbolics spec-pre))))
    (define impl-post-concrete (evaluate impl-post (complete-solution res (symbolics impl-post))))
    (define spec-post-concrete (evaluate spec-post (complete-solution res (symbolics spec-post))))

    (!for ([s filtered-state-names])
          (let ([impl-v (get-field impl-post-concrete s)]
                [spec-v (get-field spec-post-concrete s)])
            (if (vector? impl-v)
                (!for ([i (!in-naturals)]
                      [impl-v_ impl-v]
                      [spec-v_ spec-v])
                      (unless (equal? impl-v_ spec-v_)
                        (printf "~a[~a]: ~a != ~a~n" s i impl-v_ spec-v_)))
                (unless (equal? impl-v spec-v)
                  (printf "~a: ~a != ~a~n" s impl-v spec-v)))))

    (printf "rel  pre: ~a~n" (rel impl-pre-concrete spec-pre-concrete))
    (printf "rel post: ~a~n" (rel impl-post-concrete spec-post-concrete))
    (printf "rel-rxf: ~a~n" (rel-rxf impl-post-concrete spec-post-concrete))
    (printf "rel-txf: ~a~n" (rel-txf impl-post-concrete spec-post-concrete))

    (printf "outputs eq?: ~a~n" (outputs-equal? impl-post-concrete spec-post-concrete))
    (printf "impl pre sram_wdata: ~a~n" (get-field impl-pre-concrete 'spi_device.u_rxf_ctrl.sram_wdata))
    (printf "spec pre sram_wdata: ~a~n" (get-field spec-pre-concrete 'spi_device.u_rxf_ctrl.sram_wdata))
    (printf "impl post sram_wdata: ~a~n" (get-field impl-post-concrete 'spi_device.u_rxf_ctrl.sram_wdata))
    (printf "spec post sram_wdata: ~a~n" (get-field spec-post-concrete 'spi_device.u_rxf_ctrl.sram_wdata))

    (printf "impl pre rdata_q: ~a~n" (get-field impl-pre-concrete 'spi_device.u_txf_ctrl.sram_rdata_q))
    (printf "spec pre rdata_q: ~a~n" (get-field spec-pre-concrete 'spi_device.u_txf_ctrl.sram_rdata_q))
    (printf "impl post rdata_q: ~a~n" (get-field impl-post-concrete 'spi_device.u_txf_ctrl.sram_rdata_q))
    (printf "spec post rdata_q: ~a~n" (get-field spec-post-concrete 'spi_device.u_txf_ctrl.sram_rdata_q))

    (printf "impl pre  b_rdata_o: ~a~n" (get-field impl-pre-concrete 'spi_device.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o))
    (printf "spec pre  b_rdata_o: ~a~n" (get-field spec-pre-concrete 'spi_device.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o))
    (printf "impl post b_rdata_o: ~a~n" (get-field impl-post-concrete 'spi_device.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o))
    (printf "spec post b_rdata_o: ~a~n" (get-field spec-post-concrete 'spi_device.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o))

    (printf "impl pre  byte enable: ~a~n" (get-field impl-pre-concrete 'spi_device.u_rxf_ctrl.byte_enable))
    (printf "spec pre  byte enable: ~a~n" (get-field spec-pre-concrete 'spi_device.u_rxf_ctrl.byte_enable))
    (printf "impl post byte enable: ~a~n" (get-field impl-post-concrete 'spi_device.u_rxf_ctrl.byte_enable))
    (printf "spec post byte enable: ~a~n" (get-field spec-post-concrete 'spi_device.u_rxf_ctrl.byte_enable))

    (display-field 'spi_device.u_txf_ctrl.st impl-pre-concrete spec-pre-concrete impl-post-concrete spec-post-concrete)
    (display-field 'spi_device.u_rxf_ctrl.st impl-pre-concrete spec-pre-concrete impl-post-concrete spec-post-concrete)
    (display-field 'spi_device.u_txf_ctrl.sram_req impl-pre-concrete spec-pre-concrete impl-post-concrete spec-post-concrete)
    (display-field 'spi_device.u_rxf_ctrl.sram_req impl-pre-concrete spec-pre-concrete impl-post-concrete spec-post-concrete)
    (display-field 'spi_device.u_memory_2p.b_rvalid_sram impl-pre-concrete spec-pre-concrete impl-post-concrete spec-post-concrete)
    )

  (unsat? res))
