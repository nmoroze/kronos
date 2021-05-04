#lang rosette/safe

(require
 (prefix-in ! (combine-in (only-in racket/base for for/list)
                          (only-in racket/set list->seteq seteq set-subtract)))
 rackunit
 rosutil
 (only-in yosys get-field update-field update-fields))

(require
 "../clock-domains.rkt"
 "../../opentitan.rkt"
 "../util/circuit.rkt"
 "../util/rosette.rkt"
 "../util/time.rkt")

(provide (rename-out [fixed-inputs usb-fixed-inputs]
                     [fixed-input-names usb-fixed-input-names]))

(define input-names-phase1
  (append '(
            ; module inputs
            dio_usbdev_sense_i
            dio_usbdev_dp_i
            dio_usbdev_dn_i
            )
          main-to-usb-registers
          ))

(define fixed-inputs (list
                       (cons '|usbdev.u_reg.u_configin0_buffer0.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin0_rdy0.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin0_size0.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin1_buffer1.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin1_rdy1.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin1_size1.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin2_buffer2.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin2_rdy2.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin2_size2.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin3_buffer3.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin3_rdy3.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin3_size3.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin4_buffer4.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin4_rdy4.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin4_size4.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin5_buffer5.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin5_rdy5.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin5_size5.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin6_buffer6.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin6_rdy6.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin6_size6.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin7_buffer7.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin7_rdy7.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin7_size7.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin8_buffer8.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin8_rdy8.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin8_size8.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin9_buffer9.q|  (bv 0 5))
                       (cons '|usbdev.u_reg.u_configin9_rdy9.q|     (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin9_size9.q|    (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin10_buffer10.q|(bv 0 5))
                       (cons '|usbdev.u_reg.u_configin10_rdy10.q|   (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin10_size10.q|  (bv 0 7))
                       (cons '|usbdev.u_reg.u_configin11_buffer11.q|(bv 0 5))
                       (cons '|usbdev.u_reg.u_configin11_rdy11.q|   (bv 0 1))
                       (cons '|usbdev.u_reg.u_configin11_size11.q|  (bv 0 7))
                       (cons '|usbdev.u_reg.u_iso_iso0.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso1.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso2.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso3.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso4.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso5.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso6.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso7.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso8.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso9.q|           (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso10.q|          (bv 0 1))
                       (cons '|usbdev.u_reg.u_iso_iso11.q|          (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out0.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out1.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out2.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out3.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out4.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out5.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out6.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out7.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out8.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out9.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out10.q| (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_out_out11.q| (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup0.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup1.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup2.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup3.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup4.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup5.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup6.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup7.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup8.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup9.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup10.q| (bv 0 1))
                       (cons '|usbdev.u_reg.u_rxenable_setup_setup11.q| (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall0.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall1.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall2.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall3.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall4.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall5.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall6.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall7.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall8.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall9.q|  (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall10.q| (bv 0 1))
                       (cons '|usbdev.u_reg.u_stall_stall11.q| (bv 0 1))
                       (cons '|usbdev.u_reg.u_usbctrl_enable.q| (bv 0 1))
                      ))

(define fixed-input-names (!for/list ([input fixed-inputs]) (car input)))

; phase 1 inputs are everything in input-names-phase1 list, but the configuration
; registers are fixed at certain values (specified by fixed-inputs)
(define inputs-phase1 (append (!set-subtract input-names-phase1 fixed-input-names)
                              fixed-inputs))

; phase 2 inputs are phase 1 inputs (except fully symbolic), plus the contents
; of the USB memory, which has been proven safe by the core clock domain proof
(define inputs-phase2
  (append input-names-phase1
          '(usbdev.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.mem)))

(define (get-outputs state)
  (append
   (list
    ; module outputs
    (|top_earlgrey_n dio_usbdev_pullup_o| state)
    (|top_earlgrey_n dio_usbdev_pullup_en_o| state)
    (|top_earlgrey_n dio_usbdev_dp_o| state)
    (|top_earlgrey_n dio_usbdev_dp_en_o| state)
    (|top_earlgrey_n dio_usbdev_dn_o| state)
    (|top_earlgrey_n dio_usbdev_dn_en_o| state))

   (list
    ; we add USB memory signals to outputs since the core clock domain proof
    ; assumes they're deterministic, so we must verify this
    (|top_earlgrey_m:W1A usbdev.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.mem| state)
    (|top_earlgrey_m:W1D usbdev.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.mem| state)
    (|top_earlgrey_m:W1M usbdev.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.mem| state))

   (!for/list ([f usb-to-main-registers])
    (get-field state f))))

(define safe-usb-registers
  (remove 'usbdev.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o
          usb-registers))

; Invariant for phase 1 in particular (only true with fixed config inputs)
(define (invariant s)
  (and
   ; invariant: the CDC sync registers for the configin_rdy configuration
   ; registers remain zero.
   ; this invariant is necessary for proving the following one
   (equal? (get-field s 'usbdev.usbdev_rdysync.intq) (bv 0 12))
   (equal? (get-field s 'usbdev.usbdev_rdysync.q) (bv 0 12))

   (equal? (get-field s 'usbdev.u_memory_2p.b_rvalid_sram) (bv 0 1))
   (equal? (get-field s 'usbdev.usb_mem_b_rvalid_q) (bv 0 1))

   ; invariant: the in_xfr_state state machine never enters SendData state
   ; this invariant is necessary for proving that uninitialized data from the
   ; USB memory doesn't leak beyond the tx_data_o reg
   (not (equal?
         (bv 2 2) ;StSendData
         (get-field s 'usbdev.usbdev_impl.u_usb_fs_nb_pe.u_usb_fs_nb_in_pe.in_xfr_state)))))

(define (rel impl spec)
  (define safe-impl (get-fields impl safe-usb-registers))
  (define safe-spec (get-fields spec safe-usb-registers))
  (define sram-valid (get-field impl 'usbdev.u_memory_2p.b_rvalid_sram))
  (define usb-mem-rvalid (get-field impl 'usbdev.usb_mem_b_rvalid_q))
  (define b_rdata_o-impl
    (get-field impl 'usbdev.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o))
  (define b_rdata_o-spec
    (get-field spec 'usbdev.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o))

  (define tx_data_o-impl
    (get-field impl 'usbdev.usbdev_impl.u_usb_fs_nb_pe.u_usb_fs_nb_in_pe.tx_data_o))
  (define tx_data_o-spec
    (get-field spec 'usbdev.usbdev_impl.u_usb_fs_nb_pe.u_usb_fs_nb_in_pe.tx_data_o))

  (and (equal? safe-impl safe-spec)
       (if (or
            (equal? sram-valid (bv 1 1))
            (equal? usb-mem-rvalid (bv 1 1)))
           (equal? b_rdata_o-impl b_rdata_o-spec)
           #t)))

(define (rel-phase1 impl spec)
  (and
   (invariant impl)
   (invariant spec)
   (rel impl spec)))

; Peripheral output determinism for USB clock domain
; doesn't use common verify-peripheral-output-determinism because of USB's
; unique 2-phase setup

(define (verify-base-case-phase-1)
  (define impl-init (new-init-soc))
  (define spec-init impl-init)

  (define impl-outputs (get-outputs impl-init))
  (define spec-outputs (get-outputs spec-init))

  (define assertion (and (rel impl-init spec-init)
                          (equal? impl-outputs spec-outputs)))
  (define states-related? (unsat? (verify (assert assertion))))

  ; Output determinism base case: show that initial state and outputs are
  ; deterministic (no dependence on symbolics)
  (define deterministic-state
    (values-only-depend-on (get-fields spec-init safe-usb-registers) (!seteq)))
  (define deterministic-output
    (values-only-depend-on spec-outputs (!seteq)))

  (and deterministic-state deterministic-output states-related?))

(define (verify-inductive-step-phase-1 #:debug [debug #f])
  (define impl-pre (new-symbolic-top_earlgrey_s))
  (define spec-pre (new-symbolic-top_earlgrey_s))

  (define some-input (make-input inputs-phase1))
  (define post-input (make-input inputs-phase2))

  (define impl-post (update-fields (step impl-pre some-input usb-registers) post-input))
  (define spec-post (update-fields (step spec-pre some-input usb-registers) post-input))
  (define impl-outputs (get-outputs impl-post))
  (define spec-outputs (get-outputs spec-post))

  (define assumption (rel-phase1 impl-pre spec-pre))
  (define assertion (and
                     (rel-phase1 impl-post spec-post)
                     (equal? impl-outputs spec-outputs)))

  (define res (verify (begin (assume assumption)
                             (assert assertion))))

  (define states-related? (unsat? res))

  ; Output determinism: show that the post-step spec state and outputs solely
  ; depend on the previous spec state and the inputs.
  (define deterministic-state
    (values-only-depend-on (get-fields spec-post safe-usb-registers)
                                 (!list->seteq (append (symbolics (get-fields spec-pre safe-usb-registers))
                                                       (symbolics some-input)
                                                       (symbolics post-input)))
                                 (invariant spec-pre)))

  (define deterministic-output
    (values-only-depend-on spec-outputs
                           (!list->seteq (append (symbolics (get-fields spec-pre safe-usb-registers))
                                                 (symbolics some-input)
                                                 (symbolics post-input)))
                           (invariant spec-pre)))

  (when debug
    (printf "states related? ~a~n" states-related?)
    (printf "deterministic state? ~a~n" deterministic-state)
    (printf "deterministic output? ~a~n" deterministic-output))

  (and states-related? deterministic-state deterministic-output))

; Need a base case to set us up for phase 2, which is a bit different from our
; other base cases since we're not starting from the initial state. This is
; supposed to represent the very first state of USB clock domain steps on which
; the core clock domain has finished deterministic start (i.e. we have phase 2
; CDC inputs from the core clock domain, but we have not yet stepped with them)
(define (verify-base-case-phase-2)
  ; Since we've been stepping on symbolic input for an unknown number of steps,
  ; fully symbolic starting state
  (define impl-pre* (new-symbolic-top_earlgrey_s))

  ; Create a deterministic spec state. We start off with a symbolic state, but
  ; since Phase 1 shows that every register in the usb clock domain besides
  ; b_rdata_o is deterministic, so that's the only one that has to be zeroed.
  (define spec-pre* (update-field impl-pre*
                                 'usbdev.u_memory_2p.gen_srammem.u_mem.gen_mem_generic.u_impl_generic.b_rdata_o
                                 (bv 0 32)))

  ; Each state should has phase 2 CDC input we can rely on
  (define some-input (make-input inputs-phase2))
  (define impl-pre (update-fields impl-pre* some-input))
  (define spec-pre (update-fields spec-pre* some-input))

  (define impl-output (get-outputs impl-pre))
  (define spec-output (get-outputs spec-pre))

  ; Phase 1 proves this invariant holds, which is necessary for showing that the
  ; impl and new spec state are related
  (define assumption (invariant impl-pre))

  (define assertion (and (rel impl-pre spec-pre)
                         (equal? impl-output spec-output)))

  (define res (verify (begin (assume assumption)
                             (assert assertion))))

  ; Show that spec state is now fully safe, assuming that previous fields in
  ; safe-usb-registers are (which is proven in phase 1)
  (define deterministic-state
    (values-only-depend-on (get-fields spec-pre usb-registers)
                           (!list->seteq (symbolics (get-fields impl-pre safe-usb-registers)))))

  ; Show that spec state has deterministic outputs
  (define deterministic-outputs
    (values-only-depend-on spec-output
                           (!list->seteq (append
                                          (symbolics (get-fields impl-pre safe-usb-registers))
                                          (symbolics some-input)))))

  (and
   (unsat? res)
   deterministic-state
   deterministic-outputs))

(define (verify-inductive-step-phase-2 #:debug [debug #f])
  (define impl-pre (new-symbolic-top_earlgrey_s))
  (define spec-pre (new-symbolic-top_earlgrey_s))
  (define some-input (make-input inputs-phase2))

  (define post-input (make-input inputs-phase2))

  (define impl-post (update-fields (step impl-pre some-input usb-registers) post-input))
  (define spec-post (update-fields (step spec-pre some-input usb-registers) post-input))

  (define impl-outputs (get-outputs impl-post))
  (define spec-outputs (get-outputs spec-post))

  (define assumption (rel impl-pre spec-pre))
  (define assertion (and
                     (rel impl-post spec-post)
                     (equal? impl-outputs spec-outputs)))

  (define res (verify (begin (assume assumption)
                             (assert assertion))))

  (when (and (sat? res) debug)
    (define impl-pre-concrete (evaluate impl-pre res))
    (define impl-post-concrete (evaluate impl-post res))
    (define spec-post-concrete (evaluate spec-post res))
    (define rel? (rel impl-post-concrete spec-post-concrete))
    (printf "rel? ~a~n" rel?)
    (print-state impl-pre-concrete usb-registers)
    (print-state impl-post-concrete usb-registers)
    (unless rel?
      (!for ([f safe-usb-registers])
            (let ([impl-v (get-field impl-post-concrete f)]
                  [spec-v (get-field spec-post-concrete f)])
              (unless (equal? impl-v spec-v)
                (printf "~a: ~a != ~a~n" f impl-v spec-v)))))
    (printf "outputs eq? ~a~n" (equal? (get-outputs impl-post-concrete)
                                       (get-outputs spec-post-concrete))))

  ; Output determinism: show that the post-step spec state and outputs solely
  ; depend on the previous spec state and the inputs.
  (define deterministic-state
    (values-only-depend-on (get-fields spec-post usb-registers)
                           (!list->seteq (append (symbolics (get-fields spec-pre usb-registers))
                                                 (symbolics some-input)
                                                 (symbolics post-input)))
                           (invariant spec-pre)))

  (define deterministic-output
    (values-only-depend-on spec-outputs
                           (!list->seteq (append (symbolics (get-fields spec-pre usb-registers))
                                                 (symbolics some-input)
                                                 (symbolics post-input)))
                           (invariant spec-pre)))

  (when debug
    (printf "states related? ~a~n" res)
    (printf "deterministic state? ~a~n" deterministic-state)
    (printf "deterministic output? ~a~n" deterministic-output))

  (and (unsat? res)
       deterministic-state
       deterministic-output))

(define (verify-usb)
  (displayln "Checking base case... (phase 1)")
  (check-true (verify-base-case-phase-1) "Failed to verify base case!")
  (displayln "Checking inductive step... (phase 1)")
  (check-true (verify-inductive-step-phase-1) "Failed to verify inductive step!")
  (displayln "Checking base case... (phase 2)")
  (check-true (verify-base-case-phase-2) "Failed to verify base case!")
  (displayln "Checking inductive step... (phase 2)")
  (check-true (verify-inductive-step-phase-2) "Failed to verify inductive step!")

  (check-true (vc-true? (vc))))

(module+ main
  (define-values (_ t) (time (verify-usb)))
  (printf "USB verified in ~as~n" (fmt-time t)))
