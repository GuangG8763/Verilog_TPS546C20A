//use notepad++ open!!!!!!!!!!!
module I2C_funtion
(
	input			I_CLK_4M		,	// 4Mhz clock input = 250ns
	input			I_rst_n			,	// reset pin low action
	input			I_recv_en		,	// recv enalbe pin 1:action
	input			I_send_en		,	// send enalbe pin 1:action
	input			I_SCL_POS		,	// SCL 上升緣 pulse
	input			I_SCL_HIG		,	// SCL HIGH 中間 pulse
	input			I_SCL_NEG		,	// SCL下緣 pulse
	input			I_SCL_LOW		,	// SCL LOW 中間 pulse
	input	[6:0]	I_dev_addr		,	// device address
	input	[7:0]	I_cmd_addr		,	// command adress
	input 	[15:0]	I_write_data	,	// 寫入資料
	input	[1:0]	I_BYTE			,	// 有幾個byte要讀
	output			O_SCL_en		,	// SCL啟動 1:action
	output	[15:0]	O_read_data		,	// 資料輸出 
	output			O_done_pulse	,	// 結束pulse 資料才可撈
	output			O_TP1			,	// 
	output			O_TP2			,	// 
	inout			IO_SDA				// SDA線控制
);

//============ 狀態機定義 ============
parameter	P_INIT				= 8'h00,		
			P_LOAD1				= 8'h01,		
			P_START				= 8'h02,		
			P_ADDRESS			= 8'h03,		
			P_ACK				= 8'h04,		
			P_ACK_JUDG			= 8'h05,	
			P_R_PEC				= 8'h06,	
			P_COMMAND			= 8'h07,	
			P_ACK2				= 8'h08,
			P_ACK_JUDG2			= 8'h09,
			P_PEC_JUDG			= 8'h0A,	
			P_reSTART			= 8'h0B,	
			P_reADDRESS			= 8'h0C,
			P_ACK3				= 8'h0D,
			P_ACK_JUDG3			= 8'h0E,
			P_READ				= 8'h0F,
			P_WRITE				= 8'h10,
			P_WAIT				= 8'h11,
			P_STOP				= 8'h12,
			P_DONE_PULSE		= 8'h13,
			P_BYTE_JUDG			= 8'h14,
			P_PEC_JUDG_ACK		= 8'h15,
			P_ACK5				= 8'h16,
			P_ACK4				= 8'h17,
			P_ACK_JUDG4			= 8'h18,
			P_ACK_JUDG5 		= 8'h19,
			//P_BYTE_JUDG2		= 8'h1A,
			P_ACK_JUDG6 		= 8'h1B,
			P_READY_STOP		= 8'h1C,
			P_W_PEC				= 8'h1D,
			P_ACK6				= 8'h1E,
			P_ACK_JUDG7			= 8'h1F,
			P_SYS_STOP 			= 8'hFF;	// 最後一個結尾要;不能,

reg	[7:0]	R_state				= 0		;	// 狀態機
reg 		R_sda_mode			= 0		;	// 設置SDA模式，1:輸出，0:Z
reg 		R_sda				= 1'b1	;	// SDA線暫存狀態，兼ACK狀態暫存
reg	[3:0]	R_bit_cnt			= 0		;	// 計算發送bit的counter
reg 		R_done_pulse		= 0		;	// finish pulse reg
reg	[15:0]	R_read_data			= 0		;	// 讀取的data
reg			R_scl_en        	= 0		;	// SCL enable reg 1:action
reg	[7:0]	R_PEC_data			= 0		;	// PEC byte
reg	[1:0]	R_byte_now			= 0		;	//
reg	[7:0]	R_W_PEC				= 8'h4E	;	// write PEC byte
reg 		R_TP1, R_TP2		= 0		;	// 


