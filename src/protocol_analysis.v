module protocol_analysis #(
	parameter MAX_PACKAGE_SIZE	= 2048	//must be 2**n
) (
	input			I_clk,
	input			I_rstn,

	output	[7:0]	O_wdata,
	// input			I_wready,
	input			I_rvalid,
	input	[7:0]	I_rdata,
	// output			O_int,

	output	[7:0]	O_output_mode,
	output	[7:0]	O_update_rate_div,
	output	[22:0]	O_sample_points,
	output	[15:0]	O_output_offset,
	output			O_is_run,
	output			O_wave_valid,
	output	[20:0]	O_wave_addr,
	output	[31:0]	O_wave_data,
	output	[3:0]	O_wave_dqm,
	input			I_wave_ready
);


localparam ADDRWIDTH = $clog2(MAX_PACKAGE_SIZE);


wire W_pack_valid;
wire [ADDRWIDTH-1:0] W_pack_addr;
wire [7:0] W_pack_data;
wire [ADDRWIDTH-1:0] W_pack_max_addr;
wire [7:0] W_pack_id;
wire W_pack_ready;
wire W_crc_error;
wire W_busy_error;

link_analysis #(
	.MAX_PACKAGE_SIZE	(MAX_PACKAGE_SIZE),
	.ADDRWIDTH			(ADDRWIDTH)
) link_analysis_u(
	.I_clk				(I_clk),
	.I_rstn				(I_rstn),

	.I_rvalid			(I_rvalid),
	.I_rdata			(I_rdata),

	.O_crc_error		(W_crc_error),
	.O_busy_error		(W_busy_error),
	.O_pack_valid		(W_pack_valid),
	.O_pack_addr		(W_pack_addr),
	.O_pack_data		(W_pack_data),
	.O_pack_max_addr	(W_pack_max_addr),
	.O_pack_id			(W_pack_id),
	.I_pack_ready		(W_pack_ready)
);


reg [7:0] R_pack_id;
reg R_pack_lost;
wire [7:0] W_status = {W_crc_error, W_busy_error, 5'b0, R_pack_lost};

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_pack_id <= 8'b0;
	else if(W_pack_valid && W_pack_ready && (W_pack_addr == {ADDRWIDTH{1'b0}}))
		R_pack_id <= W_pack_id;
	else 
		R_pack_id <= R_pack_id;

	if(!I_rstn)
		R_pack_lost <= 1'b0;
	else if(W_pack_valid && W_pack_ready && (W_pack_addr == {ADDRWIDTH{1'b0}}))
		R_pack_lost <= (W_pack_id != (R_pack_id + 1'b1));
	else 
		R_pack_lost <= R_pack_lost;
end

assign O_wdata = W_status;


app_analysis #(
	.MAX_PACKAGE_SIZE	(MAX_PACKAGE_SIZE),
	.ADDRWIDTH			(ADDRWIDTH)
) app_analysis_u(
	.I_clk				(I_clk),
	.I_rstn				(I_rstn),

	.I_pack_valid		(W_pack_valid),
	.I_pack_addr		(W_pack_addr),
	.I_pack_data		(W_pack_data),
	.I_pack_max_addr	(W_pack_max_addr),
	.O_pack_ready		(W_pack_ready),

	.O_output_mode		(O_output_mode),
	.O_update_rate_div	(O_update_rate_div),
	.O_sample_points	(O_sample_points),
	.O_output_offset	(O_output_offset),
	.O_is_run			(O_is_run),
	.O_wave_valid		(O_wave_valid),
	.O_wave_addr		(O_wave_addr),
	.O_wave_data		(O_wave_data),
	.O_wave_dqm			(O_wave_dqm),
	.I_wave_ready		(I_wave_ready)
);


endmodule
