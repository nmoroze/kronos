#lang racket/base

(require racket/list) ; empty?
(require (prefix-in @ rosette/safe))
(require yosys/parameters)
(require rosutil)

(provide print-state print-state-symbolic print-mem print-mem-symbolics identify-growing-terms-depth identify-growing-terms)

(define no-output '(
  ; no need to look at rom
  "u_rom_rom.gen_mem_generic.u_impl_generic.mem"

  ; overapproximated SPI clock domain contents
  "spi_device.u_txf_underflow.src_level "
  "spi_device.u_tx_fifo.sync_wptr.q "
  "spi_device.u_tx_fifo.sync_wptr.intq "
  "spi_device.u_tx_fifo.fifo_rptr_gray"
  "spi_device.u_fwmode.tx_state"
  "spi_device.txf_empty_q"
  "spi_device.u_fwmode.tx_bitcount"
  "spi_device.u_tx_fifo.fifo_rptr"
  "spi_device.u_fwmode.miso_shift"
  "spi_device.u_rxf_overflow.src_level"
  "spi_device.u_rx_fifo.sync_rptr.q"
  "spi_device.u_rx_fifo.sync_rptr.intq"
  "spi_device.u_rx_fifo.fifo_wptr_gray"
  "spi_device.u_rx_fifo.fifo_wptr"
  "spi_device.u_rx_fifo.fifo_rptr_sync"
  "spi_device.u_fwmode.rx_data_q"
  "spi_device.u_fwmode.rx_bitcount"
  "spi_device.rxf_full_q"
  "spi_device.u_rx_fifo.storage"))

(define (print-state s)
  (parameterize ([field-filter (filter/not (apply filter/or no-output))])
    (printf "~v~n" s)))

(define (print-state-symbolic s state-getters)
  (for ([sg state-getters])
    (let ([name (car sg)]
          [getter (cdr sg)])
      (define len (length (@symbolics (getter s))))
      (when (> len 0)
        (printf "~a: ~a~n" name len)))))

(define (print-mem mem)
  (for ([i (in-naturals)]
        [entry mem])
    (printf "~a: ~a~n" i entry)))

(define (print-mem-symbolics mem)
  (for ([i (in-naturals)]
        [entry mem])
    (define len (length (@symbolics entry)))
    (when (> len 0)
      (printf "~a: ~a~n" i len))))

(define prev-symbolics (make-parameter '()))
(define prev-depths (make-parameter '()))

(define (identify-growing-terms-depth sn state-getters)
  (displayln "Growing terms (depth):")
  (define depth-per-field
    (for/list ([named-getter state-getters])
      (let ([name (car named-getter)]
            [getter (cdr named-getter)])
        (define depth (value-depth (getter sn)))
        (cons name depth))))
  (unless (empty? (prev-depths))
    (for ([named-depth depth-per-field]
          [prev-named-depth (prev-depths)])
      (let ([name (car named-depth)]
            [depth (cdr named-depth)]
            [prev-depth (cdr prev-named-depth)])
        (define delta (- depth prev-depth))
        (when (> delta 0)
          (printf "~a: ~a~n" name delta)
          (printf "  before: ~a, after: ~a~n" prev-depth depth)))))
  (prev-depths depth-per-field))


(define (identify-growing-terms sn state-getters)
  (displayln "Growing terms (# symbolics):")
  (define symbolics-per-field
    (for/list ([field-getter state-getters])
      (let ([field (car field-getter)]
            [getter (cdr field-getter)])
        (cons field (length (@symbolics (getter sn)))))))
  (unless (empty? (prev-symbolics))
    (for ([named-symcount symbolics-per-field]
          [prev-named-symcount (prev-symbolics)])
      (let ([name (car named-symcount)]
            [symcount (cdr named-symcount)]
            [prev-symcount (cdr prev-named-symcount)])
        (define delta (- symcount prev-symcount))
        (when (> delta 0)
          (printf "~a: ~a~n" name delta)
          (printf "  before: ~a, after: ~a~n" prev-symcount symcount)))))
  (prev-symbolics symbolics-per-field))
