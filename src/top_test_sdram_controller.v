module top_test_sdram_controller (
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

// reg R_mclk_rstn;

// always @(posedge W_mclk) begin
// 	R_mclk_rstn <= W_lock;
// end


wire R_mclk_rstn;

time_delay_ms #(
	.CLK_FREQ	(125_000_000),
	.DELAY_MS	(5000)
) time_delay_ms_mclk_rstn(
	.I_clk		(W_mclk),

	.I_rstn		(W_lock),
	.O_rstn		(R_mclk_rstn)
);


wire W_miso;

wire	[7:0]	W_spi_wdata;
wire			W_spi_wready;
wire			W_spi_rvalid;
wire	[7:0]	W_spi_rdata;
wire			W_spi_transfer_end;

spi_slave #(
	.CPOL			(0),	//SCLK = CPOL when spi is standby
	.CPHA			(1),	//when CPHA == 0, sample will occur in the first edge, 
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


wire			W_is_run;
wire	[7:0]	W_update_rate_div;
wire	[22:0]	W_sample_points;
wire			W_wave_valid;
wire	[20:0]	W_wave_addr;
wire	[31:0]	W_wave_data;
wire	[3:0]	W_wave_dqm;
wire			W_wave_ready = W_wave_valid;

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

	.O_is_run			(W_is_run),
	.O_update_rate_div	(W_update_rate_div),
	.O_sample_points	(W_sample_points),
	.O_wave_valid		(W_wave_valid),
	.O_wave_addr		(W_wave_addr),
	.O_wave_data		(W_wave_data),
	.O_wave_dqm			(W_wave_dqm),
	.I_wave_ready		(W_wave_ready)
);

assign O_int = 1'bz;


wire W_clk_en;

en_clk_divider #(
	.CLK_FREQ		(125_000_000),
	.EN_FREQ		(2),
	// .CLK_DIVIDE		(CLK_FREQ / EN_FREQ),
	.EN_POSITION	("END")		//"START" "END"
) en_clk_divider_u(
	.I_clk			(W_mclk),
	.I_rstn			(R_mclk_rstn),

	.O_clk_en		(W_clk_en)
);

reg R_led;

always @(posedge W_mclk) begin
	R_led <= W_clk_en ? (!R_led) : R_led;
end

assign O_led_run = R_led;



wire			W_wvalid;
wire	[20:0]	W_waddr;
wire	[31:0]	W_wdata;
wire	[3:0]	W_wdqm;
wire			W_wready;

wire			W_rvalid;
wire	[20:0]	W_raddr;
wire	[3:0]	W_rdqm;
wire			W_rready;

wire			W_out_valid;
wire	[20:0]	W_out_addr;
wire	[31:0]	W_out_data;
wire	[3:0]	W_out_dqm;


reg R_rwmix_wr;
reg R_rwmix_rd;
reg R_wvalid;
reg R_rvalid;
reg [21:0] R_test_waddr;
reg [20:0] R_test_raddr;

// reg [21:0] R_test_addr;

always @(posedge W_mclk or negedge R_mclk_rstn) begin
	if(!R_mclk_rstn)
		R_rwmix_wr <= 1'b1;
	else if(W_wready || W_rready)
		R_rwmix_wr <= !R_rwmix_wr;
	else 
		R_rwmix_wr <= R_rwmix_wr;

	if(!R_mclk_rstn)
		R_rwmix_rd <= 1'b0;
	else if(W_wready || W_rready)
		R_rwmix_rd <= !R_rwmix_rd;
	else 
		R_rwmix_rd <= R_rwmix_rd;
	
	// if(!R_mclk_rstn)
	// 	R_wvalid <= 1'b0;
	// else 
	// 	R_wvalid <= ;
	
	// if(!R_mclk_rstn)
	// 	R_rvalid <= 1'b0;
	// else 
	// 	R_rvalid <= ;
	
	if(!R_mclk_rstn)
		R_test_waddr <= 22'b0;// + 21'd1024;
	else if(W_wready)
		R_test_waddr <= R_test_waddr + 1'b1;
	else 
		R_test_waddr <= R_test_waddr;

	if(!R_mclk_rstn)
		R_test_raddr <= 21'b0;
	else if(W_rready)
		R_test_raddr <= R_test_raddr + 1'b1;
	else 
		R_test_raddr <= R_test_raddr;
