.global _reset
.type _reset, %function

.equ UART_BASE, 0x40000000
.equ UART_CTRL_OFFSET, 0xC
.equ UART_NCO, 0xFFFF
.equ UART_NCO_OFFSET, 16
.equ UART_CTRL_TX_OFFSET, 0
.equ UART_CTRL_RX_OFFSET, 1
.equ UART_CTRL_SLPBK_OFFSET, 4
.equ UART_WDATA_OFFSET, 0x18
.equ UART_FIFO_CTRL_OFFSET, 0x1C

.equ SPI_BASE, 0x40020000
.equ SPI_CONTROL_OFFSET, 0xc
.equ SPI_CFG_OFFSET, 0x10
.equ SPI_BUFFER_OFFSET, 0x800
.equ SPI_TXF_PTR_OFFSET, 0x24

.equ USB_BASE, 0x40150000
.equ USB_BUFFER_OFFSET, 0x800

.equ RAM_BASE, 0x10000000
.equ RAM_END,  0x10002000

# reset vector
.org 0x80
#################
# Reset SPI (1/2)
#################
li x1, SPI_BASE
li x2, 0x30000 # rst rxfifo and txfifo
sw x2, SPI_CONTROL_OFFSET(x1)
li x2, 0x100
sw x2, SPI_CFG_OFFSET(x1)

#################
# Reset UART
#################
# x1 - UART_BASE
# x2 - Register value under construction
# x3 - intermediate field values

li x1, UART_BASE

# Set NCO for maximum possible baud rate
li x2, UART_NCO
slli x2, x2, UART_NCO_OFFSET

# Enable system loopback
li x3, 1
slli x3, x3, UART_CTRL_SLPBK_OFFSET
or x2, x2, x3

# Enable TX/RX
ori x2, x2, 0x3

# Write to control register
sw x2, UART_CTRL_OFFSET(x1)

# Write 32 bytes to TX
li x4, 32
li x2, 0x42
txloop:
    sw x2, UART_WDATA_OFFSET(x1)
    addi x4, x4, -1
    bnez x4, txloop

li x31, 1 # flag to indicate about to enter next section

#################
# Reset SPI (2/2)
#################
# reset SPI SRAM
li x1, SPI_BASE
li x2, SPI_BUFFER_OFFSET
add x1, x1, x2

li x11, USB_BASE
li x12, USB_BUFFER_OFFSET
add x11, x11, x12

li x3, 0

# fill SPI and USB SRAM
li x2, 511
sram_loop:
sw x3, 0(x1)
sw x3, 0(x11)

addi x1, x1, 4
addi x11, x11, 4

addi x2, x2, -1
addi x3, x3, 1

bge x2, x0, sram_loop

lw x0, -4(x1) # dummy load of last element of SPI SRAM to reset state
lw x0, -4(x11) # dummy load of last element of USB SRAM to reset state

##################
# Reset Ibex
##################
li x1, 0x8000
lw x0, 0(x1)

##################
# Reset RAM
##################
li x1, RAM_BASE
li x2, RAM_END

ram_loop:
  sw x0, 0(x1)
  addi x1, x1, 4
  bne x1, x2, ram_loop

lw x0, -4(x1)

_hang:
jal x0, _hang
