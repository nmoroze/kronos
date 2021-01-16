// Copyright lowRISC contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

module top_earlgrey #(
  parameter bit IbexPipeLine = 0
) (
  // Clock and Reset
  input        clk_i,
  input        rst_ni,

  // USB clock
  input        clk_usb_48mhz_i,

  // Dedicated I/O
  input        dio_spi_device_sck_i,
  input        dio_spi_device_csb_i,
  input        dio_spi_device_mosi_i,
  output logic dio_spi_device_miso_o,
  output logic dio_spi_device_miso_en_o,
  input        dio_uart_rx_i,
  output logic dio_uart_tx_o,
  output logic dio_uart_tx_en_o,
  input        dio_usbdev_sense_i,
  output logic dio_usbdev_pullup_o,
  output logic dio_usbdev_pullup_en_o,
  input        dio_usbdev_dp_i,
  output logic dio_usbdev_dp_o,
  output logic dio_usbdev_dp_en_o,
  input        dio_usbdev_dn_i,
  output logic dio_usbdev_dn_o,
  output logic dio_usbdev_dn_en_o,

  input        scanmode_i  // 1 for Scan
);

  import tlul_pkg::*;
  import top_pkg::*;
  import tl_main_pkg::*;

  tl_h2d_t  tl_corei_h_h2d;
  tl_d2h_t  tl_corei_h_d2h;

  tl_h2d_t  tl_cored_h_h2d;
  tl_d2h_t  tl_cored_h_d2h;

  tl_h2d_t  tl_uart_d_h2d;
  tl_d2h_t  tl_uart_d_d2h;
  tl_h2d_t  tl_spi_device_d_h2d;
  tl_d2h_t  tl_spi_device_d_d2h;
  tl_h2d_t  tl_usbdev_d_h2d;
  tl_d2h_t  tl_usbdev_d_d2h;

  tl_h2d_t tl_rom_d_h2d;
  tl_d2h_t tl_rom_d_d2h;
  tl_h2d_t tl_ram_main_d_h2d;
  tl_d2h_t tl_ram_main_d_d2h;

  tl_h2d_t tl_main_h_h2d;
  tl_d2h_t tl_main_h_d2h;
  tl_h2d_t tl_peri_d_h2d;
  tl_d2h_t tl_peri_d_d2h;

  assign tl_main_h_h2d = tl_peri_d_h2d;
  assign tl_peri_d_d2h = tl_main_h_d2h;

  //reset wires declaration
  logic sys_rst_n;
  logic sys_fixed_rst_n;
  logic spi_device_rst_n;
  logic usb_rst_n;

  //clock wires declaration
  logic main_clk;
  logic fixed_clk;
  logic usb_clk;

  // uart
  logic        cio_uart_rx_p2d;
  logic        cio_uart_tx_d2p;
  logic        cio_uart_tx_en_d2p;
  // spi_device
  logic        cio_spi_device_sck_p2d;
  logic        cio_spi_device_csb_p2d;
  logic        cio_spi_device_mosi_p2d;
  logic        cio_spi_device_miso_d2p;
  logic        cio_spi_device_miso_en_d2p;
  // usbdev
  logic        cio_usbdev_sense_p2d;
  logic        cio_usbdev_dp_p2d;
  logic        cio_usbdev_dn_p2d;
  logic        cio_usbdev_pullup_d2p;
  logic        cio_usbdev_pullup_en_d2p;
  logic        cio_usbdev_dp_d2p;
  logic        cio_usbdev_dp_en_d2p;
  logic        cio_usbdev_dn_d2p;
  logic        cio_usbdev_dn_en_d2p;


  // clock assignments
  assign main_clk = clk_i;
  assign fixed_clk = clk_i;

  // Separate clock input for USB clock
  assign usb_clk = clk_usb_48mhz_i;

  assign sys_rst_n = rst_ni;

  // Non-root reset assignments
  assign sys_fixed_rst_n = sys_rst_n;
  assign spi_device_rst_n = sys_rst_n;
  // Reset synchronizer for USB
  logic usb_rst_sync_out;
  prim_flop_2sync #(
    .Width(1)
  ) usb_reset_sync (
    .clk_i(usb_clk),
    .rst_ni(sys_rst_n),
    .d(1'b1),
    .q(usb_rst_sync_out)
  );
  // & is redundant, but necessary for our toolchain to model async reset
  // correctly. without it, the reset signal has two hops to reset the USB,
  // first to reset the sync registers, the output of which has to then go and
  // reset the USB registers. This would happen asynchronously in real hardware,
  // but it would require multiple steps with Yosys.
  assign usb_rst_n = sys_rst_n & usb_rst_sync_out;

  // processor core
  rv_core_ibex #(
    .PMPEnable           (0),
    .PMPGranularity      (0),
    .PMPNumRegions       (4),
    .MHPMCounterNum      (8),
    .MHPMCounterWidth    (40),
    .RV32E               (0),
    .RV32M               (1),
    // .DmHaltAddr          (ADDR_SPACE_DEBUG_MEM + dm::HaltAddress),
    // .DmExceptionAddr     (ADDR_SPACE_DEBUG_MEM + dm::ExceptionAddress),
    .PipeLine            (IbexPipeLine)
  ) core (
    // clock and reset
    .clk_i                (main_clk),
    .rst_ni               (sys_rst_n),
    .test_en_i            (1'b0),
    // static pinning
    .hart_id_i            (32'b0),
    .boot_addr_i          (ADDR_SPACE_ROM),
    // TL-UL buses
    .tl_i_o               (tl_corei_h_h2d),
    .tl_i_i               (tl_corei_h_d2h),
    .tl_d_o               (tl_cored_h_h2d),
    .tl_d_i               (tl_cored_h_d2h),
    // interrupts
    .irq_software_i       (1'b0),
    .irq_timer_i          (1'b0),
    .irq_external_i       (1'b0),
    .irq_fast_i           (15'b0),// PLIC handles all peripheral interrupts
    .irq_nm_i             (1'b0),// TODO - add and connect alert responder
    // debug interface
    .debug_req_i          (1'b0),
    // CPU control signals
    .fetch_enable_i       (1'b1),
    .core_sleep_o         ()
  );

  // ROM device
  logic        rom_req;
  logic [10:0] rom_addr;
  logic [31:0] rom_rdata;
  logic        rom_rvalid;

  tlul_adapter_sram #(
    .SramAw(11),
    .SramDw(32),
    .Outstanding(2),
    .ErrOnWrite(1)
  ) tl_adapter_rom (
    .clk_i   (main_clk),
    .rst_ni   (sys_rst_n),

    .tl_i     (tl_rom_d_h2d),
    .tl_o     (tl_rom_d_d2h),

    .req_o    (rom_req),
    .gnt_i    (1'b1), // Always grant as only one requester exists
    .we_o     (),
    .addr_o   (rom_addr),
    .wdata_o  (),
    .wmask_o  (),
    .rdata_i  (rom_rdata),
    .rvalid_i (rom_rvalid),
    .rerror_i (2'b00)
  );

  prim_rom #(
    .Width(32),
    .Depth(2048)
  ) u_rom_rom (
    .clk_i   (main_clk),
    .rst_ni   (sys_rst_n),
    .cs_i     (rom_req),
    .addr_i   (rom_addr),
    .dout_o   (rom_rdata),
    .dvalid_o (rom_rvalid)
  );

  // sram device
  logic        ram_main_req;
  logic        ram_main_we;
  logic [10:0]  ram_main_addr;
  logic [31:0] ram_main_wdata;
  logic [31:0] ram_main_wmask;
  logic [31:0] ram_main_rdata;
  logic        ram_main_rvalid;

  tlul_adapter_sram #(
    .SramAw(11),
    .SramDw(32),
    .Outstanding(2)
  ) tl_adapter_ram_main (
    .clk_i   (main_clk),
    .rst_ni   (sys_rst_n),
    .tl_i     (tl_ram_main_d_h2d),
    .tl_o     (tl_ram_main_d_d2h),

    .req_o    (ram_main_req),
    .gnt_i    (1'b1), // Always grant as only one requester exists
    .we_o     (ram_main_we),
    .addr_o   (ram_main_addr),
    .wdata_o  (ram_main_wdata),
    .wmask_o  (ram_main_wmask),
    .rdata_i  (ram_main_rdata),
    .rvalid_i (ram_main_rvalid),
    .rerror_i (2'b00)
  );

  prim_ram_1p #(
    .Width(32),
    .Depth(2048), // small test
    .DataBitsPerMask(8)
  ) u_ram1p_ram_main (
    .clk_i   (main_clk),
    .rst_ni   (sys_rst_n),

    .req_i    (ram_main_req),
    .write_i  (ram_main_we),
    .addr_i   (ram_main_addr),
    .wdata_i  (ram_main_wdata),
    .wmask_i  (ram_main_wmask),
    .rvalid_o (ram_main_rvalid),
    .rdata_o  (ram_main_rdata)
  );

  uart uart (
      .tl_i (tl_uart_d_h2d),
      .tl_o (tl_uart_d_d2h),

      // Input
      .cio_rx_i    (cio_uart_rx_p2d),

      // Output
      .cio_tx_o    (cio_uart_tx_d2p),
      .cio_tx_en_o (cio_uart_tx_en_d2p),

      // Interrupt
      .intr_tx_watermark_o  (intr_uart_tx_watermark),
      .intr_rx_watermark_o  (intr_uart_rx_watermark),
      .intr_tx_empty_o      (intr_uart_tx_empty),
      .intr_rx_overflow_o   (intr_uart_rx_overflow),
      .intr_rx_frame_err_o  (intr_uart_rx_frame_err),
      .intr_rx_break_err_o  (intr_uart_rx_break_err),
      .intr_rx_timeout_o    (intr_uart_rx_timeout),
      .intr_rx_parity_err_o (intr_uart_rx_parity_err),

      .clk_i (fixed_clk),
      .rst_ni (sys_fixed_rst_n)
  );

  spi_device spi_device (
    .tl_i (tl_spi_device_d_h2d),
    .tl_o (tl_spi_device_d_d2h),

    // Input
    .cio_sck_i     (cio_spi_device_sck_p2d),
    .cio_csb_i     (cio_spi_device_csb_p2d),
    .cio_mosi_i    (cio_spi_device_mosi_p2d),

    // Output
    .cio_miso_o    (cio_spi_device_miso_d2p),
    .cio_miso_en_o (cio_spi_device_miso_en_d2p),

    // Interrupt
    .intr_rxf_o         (intr_spi_device_rxf),
    .intr_rxlvl_o       (intr_spi_device_rxlvl),
    .intr_txlvl_o       (intr_spi_device_txlvl),
    .intr_rxerr_o       (intr_spi_device_rxerr),
    .intr_rxoverflow_o  (intr_spi_device_rxoverflow),
    .intr_txunderflow_o (intr_spi_device_txunderflow),
    .scanmode_i   (scanmode_i),

    .clk_i (fixed_clk),
    .rst_ni (spi_device_rst_n)
  );

  usbdev usbdev (
      .tl_i (tl_usbdev_d_h2d),
      .tl_o (tl_usbdev_d_d2h),

      // Differential data - Currently not used.
      .cio_d_i          (1'b0),
      .cio_d_o          (),
      .cio_se0_o        (),

      // Single-ended data
      .cio_dp_i         (cio_usbdev_dp_p2d),
      .cio_dn_i         (cio_usbdev_dn_p2d),
      .cio_dp_o         (cio_usbdev_dp_d2p),
      .cio_dn_o         (cio_usbdev_dn_d2p),

      // Non-data I/O
      .cio_sense_i      (cio_usbdev_sense_p2d),
      .cio_oe_o         (cio_usbdev_dp_en_d2p),
      .cio_tx_mode_se_o (),
      .cio_pullup_en_o  (cio_usbdev_pullup_en_d2p),
      .cio_suspend_o    (),

      // Interrupt
      .intr_pkt_received_o    (intr_usbdev_pkt_received),
      .intr_pkt_sent_o        (intr_usbdev_pkt_sent),
      .intr_disconnected_o    (intr_usbdev_disconnected),
      .intr_host_lost_o       (intr_usbdev_host_lost),
      .intr_link_reset_o      (intr_usbdev_link_reset),
      .intr_link_suspend_o    (intr_usbdev_link_suspend),
      .intr_link_resume_o     (intr_usbdev_link_resume),
      .intr_av_empty_o        (intr_usbdev_av_empty),
      .intr_rx_full_o         (intr_usbdev_rx_full),
      .intr_av_overflow_o     (intr_usbdev_av_overflow),
      .intr_link_in_err_o     (intr_usbdev_link_in_err),
      .intr_rx_crc_err_o      (intr_usbdev_rx_crc_err),
      .intr_rx_pid_err_o      (intr_usbdev_rx_pid_err),
      .intr_rx_bitstuff_err_o (intr_usbdev_rx_bitstuff_err),
      .intr_frame_o           (intr_usbdev_frame),
      .intr_connected_o       (intr_usbdev_connected),

      .clk_i (fixed_clk),
      .clk_usb_48mhz_i (usb_clk),
      .rst_ni (sys_fixed_rst_n),
      .rst_usb_48mhz_ni (usb_rst_n)
  );

  // USB assignments
  assign cio_usbdev_dn_en_d2p = cio_usbdev_dp_en_d2p; // have a single output enable only
  assign cio_usbdev_pullup_d2p = 1'b1;

  xbar_main u_xbar_main (
    .clk_main_i (main_clk),
    .clk_fixed_i (fixed_clk),
    .rst_main_ni (sys_rst_n),
    .rst_fixed_ni (sys_fixed_rst_n),
    .tl_corei_i         (tl_corei_h_h2d),
    .tl_corei_o         (tl_corei_h_d2h),
    .tl_cored_i         (tl_cored_h_h2d),
    .tl_cored_o         (tl_cored_h_d2h),
    .tl_rom_o           (tl_rom_d_h2d),
    .tl_rom_i           (tl_rom_d_d2h),
    .tl_ram_main_o      (tl_ram_main_d_h2d),
    .tl_ram_main_i      (tl_ram_main_d_d2h),
    .tl_peri_o          (tl_peri_d_h2d),
    .tl_peri_i          (tl_peri_d_d2h),

    .scanmode_i
  );
  xbar_peri u_xbar_peri (
    .clk_peri_i (fixed_clk),
    .rst_peri_ni (sys_fixed_rst_n),
    .tl_main_i       (tl_main_h_h2d),
    .tl_main_o       (tl_main_h_d2h),
    .tl_uart_o       (tl_uart_d_h2d),
    .tl_uart_i       (tl_uart_d_d2h),
    .tl_spi_device_o (tl_spi_device_d_h2d),
    .tl_spi_device_i (tl_spi_device_d_d2h),
    .tl_usbdev_o     (tl_usbdev_d_h2d),
    .tl_usbdev_i     (tl_usbdev_d_d2h),

    .scanmode_i
  );

  assign cio_spi_device_sck_p2d   = dio_spi_device_sck_i;
  assign cio_spi_device_csb_p2d   = dio_spi_device_csb_i;
  assign cio_spi_device_mosi_p2d  = dio_spi_device_mosi_i;
  assign dio_spi_device_miso_o    = cio_spi_device_miso_d2p;
  assign dio_spi_device_miso_en_o = cio_spi_device_miso_en_d2p;
  assign cio_uart_rx_p2d          = dio_uart_rx_i;
  assign dio_uart_tx_o            = cio_uart_tx_d2p;
  assign dio_uart_tx_en_o         = cio_uart_tx_en_d2p;
  assign cio_usbdev_sense_p2d     = dio_usbdev_sense_i;
  assign dio_usbdev_pullup_o      = cio_usbdev_pullup_d2p;
  assign dio_usbdev_pullup_en_o   = cio_usbdev_pullup_en_d2p;
  assign cio_usbdev_dp_p2d        = dio_usbdev_dp_i;
  assign dio_usbdev_dp_o          = cio_usbdev_dp_d2p;
  assign dio_usbdev_dp_en_o       = cio_usbdev_dp_en_d2p;
  assign cio_usbdev_dn_p2d        = dio_usbdev_dn_i;
  assign dio_usbdev_dn_o          = cio_usbdev_dn_d2p;
  assign dio_usbdev_dn_en_o       = cio_usbdev_dn_en_d2p;

  // make sure scanmode_i is never X (including during reset)
  `ASSERT_KNOWN(scanmodeKnown, scanmode_i, clk_i, 0)

endmodule