end

// //continuous read
// assign W_wvalid	= (R_test_waddr != {21{1'b1}});
// assign W_waddr	= R_test_waddr;
// assign W_wdata	= {11'b0 ,R_test_waddr};
// assign W_wdqm	= 4'b0;

// assign W_rvalid	= (R_test_waddr == {21{1'b1}});
// assign W_raddr	= R_test_raddr;
// assign W_rdqm	= 4'b0;
// //end continuous read

//bank interleave read
assign W_wvalid	= (!R_test_waddr[21]);
assign W_waddr	= R_test_waddr[20:0];
assign W_wdata	= {11'b0 ,R_test_waddr[20:0]};
assign W_wdqm	= 4'b0;

assign W_rvalid	= R_test_waddr[21];
assign W_raddr	= {R_test_raddr[2], R_test_raddr[20:3], R_test_raddr[1:0]};
assign W_rdqm	= 4'b0;
//end bank interleave read

// //read write mix
// assign W_wvalid	= R_rwmix_wr;
// assign W_waddr	= R_test_waddr;
// assign W_wdata	= {11'b0 ,R_test_waddr};
// assign W_wdqm	= 4'b0;

// assign W_rvalid	= R_rwmix_rd;
// assign W_raddr	= R_test_raddr;
// // assign W_raddr	= {R_test_raddr[1], R_test_raddr[20:2], R_test_raddr[0]};
// assign W_rdqm	= 4'b0;
// //end read write mix



reg R_is_error;
reg R_have_error;

always @(posedge W_mclk or negedge R_mclk_rstn) begin
	if(!R_mclk_rstn)
		R_is_error <= 1'b0;
	else 
		R_is_error <= W_out_valid && (W_out_addr != W_out_data);

	if(!R_mclk_rstn)
		R_have_error <= 1'b0;
	else if(R_have_error)
		R_have_error <= 1'b1;
	else 
		R_have_error <= R_is_error;
end





wire W_powerup_rstn;

time_delay_ms #(
	.CLK_FREQ	(125_000_000),
	.DELAY_MS	(5000)
) time_delay_ms_u(
	.I_clk		(W_mclk),

	.I_rstn		(R_mclk_rstn),
	.O_rstn		(W_powerup_rstn)
);



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
	.ADDRRANK				("BRC"),	//"BRC" "RBC"	//{BANK, ROW, COLUMN} or {ROW, BANK, COLUMN}
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
	.INRBUFFERDEPTH			(0),		//must be 2**n or 0
	.RDATABATCHLENGTH		(0),		//must < INRBUFFERDEPTH, or be 0
	.RMAXBATCHDELAY			(0),		//if it == 0, means infinity

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
	.I_rstn					(R_mclk_rstn),// && W_powerup_rstn),

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













reg [10:0] R_cnt;
reg [9:0] R_data;

always @(posedge W_mclk or negedge R_mclk_rstn) begin
	if(!R_mclk_rstn)
		R_cnt <= 11'b0;
	else 
		R_cnt <= R_cnt + 11'd128;
end

always @(posedge W_mclk) begin
	R_data <= R_cnt[10] ? (~R_cnt[9:0]) : R_cnt[9:0];
end

EG_LOGIC_ODDR #(
	.ASYNCRST	("ENABLE"))
oddr_dclk(
	.q		(O_dclk),
	.clk	(W_mclk),
	.d1		(1'b1),
	.d0		(1'b0),
	.rst	(!R_mclk_rstn)
);

assign O_data = R_data;


endmodule