assign 		IO_SDA				= (R_sda_mode == 1'b1) ? R_sda : 1'bz ;
assign 		O_SCL_en			= R_scl_en			;
assign 		O_done_pulse		= R_done_pulse		;
assign 		O_read_data			= R_read_data		;
assign 		O_TP1				= R_TP1				;
assign 		O_TP2				= R_TP2				;

always @(posedge I_CLK_4M or negedge I_rst_n)
begin
    if(!I_rst_n)
        begin
			R_state				<= P_INIT ;
			R_sda_mode			<= 1'b0 ;
			R_sda				<= 1'b1 ;
			R_bit_cnt			<= 4'd0 ;
			R_done_pulse		<= 1'b0 ;
			R_read_data			<= 0 ;
			R_scl_en			<= 1'b0 ;
        end
    else if(I_recv_en || I_send_en)	//I2C enable
        begin
			case(R_state)
				P_INIT:
					begin
						R_state	<= P_LOAD1 ;
					end
					
				P_LOAD1:
					begin
						if(I_SCL_LOW)	//起始再SCL LOW 中間準備 
							begin
								R_state			<= P_START ;
								//R_scl_en		<= 1'b1 ; // 啟動SCL
								R_sda_mode		<= 1'b1 ; // 啟動SDA控制
								R_sda			<= 1'b1 ; // 確保起始HIG > LOW
							end
					end	
					
				P_START:	//送出起始
					begin
                      if(I_SCL_HIG)	//SCL HIGH 中間 
                          begin
                              R_sda		<=  1'b0 ; // 下降緣start
                              R_state	<=  P_ADDRESS ; // 
                          end
                      else
                            R_state <= P_START ;    
					end							
				
				P_ADDRESS:
					begin
						if(I_SCL_LOW)	//SCL LOW 中間 
							begin
								if(R_bit_cnt == 4'd8)
									begin
										R_state		<= P_ACK;
										R_bit_cnt 	<= 0;
										R_sda_mode	<= 1'b0 ; // 放開SDA控制
									end
								else
									begin
										case(R_bit_cnt)
											4'd0:	R_sda <= I_dev_addr[6];
											4'd1:	R_sda <= I_dev_addr[5];
											4'd2:	R_sda <= I_dev_addr[4];
											4'd3:	R_sda <= I_dev_addr[3];
											4'd4:	R_sda <= I_dev_addr[2];
											4'd5:	R_sda <= I_dev_addr[1];
											4'd6:	R_sda <= I_dev_addr[0];
											4'd7:	R_sda <= 1'b0;
											default: ; //R:1 W:0
										endcase
										//R_sda <= I_dev_addr[7-R_bit_cnt];
										R_bit_cnt <= R_bit_cnt + 1'b1;
									end
							end
						else
							R_state	<= P_ADDRESS;
					end
				
				P_ACK:	//接收slave ACK
					begin
						if(I_SCL_HIG)
							begin
								R_state		<= P_ACK_JUDG;
								R_sda		<= IO_SDA;
							end
						else
							R_state	<= P_ACK;
					end
					
				P_ACK_JUDG:	//判斷接收slave的ACK 0:yes
					begin
						if(!R_sda && I_SCL_NEG)		// sda:0和SCL下緣再離開這回圈
							R_state	<= P_COMMAND ; 
						else if(R_sda)					// slave無回應準備進入STOP回圈
							R_state	<= P_READY_STOP ;
						else
							R_state	<= P_ACK_JUDG ;				
					end

				P_COMMAND:	//傳送command address
					begin
						if(I_SCL_LOW)
							begin
								//R_sda_mode <= 1'b1 ; // 開啟SDA控制
								if(R_bit_cnt == 4'd8)
									begin
										R_state		<= P_ACK2;
										R_bit_cnt 	<= 0;
										R_sda_mode	<= 1'b0 ; // 放開SDA控制
									end
								else
									begin
										R_sda <= I_cmd_addr[7-R_bit_cnt];
										R_bit_cnt <= R_bit_cnt + 1'b1;
										R_sda_mode <= 1'b1 ; // 開啟SDA控制
									end
							end
						else
							R_state	<= P_COMMAND;
					end
					
				P_ACK2:	//接收slave ACK
					begin
						if(I_SCL_HIG)
							begin
								if(I_recv_en)
									R_state		<= P_ACK_JUDG2;	//讀取路線
								else
									R_state		<= P_ACK_JUDG5; //寫入路線
								R_sda		<= IO_SDA;
							end
						else
							R_state	<= P_ACK2;
					end
					
//讀取路線
//P_ACK_JUDG2 > P_reSTART > P_reADDRESS > P_ACK3 > P_ACK_JUDG3 > P_READ > P_ACK4 > 下一行
//P_BYTE_JUDG > P_R_PEC > P_PEC_JUDG > P_PEC_JUDG_ACK > P_STOP > P_DONE_PULSE
				
				P_ACK_JUDG2:	//判斷接收slave的ACK 0:yes
					begin
						if(!R_sda && I_SCL_LOW)		// sda:0和SCL下緣再離開這回圈
							begin
								R_sda_mode	<= 1'b1 ; // 開啟SDA控制
								R_sda		<= 1'b1 ; // 準備restart
								R_state		<= P_reSTART ; 
							end
						else if(R_sda)					// slave無回應準備進入STOP回圈
							R_state	<= P_READY_STOP ;
						else
							R_state	<= P_ACK_JUDG2 ;				
					end

				P_reSTART:
					begin
						if(I_SCL_HIG)
							begin
								R_sda		<= 1'b0 ; // 下降緣start
								R_state		<= P_reADDRESS ; // 
							end
						else
							R_state <= P_reSTART ;   
					end	
				
				P_reADDRESS:
					begin
						if(I_SCL_LOW)
							begin
								if(R_bit_cnt == 4'd8)
									begin
										R_state		<= P_ACK3;
										R_bit_cnt 	<= 0;
										R_sda_mode	<= 1'b0 ; // 放開SDA控制
									end
								else
									begin
										case(R_bit_cnt)
											4'd0:	R_sda <= I_dev_addr[6];
											4'd1:	R_sda <= I_dev_addr[5];
											4'd2:	R_sda <= I_dev_addr[4];
											4'd3:	R_sda <= I_dev_addr[3];
											4'd4:	R_sda <= I_dev_addr[2];
											4'd5:	R_sda <= I_dev_addr[1];
											4'd6:	R_sda <= I_dev_addr[0];
											4'd7:	R_sda <= 1'b1;
											default: ; //R:1 W:0
										endcase
										R_bit_cnt <= R_bit_cnt + 1'b1;
									end
							end
						else
							R_state	<= P_reADDRESS;
					end
					
				P_ACK3:
					begin
						if(I_SCL_HIG)
							begin
								R_state		<= P_ACK_JUDG3;
								R_sda		<= IO_SDA;
							end
						else
							R_state	<= P_ACK3;
					end

				P_ACK_JUDG3:
					begin
						if(!R_sda && I_SCL_LOW)		// sda:0和SCL下緣再離開這回圈
							begin
								R_sda_mode	<= 1'b0 ; // 放開SDA控制
								R_state		<= P_READ ; 
							end
						else if(R_sda)					// slave無回應準備進入STOP回圈
							R_state	<= P_READY_STOP ;
						else
							R_state	<= P_ACK_JUDG3 ;				
					end

				P_READ:
					begin
						if(I_SCL_HIG)
							begin
								R_read_data	<= {R_read_data[14:0],IO_SDA};
								if(R_bit_cnt == 4'd7)
									begin
										R_state		<= P_ACK4 ;
										R_bit_cnt	<= 0;	
										R_byte_now	<= R_byte_now + 1'b1;
									end
								else
									R_bit_cnt	<= R_bit_cnt + 1'b1;
							end
						else
							R_state	<= P_READ;
					end		
					
				P_ACK4:		//master 回應 slave ACK
					begin
						if(I_SCL_LOW)
							begin
								R_state		<= P_BYTE_JUDG;
								R_sda_mode	<= 1'b1 ; // 啟動SDA控制
								R_sda		<= 1'b0 ; // 0:回應
							end
						else
							R_state	<= P_ACK4;
					end

				P_BYTE_JUDG: //判斷現在接收BYTE長度
					begin
						if(I_SCL_LOW)
							begin
								if(R_byte_now == I_BYTE) //累積BYTE長度等於指定長度就跳出
									begin
										R_state		<= P_R_PEC ;
										R_byte_now	<= 0 ;
										R_sda_mode	<= 1'b0 ; // 放開SDA控制，到讀PEC
										//R_sda		<= 1'b0 ; // 0:回應
										if(I_BYTE == 2'd2)
											R_read_data <= {R_read_data[7:0],R_read_data[15:8]}; //高低位元反過來
										else
											R_read_data <= R_read_data;
									end
								else //未達指定BYTE長度
									begin
										R_state		<= P_READ ;	//返回讀取狀態
										R_sda_mode	<= 1'b0 ; // 放開SDA控制
									end
							end
						else
							R_state	<= P_BYTE_JUDG;
					end		
				
				P_R_PEC:
					begin
						if(I_SCL_HIG)
							begin
								R_PEC_data	<= {R_PEC_data[6:0],IO_SDA};
								if(R_bit_cnt == 4'd7)
									begin
										R_state		<= P_PEC_JUDG ;
										R_bit_cnt	<= 0;	
									end
								else
									R_bit_cnt	<= R_bit_cnt + 1'b1;
							end
						else
							R_state	<= P_R_PEC;
					end
					
				P_PEC_JUDG:		//PEC檢查碼，並回應ACK(現在不理)
					begin
						if(I_SCL_LOW)
							begin
								R_state		<= P_PEC_JUDG_ACK;
								R_sda_mode	<= 1'b1 ; // 啟動SDA控制
								R_sda		<= 1'b0 ; // 0:回應
							end
						else
							R_state	<= P_PEC_JUDG;
					end
					
				P_PEC_JUDG_ACK:	//回應PEC ACK後準備結束
					begin
						if(I_SCL_LOW)
							begin
								R_state		<= P_STOP;
								R_sda_mode	<= 1'b1 ; // 啟動SDA控制
								R_sda		<= 1'b0 ; // 0:回應
							end
						else
							R_state	<= P_PEC_JUDG_ACK;
					end
				
				P_READY_STOP:
					begin
						if(I_SCL_LOW)
							begin
								R_state		<= P_STOP;
								R_sda_mode	<= 1'b1 ; // 開啟SDA控制
								R_sda		<= 1'b0 ; // 準備STOP
							end
					end				
				
				P_STOP:
					begin
						if(I_SCL_HIG)
							begin
								R_state		<= P_DONE_PULSE ;
								R_sda		<= 1'b1 ;
							end
						else
							R_state		<= P_STOP ;
					end
				
				P_DONE_PULSE:
					begin
						//if(I_SCL_LOW)
						//	begin
						R_state			<= P_INIT		;
						R_sda_mode		<= 1'b1 		; // 開啟SDA控制
						R_sda			<= 1'b1 		;
						R_done_pulse	<= 1'b1 		; // 通知結束撈DATA
						//	end
					end				

//寫入路線
//P_ACK_JUDG5 > P_WRITE > P_ACK5 > P_ACK_JUDG6 > P_BYTE_JUDG2 > P_STOP > P_DONE_PULSE > 下一行

				P_ACK_JUDG5: //現在SCL狀態:HIGH
					begin
						if(!R_sda)	// slave有回應LOW，
							begin
								R_sda_mode	<= 1'b1 ; // 開啟SDA控制
								R_sda		<= 1'b0 ; // 確保SDA要維持不變:LOW
								R_state		<= P_WRITE ;
							end
						else
							R_state	<= P_STOP;	//slave無回應跳回
					end
					
				P_WRITE:
					begin
						if(I_SCL_LOW)
							begin
								if(R_bit_cnt == 4'd8)
									begin
										R_state		<= P_ACK5;
										R_bit_cnt 	<= 0;
										R_sda_mode	<= 1'b0 ; // 放開SDA控制
										R_byte_now	<= R_byte_now + 1'b1;
									end
								else
									begin
										if(R_byte_now == 2'd1) // 高位元
											R_sda <= I_write_data[15-R_bit_cnt];
										else //低位元先傳(R_byte_now == 2'd0)
											R_sda <= I_write_data[7-R_bit_cnt];
										R_bit_cnt <= R_bit_cnt + 1'b1;
									end
							end
						else
							R_state	<= P_WRITE ;
					end		

				P_ACK5:	//接收slave ACK
					begin
						if(I_SCL_HIG)
							begin
								R_state		<= P_ACK_JUDG6 ;
								R_sda		<= IO_SDA ;
							end
						else
							R_state	<= P_ACK5 ;
					end

				P_ACK_JUDG6: //判斷接收slave的ACK 0:yes
					begin
						if(!R_sda && I_SCL_NEG)		// sda:0和SCL下緣再離開這回圈
							begin
								if(R_byte_now == I_BYTE) //累積BYTE長度等於指定長度就跳出
									begin
										R_state		<= P_READY_STOP ;
										R_byte_now	<= 0 ;
									end
								else //write未達指定BYTE長度
									begin
										R_state		<= P_WRITE ;	// 返回寫入狀態
										R_sda_mode	<= 1'b1 ; 		// 開啟SDA控制
									end
							end	
							//R_state	<= P_BYTE_JUDG2 ; 
						else if(R_sda)					// slave無回應準備進入STOP回圈
							begin
								R_state	<= P_READY_STOP ;
								R_byte_now	<= 2'd0; //因BYTE判增加往上移所以這裡也要放清零
							end
						else
							R_state	<= P_ACK_JUDG6 ;				
					end

				//P_W_PEC:
				//	begin
				//		if(I_SCL_LOW)
				//			begin
				//				if(R_bit_cnt == 4'd8)
				//					begin
				//						R_state		<= P_ACK6;
				//						R_bit_cnt 	<= 0;
				//						R_sda_mode	<= 1'b0 ; // 放開SDA控制
				//					end
				//				else
				//					begin
				//						R_sda 		<= R_W_PEC[7-R_bit_cnt];
				//						R_bit_cnt 	<= R_bit_cnt + 1'b1;
				//						
				//					end
				//			end
				//		else
				//			R_state	<= P_W_PEC ;
				//	end	
				//	
				//P_ACK6:	//接收slave ACK
				//	begin
				//		if(I_SCL_HIG)
				//			begin
				//				R_state		<= P_ACK_JUDG7 ;
				//				R_sda		<= IO_SDA ;
				//			end
				//		else
				//			R_state	<= P_ACK6 ;
				//	end
				//
				//P_ACK_JUDG7: //判斷接收slave的ACK 0:yes
				//	begin
				//		if(!R_sda && I_SCL_NEG)		// sda:0和SCL下緣再離開這回圈
				//			R_state	<= P_READY_STOP ; 
				//		else if(R_sda)					// slave無回應準備進入STOP回圈
				//			R_state	<= P_READY_STOP ;
				//		else
				//			R_state	<= P_ACK_JUDG7 ;				
				//	end

				default: R_state <= P_INIT;
			endcase
		end
	else
		begin
			R_state			<= P_INIT;
			R_sda_mode		<= 1'b0 ;
			R_sda			<= 1'b1 ;
			R_bit_cnt		<= 4'd0 ;
			R_done_pulse	<= 1'b0 ;
		end
end

endmodule