#lang rosette/safe

(require
 (prefix-in ! (combine-in (only-in racket/base for for/vector in-range
                                   make-parameter)))
 (only-in yosys/lib select store))

(require "../util/bv.rkt")

(provide fifo-ptr-width fifo-max-depth ptr-idx ptr-val fifo-depth inc-ptr gray2dec)

; Module implementing various functionality mirroring the prim_fifo_sync and
; prim_fifo_async modules from OpenTitan. These utilities are useful for proving
; things about these modules.

; TODO: wrap everything in function (or unit?) that takes in these parameters
; and returns parameterized functions.
(define fifo-ptr-width (!make-parameter 3))
(define fifo-max-depth (!make-parameter (bv 3 3)))

; return index into storage vector based on ptr (index with all bits besides MSB)
(define (ptr-idx ptr)
  (extract (- (fifo-ptr-width) 2) 0 ptr))

(define (ptr-val ptr)
  (zero-extend (ptr-idx ptr) (bitvector (fifo-ptr-width))))

; get number of elements in FIFO based on rptr and wptr
(define (fifo-depth rptr wptr)
  (define wptr-value (ptr-val wptr))
  (define rptr-value (ptr-val rptr))
  (define full (and (equal? (msb wptr) (bvnot (msb rptr)))
                    (equal? wptr-value rptr-value)))
  (if full
      (fifo-max-depth)
      (if (equal? (msb wptr) (msb rptr))
          (bvsub wptr-value rptr-value)
          (bvadd (bvsub (fifo-max-depth) rptr-value) wptr-value))))

; increment {r,w}ptr based on algorithm in prim_fifo_{a}sync
; add 1 until ptr[WIDTH-2:0] == Depth - 1, then set ptr[WIDTH-2:0] = 0 and
; flip MSB
(define (inc-ptr ptr)
  (if (bveq (ptr-val ptr) (bvsub1 (fifo-max-depth)))
      (concat (bvnot (msb ptr)) (bv 0 (sub1 (fifo-ptr-width))))
      (bvadd1 ptr)))

; Gray-code functions (based on prim_fifo_async.sv)

;;; function automatic [PTR_WIDTH-1:0] gray2dec(input logic [PTR_WIDTH-1:0] grayval);
;;;   logic [PTR_WIDTH-2:0] dec_tmp, dec_tmp_sub;
;;;   logic                 unused_decsub_msb;
;;;
;;;   dec_tmp[PTR_WIDTH-2] = grayval[PTR_WIDTH-2];
;;;   for (int i = PTR_WIDTH-3; i >= 0; i--)
;;;     dec_tmp[i] = dec_tmp[i+1]^grayval[i];
;;;   {unused_decsub_msb, dec_tmp_sub} = Depth - {1'b0,dec_tmp} - 1'b1;
;;;   if (grayval[PTR_WIDTH-1])
;;;     gray2dec = {1'b1,dec_tmp_sub};
;;;   else
;;;     gray2dec = {1'b0,dec_tmp};
;;; endfunction

(define (gray2dec-func grayval)
  (define dec_tmp (build-zero-vector 1 (sub1 (fifo-ptr-width))))
  (vector-set! dec_tmp (- (fifo-ptr-width) 2) (extract (- (fifo-ptr-width) 2) (- (fifo-ptr-width) 2) grayval))
  (!for ([i (!in-range (- (fifo-ptr-width) 3) -1 -1)])
    (vector-set! dec_tmp i (bvxor (vector-ref dec_tmp (add1 i)) (extract i i grayval))))
  (define dec_tmp_sub (extract (- (fifo-ptr-width) 2) 0
                               (bvsub (bvsub (fifo-max-depth)
                                             (concat (bv 0 1) (vector->bv dec_tmp)))
                                      (bv 1 (fifo-ptr-width)))))
  (if (bitvector->bool (msb grayval))
      (concat (bv 1 1) dec_tmp_sub)
      (concat (bv 0 1) (vector->bv dec_tmp))))

; TODO: once the entire thing is wrapped with parameters, no need to make
; gray2dec-table a function

; use look-up-table since gray2dec-func uses unlifted racket features
(define (gray2dec-table)
  (!for/vector ([i (!in-range (expt 2 (fifo-ptr-width)))])
               (gray2dec-func (bv i (fifo-ptr-width)))))

(define (gray2dec g)
  (select (gray2dec-table) g))
