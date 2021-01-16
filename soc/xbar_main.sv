module xbar_main (
  input  clk_main_i,
  input  clk_fixed_i,
  input  rst_main_ni,
  input  rst_fixed_ni,

  // Host interfaces
  input  tlul_pkg::tl_h2d_t tl_corei_i,
  output tlul_pkg::tl_d2h_t tl_corei_o,
  input  tlul_pkg::tl_h2d_t tl_cored_i,
  output tlul_pkg::tl_d2h_t tl_cored_o,

  // Device interfaces
  output tlul_pkg::tl_h2d_t tl_rom_o,
  input  tlul_pkg::tl_d2h_t tl_rom_i,
  output tlul_pkg::tl_h2d_t tl_ram_main_o,
  input  tlul_pkg::tl_d2h_t tl_ram_main_i,
  output tlul_pkg::tl_h2d_t tl_peri_o,
  input  tlul_pkg::tl_d2h_t tl_peri_i,

  input  scanmode_i
);

  import tlul_pkg::*;
  import tl_main_pkg::*;

  // scanmode_i is currently not used, but provisioned for future use
  // this assignment prevents lint warnings
  logic unused_scanmode;
  assign unused_scanmode = scanmode_i;

  // this s1n doesn't exist yet, but use these signal names to make things
  // easier to wire later
  tl_h2d_t tl_s1n_15_us_h2d ;
  tl_d2h_t tl_s1n_15_us_d2h ;

  tl_h2d_t tl_s1n_15_ds_h2d [2];
  tl_d2h_t tl_s1n_15_ds_d2h [2];

  // Create steering signal
  logic [1:0] dev_sel_s1n_15;

  tl_h2d_t tl_sm1_16_us_h2d [2];
  tl_d2h_t tl_sm1_16_us_d2h [2];

  tl_h2d_t tl_sm1_16_ds_h2d ;
  tl_d2h_t tl_sm1_16_ds_d2h ;

  tl_h2d_t tl_sm1_18_us_h2d [2];
  tl_d2h_t tl_sm1_18_us_d2h [2];

  tl_h2d_t tl_sm1_18_ds_h2d ;
  tl_d2h_t tl_sm1_18_ds_d2h ;

  tl_h2d_t tl_s1n_20_us_h2d ;
  tl_d2h_t tl_s1n_20_us_d2h ;

  tl_h2d_t tl_s1n_20_ds_h2d [3];
  tl_d2h_t tl_s1n_20_ds_d2h [3];

  // Create steering signal
  logic [1:0] dev_sel_s1n_20;


  tl_h2d_t tl_asf_21_us_h2d ;
  tl_d2h_t tl_asf_21_us_d2h ;
  tl_h2d_t tl_asf_21_ds_h2d ;
  tl_d2h_t tl_asf_21_ds_d2h ;

  tl_h2d_t tl_sm1_22_ds_h2d ;
  tl_d2h_t tl_sm1_22_ds_d2h ;

  tl_h2d_t tl_sm1_22_us_h2d ;
  tl_d2h_t tl_sm1_22_us_d2h ;


  assign tl_sm1_16_us_h2d[0] = tl_s1n_15_ds_h2d[0];
  assign tl_s1n_15_ds_d2h[0] = tl_sm1_16_us_d2h[0];

  assign tl_sm1_18_us_h2d[0] = tl_s1n_15_ds_h2d[1];
  assign tl_s1n_15_ds_d2h[1] = tl_sm1_18_us_d2h[0];

  assign tl_sm1_16_us_h2d[1] = tl_s1n_20_ds_h2d[0];
  assign tl_s1n_20_ds_d2h[0] = tl_sm1_16_us_d2h[1];

  assign tl_sm1_18_us_h2d[1] = tl_s1n_20_ds_h2d[1];
  assign tl_s1n_20_ds_d2h[1] = tl_sm1_18_us_d2h[1];

  assign tl_sm1_22_us_h2d = tl_s1n_20_ds_h2d[2];
  assign tl_s1n_20_ds_d2h[2] = tl_sm1_22_us_d2h;

  assign tl_s1n_15_us_h2d = tl_corei_i;
  assign tl_corei_o = tl_s1n_15_us_d2h;

  assign tl_rom_o = tl_sm1_16_ds_h2d;
  assign tl_sm1_16_ds_d2h = tl_rom_i;

  assign tl_ram_main_o = tl_sm1_18_ds_h2d;
  assign tl_sm1_18_ds_d2h = tl_ram_main_i;

  assign tl_s1n_20_us_h2d = tl_cored_i;
  assign tl_cored_o = tl_s1n_20_us_d2h;

  assign tl_peri_o = tl_asf_21_ds_h2d;
  assign tl_asf_21_ds_d2h = tl_peri_i;

  assign tl_asf_21_us_h2d = tl_sm1_22_ds_h2d;
  assign tl_sm1_22_ds_d2h = tl_asf_21_us_d2h;

  always_comb begin
    // default steering to generate error response if address is not within the range
    dev_sel_s1n_15 = 2'd2;
    if ((tl_s1n_15_us_h2d.a_address & ~(ADDR_MASK_ROM)) == ADDR_SPACE_ROM) begin
      dev_sel_s1n_15 = 2'd0;

    end else if ((tl_s1n_15_us_h2d.a_address & ~(ADDR_MASK_RAM_MAIN)) == ADDR_SPACE_RAM_MAIN) begin
      dev_sel_s1n_15 = 2'd1;
    end
  end

  always_comb begin
    // default steering to generate error response if address is not within the range
    dev_sel_s1n_20 = 2'd3;
    if ((tl_s1n_20_us_h2d.a_address & ~(ADDR_MASK_ROM)) == ADDR_SPACE_ROM) begin
      dev_sel_s1n_20 = 2'd0;

    end else if ((tl_s1n_20_us_h2d.a_address & ~(ADDR_MASK_RAM_MAIN)) == ADDR_SPACE_RAM_MAIN) begin
      dev_sel_s1n_20 = 2'd1;

    end else if (
      ((tl_s1n_20_us_h2d.a_address <= (ADDR_MASK_PERI[0] + ADDR_SPACE_PERI[0])) &&
       (tl_s1n_20_us_h2d.a_address >= ADDR_SPACE_PERI[0])) ||
      ((tl_s1n_20_us_h2d.a_address <= (ADDR_MASK_PERI[1] + ADDR_SPACE_PERI[1])) &&
       (tl_s1n_20_us_h2d.a_address >= ADDR_SPACE_PERI[1])) ||
      ((tl_s1n_20_us_h2d.a_address <= (ADDR_MASK_PERI[2] + ADDR_SPACE_PERI[2])) &&
       (tl_s1n_20_us_h2d.a_address >= ADDR_SPACE_PERI[2])) ||
      ((tl_s1n_20_us_h2d.a_address <= (ADDR_MASK_PERI[3] + ADDR_SPACE_PERI[3])) &&
       (tl_s1n_20_us_h2d.a_address >= ADDR_SPACE_PERI[3]))
    ) begin
      dev_sel_s1n_20 = 2'd2;
    end
  end


  // Instantiation phase
  tlul_socket_1n #(
    .HReqDepth (4'h0),
    .HRspDepth (4'h0),
    .DReqDepth ({4{4'h0}}),
    .DRspDepth ({4{4'h0}}),
    .N         (2)
  ) u_s1n_15 (
    .clk_i        (clk_main_i),
    .rst_ni       (rst_main_ni),
    .tl_h_i       (tl_s1n_15_us_h2d),
    .tl_h_o       (tl_s1n_15_us_d2h),
    .tl_d_o       (tl_s1n_15_ds_h2d),
    .tl_d_i       (tl_s1n_15_ds_d2h),
    .dev_select   (dev_sel_s1n_15)
  );
  tlul_socket_m1 #(
    .HReqDepth ({3{4'h0}}),
    .HRspDepth ({3{4'h0}}),
    .DReqDepth (4'h0),
    .DRspDepth (4'h0),
    .M         (2)
  ) u_sm1_16 (
    .clk_i        (clk_main_i),
    .rst_ni       (rst_main_ni),
    .tl_h_i       (tl_sm1_16_us_h2d),
    .tl_h_o       (tl_sm1_16_us_d2h),
    .tl_d_o       (tl_sm1_16_ds_h2d),
    .tl_d_i       (tl_sm1_16_ds_d2h)
  );
  tlul_socket_m1 #(
    .HReqDepth ({3{4'h0}}),
    .HRspDepth ({3{4'h0}}),
    .DReqDepth (4'h0),
    .DRspDepth (4'h0),
    .M         (2)
  ) u_sm1_18 (
    .clk_i        (clk_main_i),
    .rst_ni       (rst_main_ni),
    .tl_h_i       (tl_sm1_18_us_h2d),
    .tl_h_o       (tl_sm1_18_us_d2h),
    .tl_d_o       (tl_sm1_18_ds_h2d),
    .tl_d_i       (tl_sm1_18_ds_d2h)
  );
  tlul_socket_1n #(
    .HReqDepth (4'h0),
    .HRspDepth (4'h0),
    .DReqDepth ({12{4'h0}}),
    .DRspDepth ({12{4'h0}}),
    .N         (3)
  ) u_s1n_20 (
    .clk_i        (clk_main_i),
    .rst_ni       (rst_main_ni),
    .tl_h_i       (tl_s1n_20_us_h2d),
    .tl_h_o       (tl_s1n_20_us_d2h),
    .tl_d_o       (tl_s1n_20_ds_h2d),
    .tl_d_i       (tl_s1n_20_ds_d2h),
    .dev_select   (dev_sel_s1n_20)
  );
  tlul_fifo_async #(
    .ReqDepth        (3),// At least 3 to make async work
    .RspDepth        (3) // At least 3 to make async work
  ) u_asf_21 (
    .clk_h_i      (clk_main_i),
    .rst_h_ni     (rst_main_ni),
    .clk_d_i      (clk_fixed_i),
    .rst_d_ni     (rst_fixed_ni),
    .tl_h_i       (tl_asf_21_us_h2d),
    .tl_h_o       (tl_asf_21_us_d2h),
    .tl_d_o       (tl_asf_21_ds_h2d),
    .tl_d_i       (tl_asf_21_ds_d2h)
  );

  // Replace with sm1_22 at some point
  assign tl_sm1_22_ds_h2d = tl_sm1_22_us_h2d;
  assign tl_sm1_22_us_d2h = tl_sm1_22_ds_d2h;

endmodule
