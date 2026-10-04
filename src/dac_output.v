module dac_output #(
	parameter BUFFER_SIZE_POINT		= 2048,
	parameter REQUEST_ONCE_POINT	= 256
) (
	input			I_clk,
	input			I_rstn,

	input	[7:0]	I_output_mode,
	input	[7:0]	I_update_rate_div,
	input	[22:0]	I_sample_points,
	input	[9:0]	I_output_offset,
	input			I_is_run,
	output			O_read_position,
	input			I_wave_valid,
	input	[20:0]	I_wave_addr,
	
	output			O_rvalid,
	output	[20:0]	O_raddr,
	output	[3:0]	O_rdqm,
	input			I_rready,

	input			I_out_valid,
	input	[20:0]	I_out_addr,
	input	[31:0]	I_out_data,
	input	[3:0]	I_out_dqm,

	output			O_dclk,
	output	[9:0]	O_data
);

localparam PTADDRWIDTH = $clog2(REQUEST_ONCE_POINT);


reg R_read_position;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_read_position <= 1'b0;
	else if(I_out_valid && (I_out_addr == 21'b0))
		R_read_position <= 1'b0;
	else if(I_out_valid && (I_out_addr == I_sample_points[22:2]))
		R_read_position <= 1'b1;
	else 
		R_read_position <= R_read_position;
end

assign O_read_position = R_read_position;


reg R_buffer_half_new;
reg R_buffer_end_new;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_buffer_half_new <= 1'b0;
	else if(I_wave_valid && (I_wave_addr == I_sample_points[22:2]))
		R_buffer_half_new <= 1'b1;
	else if(I_out_valid && (I_out_addr == I_sample_points[22:2]))
		R_buffer_half_new <= 1'b0;
	else 
		R_buffer_half_new <= R_buffer_half_new;

	if(!I_rstn)
		R_buffer_end_new <= 1'b0;
	else if(I_wave_valid && (I_wave_addr == (I_sample_points[22:1] - 1'b1)))
		R_buffer_end_new <= 1'b1;
	else if(I_out_valid && (I_out_addr == (I_sample_points[22:1] - 1'b1)))
		R_buffer_end_new <= 1'b0;
	else 
		R_buffer_end_new <= R_buffer_end_new;
end


wire W_buffer_is_afull;
wire W_point_ready;
reg R_point_valid;
reg [PTADDRWIDTH-1:0] R_cnt_point;
reg [21:0] R_point_addr;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_point_valid <= 1'b0;
	else if((!I_is_run) || ((R_cnt_point == (REQUEST_ONCE_POINT - 1'b1)) && W_point_ready && W_buffer_is_afull))
		R_point_valid <= 1'b0;
	else if(I_is_run && (!W_buffer_is_afull))
		R_point_valid <= 1'b1;
	else 
		R_point_valid <= R_point_valid;

	if(!I_rstn)
		R_cnt_point <= {PTADDRWIDTH{1'b0}};
	else if((!I_is_run) || ((R_cnt_point == (REQUEST_ONCE_POINT - 1'b1)) && W_point_ready))
		R_cnt_point <= {PTADDRWIDTH{1'b0}};
	else if(W_point_ready)
		R_cnt_point <= R_cnt_point + 1'b1;
	else 
		R_cnt_point <= R_cnt_point;

	if(!I_rstn)
		R_point_addr <= 22'b0;
	else if((!I_is_run) || (I_is_run && (R_point_addr == (I_sample_points - 1'b1)) && W_point_ready))
		R_point_addr <= 22'b0;
	else if(W_point_ready)
		R_point_addr <= R_point_addr + 1'b1;
	else 
		R_point_addr <= R_point_addr;
end

wire			W_buf_rvalid;
// wire	[31:0]	W_buf_rdata;
wire	[1:0]	W_buf_rmask;
wire			W_buf_rready;

width_joint #(
	.WDATAWIDTH		(16),
	.RDATAWIDTH		(32),	//must be (WDATAWIDTH * n)
	.ENDIAN			("BIG"),		//"BIG" "LITTLE"
	.ADDRORDER		("INCREASE")	//"INCREASE" "DECREASE"
) width_convert_joint(
	.I_clk				(I_clk),
	.I_rstn				(I_rstn),

	.I_wvalid			(R_point_valid),
	.I_wdata			(16'b0),
	.I_waddr			(R_point_addr[0]),
	.I_wlast			(R_point_addr == (I_sample_points - 1'b1)),
	.O_wready			(W_point_ready),

	.O_rvalid			(W_buf_rvalid),
	.O_rdata			(),
	.O_rmask			(W_buf_rmask),
	.I_rready			(W_buf_rready)
);

reg [20:0] R_raddr;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_raddr <= 21'b0;
	else if((!I_is_run) || (I_is_run && (R_raddr == (I_sample_points[22:1] + I_sample_points[0] - 1'b1)) && W_buf_rready))
		R_raddr <= 21'b0;
	else if(W_buf_rready)
		R_raddr <= R_raddr + 1'b1;
	else 
		R_raddr <= R_raddr;
end

assign O_rvalid = W_buf_rvalid;
assign O_raddr = R_raddr;
assign O_rdqm = {{2{W_buf_rmask[1]}}, {2{W_buf_rmask[0]}}};
assign W_buf_rready = I_rready;

// wire W_buf_full;
// wire W_buf_empty;
// wire W_buf_re;
// wire [24:0] W_buf_rdata;
// assign W_buf_rready = (!W_buf_full) && W_buf_rvalid;

// simple_sync_fifo #(
// 	.DATAWIDTH		(25),
// 	.DATADEPTH		(32),	//must be 2**n
// 	.SHOWAHEAD		("ENABLE")	//"ENABLE" "DISABLE"
// ) simple_sync_fifo_u(
// 	.I_clk			(I_clk),
// 	.I_rstn			(I_rstn),

// 	.I_we			(W_buf_rready),
// 	.I_wdata		({R_raddr, {{2{W_buf_rmask[1]}}, {2{W_buf_rmask[0]}}}}),
// 	.O_full			(W_buf_full),

// 	.I_re			(W_buf_re),
// 	.O_rdata		(W_buf_rdata),
// 	.O_empty		(W_buf_empty)
// );

// data_batch #(
// 	.DATAWIDTH		(25),
// 	.BUFFERDEPTH	(32),
// 	.BATCH_LENGTH	(16),
// 	.MAX_DELAY		(40)
// ) data_batch_u(
// 	.I_clk			(I_clk),
// 	.I_rstn			(I_rstn),

// 	.I_we			(W_buf_rready),

// 	.O_re			(W_buf_re),
// 	.I_rdata		(W_buf_rdata),
// 	.I_empty		(W_buf_empty),

// 	.O_valid		(O_rvalid),
// 	.O_data			({O_raddr, O_rdqm}),
// 	.I_ready		(I_rready)
// );




localparam FIFODEPTH_P0 = 2**($clog2(BUFFER_SIZE_POINT / 2));
localparam FIFODEPTH_P1 = (FIFODEPTH_P0 > 8192) ? 8192 : FIFODEPTH_P0;
localparam FIFODEPTH_P2 = (FIFODEPTH_P1 < 512) ? 512 : FIFODEPTH_P1;
localparam FIFODEPTH = FIFODEPTH_P2;

wire W_sa_re;
wire [35:0] W_sa_rdata;
wire W_sa_empty;
wire W_buffer_afull;
wire W_buffer_aempty;

dbclk_fifo_anlogic #(
	.WDATAWIDTH		(36),	//must be 1-432
	.WDATADEPTH		(FIFODEPTH),	//only 5 values can be selected, [512, 1024, 2048, 4096, 8192]
	.RDATAWIDTH		(36),	//only 5 values can be selected, must >= 1, must <= 432
							//values: (WDATAWIDTH * (WDATADEPTH / 512)) / [1, 2, 4, 8, 16]
	.RDATADEPTH		(FIFODEPTH),
	.ENDIAN			("BIG"),		//"BIG" "LITTLE"
	.ALMOSTFULL		(FIFODEPTH - (REQUEST_ONCE_POINT / 2)),
	.ALMOSTEMPTY	(FIFODEPTH / 2)
) dbclk_fifo_anlogic_u(
	.I_rstn			(I_rstn),

	.I_wclk			(I_clk),
	.I_we			(I_out_valid),
	.I_wdata		({I_out_dqm, I_out_data}),
	.O_full			(),
	.O_afull		(W_buffer_afull),

	.I_rclk			(I_clk),
	.I_re			(W_sa_re),
	.O_rdata		(W_sa_rdata),
	.O_empty		(W_sa_empty),
	.O_aempty		(W_buffer_aempty)
);

assign W_buffer_is_afull = W_buffer_afull;

wire W_split_re;
wire [35:0] W_split_rdata;
wire W_split_empty;

fifo_showahead_enable #(
	.DATAWIDTH		(36)
) fifo_showahead_enable_u(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.O_re			(W_sa_re),
	.I_rdata		(W_sa_rdata),
	.I_empty		(W_sa_empty),

	.I_re			(W_split_re),
	.O_rdata		(W_split_rdata),
	.O_empty		(W_split_empty)
);

wire			W_dac_rvalid;
wire	[15:0]	W_dac_rdata;
wire	[0:0]	W_dac_raddr;
wire			W_dac_rlast;
wire			W_dac_rready;

width_split #(
	.WDATAWIDTH		(32),
	.RDATAWIDTH		(16),	//must be (WDATAWIDTH / n), must be divisible
	.ENDIAN			("BIG"),		//"BIG" "LITTLE"
	.PREFETCH		(1)
) width_convert_split(
	.I_clk			(I_clk),
	.I_rstn			(I_rstn),

	.I_wvalid		(!W_split_empty),
	.I_wdata		(W_split_rdata[31:0]),
	.I_wmask		({W_split_rdata[35], W_split_rdata[33]}),
	.O_wready		(W_split_re),

	.O_rvalid		(W_dac_rvalid),
	.O_rdata		(W_dac_rdata),
	.O_raddr		(W_dac_raddr),
	.O_rlast		(W_dac_rlast),
	.I_rready		(W_dac_rready)
);

reg [7:0] R_cnt_rate_div;
reg R_is_output;
wire [9:0] W_dac_data_retz = W_dac_rvalid ? W_dac_rdata[9:0] : 10'b0;
reg [10:0] R_dac_data;
reg [9:0] R_dac_data_out;

always @(posedge I_clk or negedge I_rstn)begin
	if(!I_rstn)
		R_cnt_rate_div <= 8'b0;
	else if(R_cnt_rate_div == I_update_rate_div)
		R_cnt_rate_div <= 8'b0;
	else 
		R_cnt_rate_div <= R_cnt_rate_div + 1'b1;

	if(!I_rstn)
		R_is_output <= 1'b0;
	else if((!I_is_run) && (!W_dac_rvalid))
		R_is_output <= 1'b0;
	else if(I_is_run && (!W_buffer_aempty))
		R_is_output <= 1'b1;
	else 
		R_is_output <= R_is_output;

	if(!I_rstn)
		R_dac_data <= 11'b0;
	else if(W_dac_rready)
		R_dac_data <= {W_dac_data_retz[9], W_dac_data_retz[9:0]} + {I_output_offset[9], I_output_offset[9:0]};
	else 
		R_dac_data <= R_dac_data;

	if(!I_rstn)
		R_dac_data_out <= 10'b0;
	else if(R_dac_data[10:9] == 2'b01)
		R_dac_data_out <= 10'h1ff + 10'h200;
	else if(R_dac_data[10:9] == 2'b10)
		R_dac_data_out <= 10'h200 + 10'h200;
	else 
		R_dac_data_out <= R_dac_data[9:0] + 10'h200;
end

assign W_dac_rready = W_dac_rvalid && R_is_output && (R_cnt_rate_div == I_update_rate_div);

assign O_data = R_dac_data_out;

EG_LOGIC_ODDR #(
	.ASYNCRST	("ENABLE"))
oddr_dclk(
	.q		(O_dclk),
	.clk	(I_clk),
	.d1		(1'b1),
	.d0		(1'b0),
	.rst	(!I_rstn)
);

reg [9:0] R_out_d;
reg [7:0] R_d_cnt;	//synthesis keep

always @(posedge I_clk or negedge I_rstn)begin
	if(!I_rstn)
		R_out_d <= 10'b0;
	else 
		R_out_d <= R_dac_data_out;

	if(!I_rstn)
		R_d_cnt <= 8'b0;
	else if(R_out_d == R_dac_data_out)
		R_d_cnt <= (R_d_cnt == 8'd255) ? R_d_cnt : (R_d_cnt + 1'b1);
	else 
		R_d_cnt <= 8'b0;
end


endmodule
