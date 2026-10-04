module link_analysis #(
	parameter	MAX_PACKAGE_SIZE	= 2048,		//must be 2**n
	parameter	ADDRWIDTH			= $clog2(MAX_PACKAGE_SIZE)
) (
	input					I_clk,
	input					I_rstn,

	input					I_rvalid,
	input	[7:0]			I_rdata,

	output					O_crc_error,
	output					O_busy_error,
	output					O_pack_valid,
	output	[ADDRWIDTH-1:0]	O_pack_addr,
	output	[7:0]			O_pack_data,
	output	[ADDRWIDTH-1:0]	O_pack_max_addr,
	output	[7:0]			O_pack_id,
	input					I_pack_ready
);


reg [7:0] R_preamble[4:0];

always @(posedge I_clk or negedge I_rstn)begin
	if(!I_rstn)begin
		R_preamble[0] <= 8'b0;
		R_preamble[1] <= 8'b0;
		R_preamble[2] <= 8'b0;
		R_preamble[3] <= 8'b0;
		R_preamble[4] <= 8'b0;
	end
	else if(I_rvalid)begin
		R_preamble[0] <= I_rdata;
		R_preamble[1] <= R_preamble[0];
		R_preamble[2] <= R_preamble[1];
		R_preamble[3] <= R_preamble[2];
		R_preamble[4] <= R_preamble[3];
	end
	else begin
		R_preamble[0] <= R_preamble[0];
		R_preamble[1] <= R_preamble[1];
		R_preamble[2] <= R_preamble[2];
		R_preamble[3] <= R_preamble[3];
		R_preamble[4] <= R_preamble[4];
	end
end

reg R_is_recv;
wire W_enter_recv = (!R_is_recv) && ({R_preamble[4], R_preamble[3]} == 16'ha0a5) && 
						({R_preamble[1], R_preamble[0]} <= MAX_PACKAGE_SIZE);
reg [7:0] R_package_id;
reg [ADDRWIDTH:0] R_package_size;
reg [ADDRWIDTH:0] R_cnt_recv;
reg R_pingpong;
reg W_pingpong;

always @(posedge I_clk or negedge I_rstn)begin
	if(!I_rstn)
		R_is_recv <= 1'b0;
	else if(W_enter_recv)
		R_is_recv <= 1'b1;
	else if(R_is_recv && I_rvalid && (R_cnt_recv == (R_package_size + 1'b1)))
		R_is_recv <= 1'b0;
	else 
		R_is_recv <= R_is_recv;

	if(!I_rstn)
		R_package_id <= 8'b0;
	else if(W_enter_recv)
		R_package_id <= R_preamble[2];
	else 
		R_package_id <= R_package_id;

	if(!I_rstn)
		R_package_size <= {(ADDRWIDTH+1){1'b0}};
	else if(W_enter_recv)
		R_package_size <= {R_preamble[1], R_preamble[0]};
	else 
		R_package_size <= R_package_size;

	if(!I_rstn)
		R_cnt_recv <= {(ADDRWIDTH+1){1'b0}};
	else if(W_enter_recv)
		R_cnt_recv <= {(ADDRWIDTH+1){1'b0}};
	else if(R_is_recv && I_rvalid)
		R_cnt_recv <= R_cnt_recv + 1'b1;
	else 
		R_cnt_recv <= R_cnt_recv;
end


reg [ADDRWIDTH-1:0] W_cnt_process;

dbclk_sync_ram_anlogic #(
	.WDATAWIDTH		(8),
	.WDATADEPTH		(MAX_PACKAGE_SIZE*2),	//must be 2**n
	.RDATAWIDTH		(8)	//WDATAWIDTH * (2**n) or WDATAWIDTH / (2**n), must be divisible
) dbclk_sync_ram_anlogic_u(
	.I_wclk			(I_clk),
	.I_we			(R_is_recv && I_rvalid && (R_cnt_recv < R_package_size)),
	.I_waddr		({R_pingpong, R_cnt_recv[ADDRWIDTH-1:0]}),
	.I_wdata		(I_rdata),

	.I_rclk			(I_clk),
	.I_re			(1'b1),
	.I_raddr		({(!W_pingpong), W_cnt_process}),
	.O_rdata		(O_pack_data)
);


//crc16_ccitt_false
wire [15:0] W_crc;
reg [15:0] R_crc;

crc16_ccitt crc16_ccitt_u(
	.I_crc		(R_crc),
	.I_din		(I_rdata),
	.O_crc		(W_crc)
);

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_crc <= 16'hffff;
	else if(W_enter_recv)
		R_crc <= 16'hffff;
	else if(I_rvalid)
		R_crc <= W_crc;
	else 
		R_crc <= R_crc;
end


reg R_is_process;
reg [ADDRWIDTH-1:0] R_process_size;
reg [ADDRWIDTH-1:0] R_cnt_process;
wire W_enter_process = (!R_is_process) && R_is_recv && I_rvalid && (R_cnt_recv == (R_package_size + 1'b1)) && (W_crc == 16'b0);


reg R_crc_error;
reg R_busy_error;

always @(*)begin
	if(W_enter_process)
		W_pingpong = !R_pingpong;
	else 
		W_pingpong = R_pingpong;
end

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_pingpong <= 1'b0;
	else 
		R_pingpong <= W_pingpong;

	if(!I_rstn)
		R_crc_error <= 1'b0;
	else if(R_is_recv && I_rvalid && (R_cnt_recv == (R_package_size + 1'b1)) && (W_crc != 16'b0))
		R_crc_error <= 1'b1;
	else if(W_enter_process)
		R_crc_error <= 1'b0;
	else 
		R_crc_error <= R_crc_error;

	if(!I_rstn)
		R_busy_error <= 1'b0;
	else if(R_is_process && R_is_recv && I_rvalid && (R_cnt_recv == (R_package_size + 1'b1)))
		R_busy_error <= 1'b1;
	else if(W_enter_process)
		R_busy_error <= 1'b0;
	else 
		R_busy_error <= R_busy_error;
end

assign O_crc_error = R_crc_error;
assign O_busy_error = R_busy_error;


always @(*) begin
	if(W_enter_process)
		W_cnt_process = {ADDRWIDTH{1'b0}};
	else if(R_is_process && I_pack_ready)
		W_cnt_process = R_cnt_process + 1'b1;
	else 
		W_cnt_process = R_cnt_process;
end

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_is_process <= 1'b0;
	else if(W_enter_process)
		R_is_process <= 1'b1;
	else if((R_cnt_process == R_process_size) && I_pack_ready)
		R_is_process <= 1'b0;
	else 
		R_is_process <= R_is_process;

	if(!I_rstn)
		R_process_size <= {ADDRWIDTH{1'b0}};
	else if(W_enter_process)
		R_process_size <= (R_package_size - 1'b1);
	else 
		R_process_size <= R_process_size;

	if(!I_rstn)
		R_cnt_process <= {ADDRWIDTH{1'b0}};
	else 
		R_cnt_process <= W_cnt_process;
end

assign O_pack_valid = R_is_process;
assign O_pack_addr = R_cnt_process;
assign O_pack_max_addr = R_process_size;
assign O_pack_id = R_package_id;



endmodule
