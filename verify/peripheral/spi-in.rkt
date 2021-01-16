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

(define input
  (append '((scanmode_i . #f) dio_spi_device_csb_i dio_spi_device_mosi_i) ; module
          main-to-spi-in-registers))

(define outputs (names->getters spi-in-to-main-registers))

(define (get-live-rx-data state)
  (define rx-data (|top_earlgrey_n spi_device.u_fwmode.rx_data_q| state))
  (define rx-bitcount (|top_earlgrey_n spi_device.u_fwmode.rx_bitcount| state))
  (define end (bvsub (bv 7 3) rx-bitcount))
  (define mask (bvsub (bvshl (bv 1 8) (zero-extend end (bitvector 8))) (bv 1 8)))
  (define cfg-rx-order (get-field state 'spi_device.u_fwmode.current_cfg_rx_order))
  (bvand rx-data (if (bitvector->bool cfg-rx-order)
                     (apply concat (bitvector->bits mask)) ; reverse bv
                     mask)))

(define (rel impl spec)
  (define untransformed-fields
    (filter (lambda (r) (not (equal? r 'spi_device.u_fwmode.rx_data_q)))
            spi-in-registers))
  (define impl-untransformed-fields (get-fields impl untransformed-fields))
  (define spec-untransformed-fields (get-fields spec untransformed-fields))
  (and
       (equal? impl-untransformed-fields spec-untransformed-fields)
       (equal? (get-live-rx-data impl) (get-live-rx-data spec))))

(define (make-spec impl)
  (!struct-copy top_earlgrey_s impl [spi_device.u_fwmode.rx_data_q (bv 0 8)]))

(module+ main
  (displayln "Verifying SPI-in")
  (define-values (res t)
    (time
     (verify-peripheral-output-determinism
      #:make-spec make-spec
      #:rel rel
      #:inputs input
      #:registers spi-in-registers
      #:outputs outputs)))
  (printf "SPI-in verified in ~as~n" (fmt-time t))
  (check-true res))
