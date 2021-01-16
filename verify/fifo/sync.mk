PRIM_RTL ?= ../../../soc/opentitan/hw/ip/prim/rtl

prim_fifo_sync.v: $(PRIM_RTL)/prim_fifo_sync.sv
	sv2v -I=$(PRIM_RTL) $< > $@

prim_fifo_sync_%.smt2: prim_fifo_sync.v
	yosys \
		-p 'read_verilog $<' \
		-p 'select prim_fifo_sync' \
		-p "chparam -set Width $(word 1,$(subst _, ,$*)) -set Depth $(word 2, $(subst _, ,$*)) -set Pass 1'b0" \
		-p 'select *' \
		-p 'prep -flatten -top prim_fifo_sync -nordff' \
		-p 'techmap -map +/adff2dff.v' \
		-p 'write_smt2 -stdt $@'

prim_fifo_sync_%.rkt: prim_fifo_sync_%.smt2
	echo "#lang yosys" > $@ && cat $< >> $@
