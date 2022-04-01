//use notepad++ open!!!!!!!!!!!
module I2C_cmd
(
	input			I_CLK_4M		,	// 4Mhz clock input = 250ns
	input			I_rst_n			,	// reset pin low action
	input			I_done_pulse	,	// finish pulse
	input	[15:0]	I_read_data		,	// 撈取資料
	input			I_wr_pulse		,	// top層對這層下寫入pulse
	output			O_fh_pulse		,	// 結束cmd pulse
	output			O_recv_en		,	// read module enable
	output			O_send_en		,   // write module enable
	output	[6:0]	O_dev_addr		,	// address
	output	[7:0]	O_cmd_addr		,	// command
	output	[15:0]	O_write_data	,	// data
	output	[1:0]	O_BYTE				// 有幾個BYTE
);

reg	[7:0]	R_state				= 0				;	// 狀態機
reg			R_recv_en			= 0				;	// read module enable
reg			R_send_en			= 0				;	// write module enable
reg [7:0]	R_cmd_addr			= 0				;	// command
reg	[1:0]	R_byte_tar			= 0				;	// 有幾個BYTE
reg [19:0]	R_delay_cnt			= 0				;	// 計算clock to 0.1s 用
reg [9:0]	R_delay_cnt2		= 0				;	// 計算0.1s以上用
reg 		R_delay_en			= 0				;	// 
reg	[15:0]	R_read_data			= 0 			;	// 撈取資料
reg	[15:0]	R_write_data		= 0 			;	// 寫入資料
reg	[6:0]	R_dev_addr			= 7'h24			;	// TPS546C20 address
reg			R_fh_pulse			= 0				;	// 結束cmd pulse

assign		O_recv_en			= R_recv_en		;
assign		O_send_en			= R_send_en		;
assign		O_dev_addr			= R_dev_addr	;
assign		O_cmd_addr			= R_cmd_addr	;
assign		O_write_data		= R_write_data	;
assign		O_BYTE				= R_byte_tar	;
assign		O_fh_pulse			= R_fh_pulse	;

parameter	P_Time_10ms			= 20'd 40_000	,
			P_Time_100ms		= 20'd400_000	;

parameter	P_READ_VOUT			= 8'h8B			,
			P_ADDR_PMBUS 		= 8'hD3			,
			P_VOUT_CMD			= 8'h21			,
			P_PMB_VISION 		= 8'h98			,
			P_DEV_ID			= 8'hAD			;

always@(*)  //判斷command的BYTE長度
begin  
	case(R_cmd_addr)   
		P_READ_VOUT:		R_byte_tar <= 2'd2;
		P_ADDR_PMBUS:		R_byte_tar <= 2'd1;
		P_VOUT_CMD:			R_byte_tar <= 2'd2;
		P_DEV_ID:			R_byte_tar <= 2'd2;
		P_PMB_VISION:		R_byte_tar <= 2'd1;
		default: 	R_byte_tar <= 2'd2;
	endcase 
end

always @(posedge I_CLK_4M or negedge I_rst_n)	//計算delay time
begin
	if(!I_rst_n)
		begin
			R_delay_cnt <= 0;
			R_delay_cnt2 <= 0;
		end
	else if(R_delay_en)	
		begin
			if(R_delay_cnt == P_Time_100ms)
				begin
					R_delay_cnt <= 0;
					R_delay_cnt2 <= R_delay_cnt2 + 1'b1; // +0.1s
				end
			else
				R_delay_cnt <= R_delay_cnt + 1'b1;
		end	
	else
		begin
			R_delay_cnt <= 0;
			R_delay_cnt2 <= 0;
		end
end

always @(posedge I_CLK_4M or negedge I_rst_n)
begin
	if(!I_rst_n)
		begin
			R_state		<= 0		;
			R_recv_en	<= 1'b0		;
			R_send_en	<= 1'b0		;
			R_delay_en	<= 1'b0		;
		end
	else
		begin
			case(R_state)
				8'd00:	
					begin
						if(I_wr_pulse)
							begin
								R_delay_en	<= 1'b1	;	//下delay等待
								R_state		<= 8'd01 ;
							end
						else
							R_fh_pulse	<= 1'b0 ;
					end			
				
				8'd01:	
					begin
						if(R_delay_cnt2 == 10'd10)	// 等1秒
							begin
								R_delay_en	<= 1'b0	; //停止計算
								R_state		<= 8'd04 ; //跳到寫入狀態
							end
						else
							R_state		<= 8'd01 ;
					end					

				8'd02:	
					begin
						R_state 		<= 8'd03		;
						R_cmd_addr 		<= P_READ_VOUT	;
						//R_write_data	<= 16'h00_80	;
						R_recv_en 		<= 1'b1			;
						R_send_en 		<= 1'b0			;
					end
					
				8'd03:
					begin
						if(I_done_pulse)	//等待回應完成
							begin
								R_state 		<= 8'd04		;
								R_recv_en 		<= 1'b0			;
								R_send_en 		<= 1'b0			;
								R_read_data		<= I_read_data	; //有效資料撈取
							end
						else 
							R_state 			<= 8'd03		;
					end

				8'd04:	
					begin
						R_state 		<= 8'd05		;
						R_cmd_addr 		<= P_VOUT_CMD	;
						//R_write_data	<= 16'h00_B4	; //寫入350mv    1 : 1.953mv
						//R_write_data	<= 16'h00_CD	; //寫入400mv
						R_write_data	<= 16'h00_E2	; //寫入441mv
						R_recv_en 		<= 1'b0			;
						R_send_en 		<= 1'b1			;
					end
					
				8'd05:
					begin
						if(I_done_pulse)	//等待回應完成
							begin
								R_state 		<= 8'd09		;
								R_recv_en 		<= 1'b0			;
								R_send_en 		<= 1'b0			;
								R_delay_en		<= 1'b1	;	//下delay等待
								//R_read_data		<= I_read_data	; //有效資料撈取
							end
						else 
							R_state 			<= 8'd05		;
					end

				8'd09:	
					begin
						if(R_delay_cnt2 == 10'd1)	// 等0.1秒
							begin
								R_delay_en	<= 1'b0	; //停止計算
								R_fh_pulse	<= 1'b1 ;
								R_state		<= 8'd00 ; //回到等待寫入pulse
							end
						else
							R_state		<= 8'd09 ;
					end	

				8'd06:	
					begin
						R_state 		<= 8'd07		;
						R_cmd_addr 		<= P_READ_VOUT	;
						//R_write_data	<= 16'h00_80	;
						R_recv_en 		<= 1'b1			;
						R_send_en 		<= 1'b0			;
					end
					
				8'd07:
					begin
						if(I_done_pulse)	//等待回應完成
							begin
								R_state 		<= 8'd08		;
								R_recv_en 		<= 1'b0			;
								R_send_en 		<= 1'b0			;
								R_read_data		<= I_read_data	; //有效資料撈取
							end
						else 
							R_state 			<= 8'd07		;
					end
					
				8'd08:	
					begin
						R_state		<= 8'd08 ;
					end					



				default: R_state <= 8'd00;
			endcase
		end
end
endmodule