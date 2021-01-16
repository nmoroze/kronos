#lang rosette/safe

(require
 (prefix-in ! (only-in racket/base struct-copy))
 rackunit
 rosutil
 yosys)

(require
 "../clock-domains.rkt"
 "common.rkt"
 "../../opentitan.rkt"
 "../util/circuit.rkt"
 "../util/rosette.rkt"
 "../util/time.rkt")

(define input (append '((scanmode_i . #f) dio_spi_device_csb_i) ; module
                      main-to-spi-out-registers))

(define outputs
  (append (list (cons 'dio_spi_device_miso_o  |top_earlgrey_n dio_spi_device_miso_o|)) ; module
                 (names->getters spi-out-to-main-registers)))

(define (get-live-miso-shift state)
  (define miso-shift (|top_earlgrey_n spi_device.u_fwmode.miso_shift| state))
  (define tx-bitcount (|top_earlgrey_n spi_device.u_fwmode.tx_bitcount| state))
  (if (bveq tx-bitcount (bv 7 3))
      (bv 0 8)
      miso-shift))

(define (rel impl spec)
  (define untransformed-fields
    (filter (lambda (r) (not (equal? r 'spi_device.u_fwmode.miso_shift)))
            spi-out-registers))
  (define impl-untransformed-fields (get-fields impl untransformed-fields))
  (define spec-untransformed-fields (get-fields spec untransformed-fields))

  (and (equal? impl-untransformed-fields spec-untransformed-fields)
       (equal? (get-live-miso-shift impl) (get-live-miso-shift spec))))

(define (make-spec impl)
  (!struct-copy top_earlgrey_s impl
                [spi_device.u_fwmode.miso_shift (bv 0 8)]))

(module+ main
  (displayln "Verifying SPI-out")
  (define-values (res t)
    (time
     (verify-peripheral-output-determinism
      #:make-spec make-spec
      #:rel rel
      #:inputs input
      #:registers spi-out-registers
      #:outputs outputs)))
  (printf "SPI-out verified in ~as~n" (fmt-time t))
  (check-true res))
