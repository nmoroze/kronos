MAKEFLAGS += -r
MAKEFLAGS += -R

ROM_DEPTH := 2048
ifndef PREFIX
PREFIX := $(shell if riscv64-unknown-elf-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-unknown-elf-'; \
	elif riscv64-linux-gnu-objdump -i 2>&1 | grep 'elf64-big' >/dev/null 2>&1; \
	then echo 'riscv64-linux-gnu-'; \
	else echo "***" 1>&2; \
	echo "*** Error: Couldn't find an riscv64 version of GCC/binutils." 1>&2; \
	echo "*** To turn off this error, run 'make PREFIX= ...'." 1>&2; \
	echo "***" 1>&2; exit 1; fi)
endif

CC := $(PREFIX)gcc
AS := $(PREFIX)as
LD := $(PREFIX)ld
OBJCOPY := $(PREFIX)objcopy
OBJDUMP := $(PREFIX)objdump

CFLAGS := -O2 -march=rv32i -mabi=ilp32 -fdata-sections -ffunction-sections -ffreestanding
ASFLAGS := -march=rv32im -mabi=ilp32
OBJDUMPFLAGS := --disassemble-all --source --section-headers --demangle
LDFLAGS := -melf32lriscv -nostdlib
BIN2COEFLAGS := --width 32 --depth $(ROM_DEPTH) --fill 0

FIFOS := prim_fifo_async_5_4.rkt
FIFOS += prim_fifo_async_8_8.rkt
FIFOS += prim_fifo_async_17_4.rkt
FIFOS += prim_fifo_sync_100_3.rkt
FIFOS += prim_fifo_sync_2_4.rkt
FIFOS += prim_fifo_sync_33_2.rkt

.PHONY: all
all: opentitan.rkt $(FIFOS)

.PHONY: clean
clean:
	rm -f \
		fw/*.o fw/*.bin fw/*.lst fw/*.elf \
		soc/*.mem \
		soc/opentitan.v \
		soc/opentitan.smt2 \
		opentitan.rkt \
		prim_fifo_sync_*.rkt \
		prim_fifo_async_*.rkt \
		prim_fifo_sync_*.smt2 \
		prim_fifo_async_*.smt2 \
		prim_fifo_sync.v \
		prim_fifo_async.v

VERIFY_ARGS ?=
.PHONY: verify sim vsources
verify: compiled/opentitan_rkt.dep fw/bootrom.mem $(FIFOS)
	raco test ++args "$(VERIFY_ARGS)" -j $(shell nproc) -s main verify

fifos: $(FIFOS)

verify/module/prim-fifo-sync/prim_fifo_sync_%.rkt:
	$(MAKE) -C verify/module/prim-fifo-sync WIDTH=$(word 1,$(subst _, ,$*)) \
		DEPTH=$(word 2, $(subst _, ,$*))

compiled/%_rkt.dep: %.rkt
	raco make $<

# fw

%.bin: %.elf
	$(OBJCOPY) $< -O binary $@

%.o: %.s
	$(AS) $(ASFLAGS) -c $< -o $@

%.lst: %.elf
	$(OBJDUMP) $(OBJDUMPFLAGS) $< > $@

fw/%.elf: fw/rom.ld fw/%.o
	@mkdir -p fw
	$(LD) $(LDFLAGS) -T $^ -o $@

soc/%.mem: fw/%.bin
	bin2coe $(BIN2COEFLAGS) --mem -i $< -o $@

# fifos

PRIM_RTL := soc/opentitan/hw/ip/prim/rtl
include verify/fifo/sync.mk
include verify/fifo/async.mk

# soc

include soc/deps.mk

SV2V ?= sv2v
soc/opentitan.v: $(OT_SRCS)
	$(SV2V) -I=soc/opentitan/hw/ip/prim/rtl/ -DSYNTHESIS -D=ROM_INIT_FILE=bootrom.mem $^ > $@


# fw/bootrom.mem is an order-only prereq, since we don't actually use the data
# encoded in the smt2 output, but it needs to exist for synthesis to succeed
soc/opentitan.smt2: soc/opentitan.v | soc/bootrom.mem
	cd soc; yosys \
		-p 'read_verilog opentitan.v' \
		-p 'prep -flatten -top top_earlgrey -nordff' \
		-p 'techmap -map +/adff2dff.v' \
		-p 'write_smt2 -stdt opentitan.smt2'

UNAME := $(shell uname -s)
SEDFLAGS :=
ifeq ($(UNAME), Darwin)
	SEDFLAGS += -i ''
else
	SEDFLAGS += -i''
endif

# sed hack eliminates the writes to USB memory from USB clock domain to prevent
# the memory from being screwed up by symbolic USB clock domain during
# deterministic start (USB clock domain writes are verified to be safe, and we
# overapproximate the memory on every cycle)
opentitan.rkt: soc/opentitan.smt2
	echo "#lang yosys" > $@ && cat $< >> $@
	sed $(SEDFLAGS) 's/(= (|top_earlgrey#\([0-9]*\)#2| state) (|top_earlgrey#\1#0| next_state)) ; usbdev\.u_memory_2p\.gen_srammem\.u_mem\.gen_mem_generic\.u_impl_generic\.mem CLK={ \\clk_usb_48mhz_i \\clk_i }/(= (|top_earlgrey#\1#1| state) (|top_earlgrey#\1#0| next_state)) ; usbdev\.u_memory_2p\.gen_srammem\.u_mem\.gen_mem_generic\.u_impl_generic\.mem CLK={ \\clk_usb_48mhz_i \\clk_i }/' opentitan.rkt
