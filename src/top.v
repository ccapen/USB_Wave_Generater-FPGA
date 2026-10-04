module top (
	input			I_clk,

	input			I_sck,
	input			I_nss,
	input			I_mosi,
	output			O_miso,
	output			O_int,

	output			O_led_run,
	output			O_dclk,
	output	[9:0]	O_data
);

reg [23:0] R_cnt_pll_rst = 24'b0;
reg R_pll_rst;

always @(posedge I_clk) begin
	if(R_cnt_pll_rst != 24'hff_ffff)
		R_cnt_pll_rst <= R_cnt_pll_rst + 1'b1;
	else
		R_cnt_pll_rst <= R_cnt_pll_rst;
	
	R_pll_rst <= (R_cnt_pll_rst != 24'hff_ffff);
end


wire W_mclk;
wire W_mclk_shift;
wire W_lock;

PLL_0 pll_u(
	.refclk		(I_clk),
	.reset		(R_pll_rst),
	.extlock	(W_lock),
	.clk0_out	(W_mclk),
	.clk1_out	(W_mclk_shift),
	.clk2_out	()
);

reg R_mclk_rstn_pre;
reg R_mclk_rstn;

always @(posedge W_mclk) begin
	R_mclk_rstn_pre <= W_lock;
	R_mclk_rstn <= R_mclk_rstn_pre;
end


wire W_miso;

wire	[7:0]	W_spi_wdata;
wire			W_spi_wready;
wire			W_spi_rvalid;
wire	[7:0]	W_spi_rdata;
wire			W_spi_transfer_end;

spi_slave #(
	.CPOL			(0),	//SCLK = CPOL when spi is standby
	.CPHA			(0),	//when CPHA == 0, sample will occur in the first edge, 
							//when CPHA == 1, sample will occur in the second edge
	.BITORDER		("MSB_FIRST"),	//"MSB_FIRST" "LSB_FIRST"
	.DATAWIDTH		(8),	//一次传输的数据位宽
	.ODRVMODE		("ADVANCE"),	//when I_clk frequency lower than (12 * I_sclk frequency), use "ADVANCE"; else use "NORMAL"
	.WDATADELAY		(4)		//delay O_wready to wait I_wdata, must >= 1
) spi_slave_u(
	.I_clk				(W_mclk),	//I_clk frequency must higher than (4 * I_sclk frequency)
	.I_rstn				(R_mclk_rstn),

	.I_wdata			(W_spi_wdata),
	.O_wready			(W_spi_wready),
	.O_rvalid			(W_spi_rvalid),
	.O_rdata			(W_spi_rdata),
	.O_transfer_end		(W_spi_transfer_end),

	.I_csn				(I_nss),
	.I_sclk				(I_sck),
	.I_mosi				(I_mosi),
	.O_miso				(W_miso)
);

assign O_miso = I_nss ? 1'bz : W_miso;


wire	[7:0]	W_output_mode;
wire	[7:0]	W_update_rate_div;
wire	[22:0]	W_sample_points;
wire	[15:0]	W_output_offset;
wire			W_is_run;
wire			W_wave_valid;
wire	[20:0]	W_wave_addr;
wire	[31:0]	W_wave_data;
wire	[3:0]	W_wave_dqm;
wire			W_wave_ready;

protocol_analysis #(
	.MAX_PACKAGE_SIZE	(2048)
) protocol_analysis_u(
	.I_clk				(W_mclk),
	.I_rstn				(R_mclk_rstn),

	.O_wdata			(W_spi_wdata),
	// .I_wready			(W_spi_wready),
	.I_rvalid			(W_spi_rvalid),
	.I_rdata			(W_spi_rdata),
	// .O_int				(O_int),

	.O_output_mode		(W_output_mode),
	.O_update_rate_div	(W_update_rate_div),
	.O_sample_points	(W_sample_points),
	.O_output_offset	(W_output_offset),
	.O_is_run			(W_is_run),
	.O_wave_valid		(W_wave_valid),
	.O_wave_addr		(W_wave_addr),
	.O_wave_data		(W_wave_data),
	.O_wave_dqm			(W_wave_dqm),
	.I_wave_ready		(W_wave_ready)
);

// assign O_int = 1'bz;


wire			W_wvalid	= W_wave_valid;
wire	[20:0]	W_waddr		= W_wave_addr;
wire	[31:0]	W_wdata		= W_wave_data;
wire	[3:0]	W_wdqm		= W_wave_dqm;
assign		W_wave_ready	= W_wready;

wire			W_rvalid;
wire	[20:0]	W_raddr;
wire	[3:0]	W_rdqm;
wire			W_rready;

wire			W_out_valid;
wire	[20:0]	W_out_addr;
wire	[31:0]	W_out_data;
wire	[3:0]	W_out_dqm;


