// ********************************************************************
// >>>>>>>>>>>>>>>>>>>>>>>>>>>>> NOTICE <<<<<<<<<<<<<<<<<<<<<<<<<<<<
// ********************************************************************
// File name    : Top_module.v
// Module name  : Top_module
// Author       : 
// Description  : Top_module
// 
// --------------------------------------------------------------------
// Code Revision History : 
// --------------------------------------------------------------------
// Version: |Mod. Date:   |Changes Made:
// V1.0     |2022/03/19   |Initial ver
// --------------------------------------------------------------------
// Module Function: 
module Top_module
(
	input		I_clk	,	//	12Mhz = 83.333ns
	input		I_rst_n	,	//	rest active low

	inout		IO_SDA		,
	output		O_SCL		,
	output		O_CNTL		,	// DC_module ON_OFF控制腳 1:on 0:off


	output		O_LED1	,	//	led1 output
	output		O_LED2		//	led2 output
);


parameter 
	TIME_500ms = 50_000_000 - 1,	// 500ms
	TIME_100ms = 10_000_000 - 1;	// 100ms

reg			R_clk_div = 0;
reg [31:0]	R_cnt = 0;
reg	[3:0]	R_state		= 0		;	// 狀態機
reg			R_wr_pulse	= 0		;
reg [31:0]	R_time_cnt	= 0		; 	//時間計數

wire		W_CLK_100M, W_CLK_4M, W_fh_pulse;
//wire		W_SDA, W_SCL;

assign O_LED1 = R_clk_div;
assign O_LED2 = ~R_clk_div;
assign O_CNTL = 1'b1;

CLK_PLL CLK_PLL_1
(
	.inclk0	(I_clk			),	// 12Mhz = 83.333ns
	.c0		(W_CLK_100M		),	// output 100Hz:10ns
	.c1		(W_CLK_4M		)	// output 4Hz:250ns
);

TPS546C20A TPS546C20A
(
	.I_CLK_4M		(W_CLK_4M		),
	.I_rst_n		(I_rst_n		),
	.I_wr_pulse		(R_wr_pulse		),
	.IO_SDA			(IO_SDA			),
	.O_fh_pulse		(W_fh_pulse		),
	.O_TP1			(			),
	.O_TP2			(			),
	.O_SCL			(O_SCL			)
);




always@(posedge W_CLK_100M or negedge I_rst_n)
begin
    if(!I_rst_n) 
	begin
		R_cnt <= 0;
		R_clk_div <= 0;
	end
	else 
	begin
		if( R_cnt == TIME_500ms )
		begin
			R_clk_div = ~R_clk_div;
			R_cnt <= 0;
		end
		else
			R_cnt <= R_cnt + 1'b1;
	end
end



always @(posedge W_CLK_4M)	//
begin
	case(R_state)
	
		4'd0:
			begin
				if(R_time_cnt == TIME_500ms)	// delay 200ms
					begin
						R_state		<= 4'd1;
						R_time_cnt	<= 0;
					end
				else
					R_time_cnt	<= R_time_cnt + 1'b1;	 //cnt計時	
				
			end

		4'd1:
			begin
				R_wr_pulse	<= 1'b1;	//Trigger 寫入
				R_state		<= 4'd2;
			end
			
		4'd2:
			begin
				if(W_fh_pulse)	// 等寫入完畢pulse
					R_state		<= 4'd3;
				else
					R_wr_pulse	<= 1'b0;	//關閉開始入pulse				
			end
			
		4'd3:
			begin
				R_state		<= 4'd3;
			end		
			
		default: ;
	endcase
end

endmodule

