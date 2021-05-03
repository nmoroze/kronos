#lang racket/base

(require
 racket/set
 (prefix-in @ (combine-in rosette/safe rosutil))
 (only-in yosys get-field update-field update-fields))

(require "../../opentitan.rkt")
(require "../clock-domains.rkt")
(require "bv.rkt")
(require "rosette.rkt")

; Utillities specifically related to working with opentitan.rkt

(provide new-init-soc post-reset make-input step)

(define (new-init-soc)
  (define symbolic-soc (new-symbolic-top_earlgrey_s))
  (define with-reset (update-field symbolic-soc 'rst_ni #f))
  (post-reset (top_earlgrey_t with-reset)))

; take in state that's been stepped with reset and transform it into proper
; post-reset state
(define (post-reset state)
  ; overapproximate registers uninitialized on reset
  (define state* (overapproximate state non-reset-registers))

  ; zero out all verified FIFOs
  (update-fields state*
                 (for/list ([field '(spi_device.u_fwmode_arb.u_req_fifo.gen_normal_fifo.storage
                                     tl_adapter_ram_main.u_rspfifo.gen_normal_fifo.storage
                                     u_xbar_main.u_asf_21.reqfifo.storage_rest
                                     spi_device.u_tx_fifo.storage_rest
                                     spi_device.u_rx_fifo.storage_rest
                                     usbdev.usbdev_avfifo.storage_rest
                                     usbdev.usbdev_rxfifo.storage_rest)])
                   (let* ([v (get-field state* field)]
                          [el (vector-ref v 0)])
                     (cons field
                           (build-zero-vector (bvwidth el) (vector-length v)))))))

(define (make-input inputs)
  (define sn (new-zeroed-top_earlgrey_s))
  (append
   (list (cons 'rst_ni #t)) ; append reset just in case it's not present
   (for/list ([i inputs])
     (cond
       [(pair? i) i] ; pre-set value
       [else ; symbol
        (define v (get-field sn i))
        (cons i (if (vector? v)
                    (@fresh-memory-like i v)
                    (@fresh-symbolic i (@type-of v))))]))))

(define (step state input registers)
  ; overapproximate all other clock domains after stepping to model that those
  ; clock domains may step. (step assumes that when state is first passed in
  ; the other clock domains are overapproximated already)
  (overapproximate (top_earlgrey_t (update-fields state input))
                   (set-subtract (append
                                  main-registers
                                  spi-in-registers
                                  spi-out-registers
                                  usb-registers)
                                 registers)))
