PRIM_RTL ?= ../../../soc/opentitan/hw/ip/prim/rtl

prim_fifo_async.v: $(PRIM_RTL)/prim_fifo_async.sv $(PRIM_RTL)/prim_flop_2sync.sv
	sv2v -I=$(PRIM_RTL) $^ > $@

prim_fifo_async_%.smt2: prim_fifo_async.v
	yosys \
		-p 'read_verilog $<' \
		-p 'select prim_fifo_async' \
		-p 'chparam -set Width $(word 1,$(subst _, ,$*)) -set Depth $(word 2, $(subst _, ,$*))' \
		-p 'select *' \
		-p 'prep -flatten -top prim_fifo_async -nordff' \
		-p 'clk2fflogic' \
		-p 'techmap -map +/adff2dff.v' \
		-p 'write_smt2 -stdt $@'

prim_fifo_async_%.rkt: prim_fifo_async_%.smt2
	echo "#lang yosys/clk2fflogic" > $@ && cat $< >> $@
