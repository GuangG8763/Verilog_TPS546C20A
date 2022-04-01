module TPS546C20A
(
	input			I_CLK_4M		,
	input			I_rst_n			,
	input			I_wr_pulse		,
	inout			IO_SDA			,
	output			O_fh_pulse		,
	output			O_TP1			,
	output			O_TP2			,
	output			O_SCL			
);

wire W_POS, W_HIG, W_NEG, W_LOG;
wire		W_recv_en		;
wire		W_send_en		;
wire [6:0]	W_dev_addr		;
wire [7:0]	W_cmd_addr		;
wire [1:0]	W_BYTE			;
wire [15:0]	W_read_data		;
wire		W_SCL_en	= 1'b1		;
wire [15:0]	W_write_data	;
wire		W_done_pulse	;

SCL_clock U1	// make SCL module
(
	.I_CLK_4M		(I_CLK_4M		),	// 4Mhz clock input
	.I_rst_n		(I_rst_n		),	// reset pin low action
	.I_SCL_en		(W_SCL_en		),	// SCL enable high action, low SCL keep high
	.O_SCL_POS		(W_POS			),	// SCL 上緣 pulse
	.O_SCL_HIG		(W_HIG			),	// SCL HIGH 中間 pulse
	.O_SCL_NEG		(W_NEG			),	// SCL下緣 pulse
	.O_SCL_LOW		(W_LOG			),	// SCL LOW 中間 pulse
	.O_SCL			(O_SCL			)	// SCL實際輸出
);

I2C_funtion U2
(
	.I_CLK_4M		(I_CLK_4M		),	// 4Mhz clock input
	.I_rst_n		(I_rst_n		),	// reset pin low action
	.I_recv_en		(W_recv_en		),	// recv enalbe pin 1:action
	.I_send_en		(W_send_en		),	// send enalbe pin 1:action
	.I_SCL_POS		(W_POS			),	// SCL 上升緣 pulse
	.I_SCL_HIG		(W_HIG			),	// SCL HIGH 中間 pulse
	.I_SCL_NEG		(W_NEG			),	// SCL下緣 pulse
	.I_SCL_LOW		(W_LOG			),	// SCL LOW 中間 pulse	
	.I_dev_addr		(W_dev_addr		),	// device address
	.I_cmd_addr		(W_cmd_addr		),	// command adress
	.I_write_data	(W_write_data	),	// write data
	.I_BYTE			(W_BYTE			),	// 有幾個byte要讀
	.O_SCL_en		(				),	// SCL啟動 1:action
	.O_read_data	(W_read_data	),	// 資料輸出 
	.O_done_pulse	(W_done_pulse	),	// 結束pulse 資料才可撈
	.O_TP1			(O_TP1			),	// 
	.O_TP2			(O_TP2			),	// 
	.IO_SDA			(IO_SDA			)	// SDA線控制
);

I2C_cmd U3
(
	.I_CLK_4M		(I_CLK_4M		),	// 4Mhz clock input = 250ns
	.I_rst_n		(I_rst_n		),	// reset pin low action
	.I_done_pulse	(W_done_pulse	),	// finish pulse
	.I_read_data	(W_read_data	),	// 撈取資料
	.I_wr_pulse		(I_wr_pulse		),	// top層對這層下寫入pulse
	.O_fh_pulse		(O_fh_pulse		),	// 結束cmd pulse
	.O_recv_en		(W_recv_en		),	// read module enable
	.O_send_en		(W_send_en		),  // write module enable
	.O_dev_addr		(W_dev_addr		),	// address
	.O_cmd_addr		(W_cmd_addr		),	// command
	.O_write_data	(W_write_data	),	// data
	.O_BYTE			(W_BYTE			)	// 有幾個BYTE
);
endmodule
