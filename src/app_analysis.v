module app_analysis #(
	parameter	MAX_PACKAGE_SIZE	= 2048,
	parameter	ADDRWIDTH			= $clog2(MAX_PACKAGE_SIZE)
) (
	input					I_clk,
	input					I_rstn,

	input					I_pack_valid,
	input	[ADDRWIDTH-1:0]	I_pack_addr,
	input	[7:0]			I_pack_data,
	input	[ADDRWIDTH-1:0]	I_pack_max_addr,
	output					O_pack_ready,

	output	[7:0]			O_output_mode,
	output	[7:0]			O_update_rate_div,
	output	[22:0]			O_sample_points,
	output	[15:0]			O_output_offset,
	output					O_is_run,
	output					O_wave_valid,
	output	[20:0]			O_wave_addr,
	output	[31:0]			O_wave_data,
	output	[3:0]			O_wave_dqm,
	input					I_wave_ready
);


reg [7:0]	R_cmd;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_cmd <= 8'b0;
	else if(O_pack_ready && (I_pack_addr == 0))
		R_cmd <= I_pack_data;
	else 
		R_cmd <= R_cmd;
end


reg			R_is_run;
reg	[7:0]	R_output_mode;
reg	[7:0]	R_update_rate_div;
reg	[22:0]	R_sample_points;
reg	[15:0]	R_output_offset;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_output_mode <= 8'b0;
	else if(O_pack_ready && (R_cmd == 8'h00) && (I_pack_addr == 1))
		R_output_mode <= I_pack_data;
	else 
		R_output_mode <= R_output_mode;

	if(!I_rstn)
		R_update_rate_div <= 8'b0;
	else if(O_pack_ready && (R_cmd == 8'h00) && (I_pack_addr == 2))
		R_update_rate_div <= I_pack_data;
	else 
		R_update_rate_div <= R_update_rate_div;

	if(!I_rstn)
		R_sample_points <= 23'b0;
	else if(O_pack_ready && (R_cmd == 8'h00))begin
		if(I_pack_addr == 3)
			R_sample_points[22:16] <= I_pack_data[6:0];
		else 
			R_sample_points[22:16] <= R_sample_points[22:16];

		if(I_pack_addr == 4)
			R_sample_points[15:8] <= I_pack_data;
		else 
			R_sample_points[15:8] <= R_sample_points[15:8];

		if(I_pack_addr == 5)
			R_sample_points[7:0] <= I_pack_data;
		else 
			R_sample_points[7:0] <= R_sample_points[7:0];
	end
	else 
		R_sample_points <= R_sample_points;

	if(!I_rstn)
		R_output_offset <= 16'b0;
	else if(O_pack_ready && (R_cmd == 8'h00))begin
		if(I_pack_addr == 6)
			R_output_offset[15:8] <= I_pack_data;
		else 
			R_output_offset[15:8] <= R_output_offset[15:8];

		if(I_pack_addr == 7)
			R_output_offset[7:0] <= I_pack_data;
		else 
			R_output_offset[7:0] <= R_output_offset[7:0];
	end
	else 
		R_output_offset <= R_output_offset;

	if(!I_rstn)
		R_is_run <= 1'b0;
	else if(O_pack_ready && (R_cmd == 8'h02) && (I_pack_addr == 1))
		R_is_run <= I_pack_data[0];
	else 
		R_is_run <= R_is_run;
end

assign O_output_mode = R_output_mode;
assign O_update_rate_div = R_update_rate_div;
assign O_sample_points = R_sample_points;
assign O_output_offset = R_output_offset;
assign O_is_run = R_is_run;


reg			R_wvalid;
reg	[1:0]	R_waddr;
wire W_wready;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_waddr <= 2'b0;
	else if(O_pack_ready && (R_cmd == 8'h01) && (I_pack_addr == 3))
		R_waddr <= I_pack_data[0] ? 2'b10 : 2'b00;
	else if(W_wready)
		R_waddr <= R_waddr + 1'b1;
	else 
		R_waddr <= R_waddr;

	if(!I_rstn)
		R_wvalid <= 1'b0;
	else if(O_pack_ready && (R_cmd == 8'h01) && (I_pack_addr == 3))
		R_wvalid <= 1'b1;
	else if((I_pack_addr == I_pack_max_addr) && W_wready)
		R_wvalid <= 1'b0;
	else 
		R_wvalid <= R_wvalid;
end

assign O_pack_ready = I_pack_valid && (!((R_cmd == 8'h01) && (I_pack_addr >= 4) && (!W_wready)));


width_joint #(
	.WDATAWIDTH		(8),
	.RDATAWIDTH		(32),	//must be (WDATAWIDTH * n)
	.ENDIAN			("BIG"),		//"BIG" "LITTLE"
	.ADDRORDER		("INCREASE")	//"INCREASE" "DECREASE"
) width_convert_joint(
	.I_clk				(I_clk),
	.I_rstn				(I_rstn),

	.I_wvalid			(R_wvalid),
	.I_wdata			(I_pack_data),
	.I_waddr			(R_waddr),
	.I_wlast			(I_pack_addr == I_pack_max_addr),
	.O_wready			(W_wready),

	.O_rvalid			(O_wave_valid),
	.O_rdata			(O_wave_data),
	.O_rmask			(O_wave_dqm),
	.I_rready			(I_wave_ready)
);

reg [20:0]	R_wave_addr;

always @(posedge I_clk or negedge I_rstn) begin
	if(!I_rstn)
		R_wave_addr <= 21'b0;
	else if(O_pack_ready && (R_cmd == 8'h01) && (I_pack_addr < 4))begin
		if(I_pack_addr == 1)
			R_wave_addr[20:15] <= I_pack_data[5:0];
		else 
			R_wave_addr[20:15] <= R_wave_addr[20:15];

		if(I_pack_addr == 2)
			R_wave_addr[14:7] <= I_pack_data;
		else 
			R_wave_addr[14:7] <= R_wave_addr[14:7];

		if(I_pack_addr == 3)
			R_wave_addr[6:0] <= I_pack_data[7:1];
		else 
			R_wave_addr[6:0] <= R_wave_addr[6:0];
	end
	else if(O_wave_valid && I_wave_ready)
		R_wave_addr <= R_wave_addr + 1'b1;
	else 
		R_wave_addr <= R_wave_addr;
end

assign O_wave_addr = R_wave_addr;




endmodule