dac_output #(
	.BUFFER_SIZE_POINT	(2048),
	.REQUEST_ONCE_POINT	(256)
) dac_output_u(
	.I_clk				(W_mclk),
	.I_rstn				(R_mclk_rstn),

	.I_output_mode		(W_output_mode),
	.I_update_rate_div	(W_update_rate_div),
	.I_sample_points	(W_sample_points),
	.I_output_offset	(W_output_offset[9:0]),
	.I_is_run			(W_is_run),
	.O_read_position	(O_int),
	.I_wave_valid		(W_wave_valid),
	.I_wave_addr		(W_wave_addr),

	.O_rvalid			(W_rvalid),
	.O_raddr			(W_raddr),
	.O_rdqm				(W_rdqm),
	.I_rready			(W_rready),

	.I_out_valid		(W_out_valid),
	.I_out_addr			(W_out_addr),
	.I_out_data			(W_out_data),
	.I_out_dqm			(W_out_dqm),

	.O_dclk				(O_dclk),
	.O_data				(O_data)
);

assign O_led_run = !W_is_run;


wire			W_sdram_clk;
wire			W_sdram_cke;
wire			W_sdram_rasn;
wire			W_sdram_casn;
wire			W_sdram_wen;
wire			W_sdram_csn;
wire [1:0]		W_sdram_bank;
wire [10:0]		W_sdram_addr;
wire [31:0]		W_sdram_data_i;
wire			W_sdram_data_en;
wire [31:0]		W_sdram_data_o;
wire [3:0]		W_sdram_dqm;

wire [31:0]		W_dq = W_sdram_data_en ? W_sdram_data_o : 32'bz;
assign			W_sdram_data_i = W_dq;

EG_PHY_SDRAM_2M_32 sdram(
	.clk	(W_sdram_clk),
	.ras_n	(W_sdram_rasn),
	.cas_n	(W_sdram_casn),
	.we_n	(W_sdram_wen),
	.addr	(W_sdram_addr),
	.ba		(W_sdram_bank),
	.dq		(W_dq),
	.cs_n	(W_sdram_csn),
	.dm0	(W_sdram_dqm[0]),
	.dm1	(W_sdram_dqm[1]),
	.dm2	(W_sdram_dqm[2]),
	.dm3	(W_sdram_dqm[3]),
	.cke	(W_sdram_cke)
);

sdram_controller #(
	.CLK_FREQ				(125_000_000),
	.ADDRRANK				("RBC"),	//"BRC" "RBC"	//{BANK, ROW, COLUMN} or {ROW, BANK, COLUMN}
	.ADDRWIDTH				(21),
	.DATAWIDTH				(32),
	.BANKNUM				(4),
	.ROWNUM					(2048),
	.COLNUM					(256),
	.PHYADDRWIDTH			(11),
	.PHYBANKWIDTH			(2),
	.PHYDQMWIDTH			(4),
	.CASLATENCY				(3),
	.POWERUP_DELAYMS		(1000),
	.BURSTLENGTH			(4),
	.BURSTTYPE				("SEQUENTIAL"),		//"SEQUENTIAL" "INTERLEAVE"

	.INWBUFFERDEPTH			(0),		//must be 2**n or 0
	.WDATABATCHLENGTH		(0),		//must < INWBUFFERDEPTH, or be 0
	.WMAXBATCHDELAY			(0),		//if it == 0, means infinity
	.INRBUFFERDEPTH			(32),		//must be 2**n or 0
	.RDATABATCHLENGTH		(16),		//must < INRBUFFERDEPTH, or be 0
	.RMAXBATCHDELAY			(40),		//if it == 0, means infinity

	.WPREACTIVEDEPTH		(8),		//must be 2**n and should >= 8
	.RPREACTIVEDEPTH		(8),		//must be 2**n and should >= 8
	.RWBUFFERDEPTH			(4),		//must be 2**n and >= 4
	.AUTO_REFRESH			("ENABLE"),
	.REFRESH_TIME_MS		(64),
	.REFRESH_LINE			(4096),
	.REFRESH_SLICE			(16)		//suggest >= 4, must >= 2, must <= REFRESH_TIME_MS
) sdram_controller_u(
	.I_clk					(W_mclk),
	.I_dq_retclk			(W_mclk),
	.I_rstn					(R_mclk_rstn),

	.I_wvalid				(W_wvalid),
	.I_waddr				(W_waddr),
	.I_wdata				(W_wdata),
	.I_wdqm					(W_wdqm),
	.O_wready				(W_wready),

	.I_rvalid				(W_rvalid),
	.I_raddr				(W_raddr),
	.I_rdqm					(W_rdqm),
	.O_rready				(W_rready),

	.O_out_valid			(W_out_valid),
	.O_out_addr				(W_out_addr),
	.O_out_data				(W_out_data),
	.O_out_dqm				(W_out_dqm),

	.O_sdram_clk			(W_sdram_clk),
	.O_sdram_cke			(W_sdram_cke),
	.O_sdram_csn			(W_sdram_csn),
	.O_sdram_rasn			(W_sdram_rasn),
	.O_sdram_casn			(W_sdram_casn),
	.O_sdram_wen			(W_sdram_wen),
	.O_sdram_bank			(W_sdram_bank),
	.O_sdram_addr			(W_sdram_addr),
	.I_sdram_data			(W_sdram_data_i),
	.O_sdram_data_en		(W_sdram_data_en),
	.O_sdram_data			(W_sdram_data_o),
	.O_sdram_dqm			(W_sdram_dqm)
);


endmodule
