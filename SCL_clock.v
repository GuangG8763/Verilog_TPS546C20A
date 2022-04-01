module SCL_clock // make SCL module
(
	input			I_CLK_4M		, // 4Mhz clock input
	input			I_rst_n			, // reset pin low action
	input			I_SCL_en		, // SCL enable high action, low SCL keep high
	output			O_SCL_POS		, // SCL上緣觸發
	output			O_SCL_HIG		, // SCL HIGH 中間觸發
	output			O_SCL_NEG		, // SCL下緣觸發
	output			O_SCL_LOW		, // SCL LOW 中間觸發
	output			O_SCL			  // SCL實際輸出
);

reg	[5:0]	R_SCL_cnt			= 0		;	//產生SCL計數器 

parameter	P_200Khz			= 20	,//5us
			P_100khz			= 40	,//10us
			P_CLK_SELECT		= P_100khz,
			P_DIV_SELECT0		= (P_CLK_SELECT >> 2)  -  1, //HIGH中間 		
			P_DIV_SELECT1		= (P_CLK_SELECT >> 1)  -  1, //提早變LOW閃timing		
			P_DIV_SELECT2		= (P_DIV_SELECT0 + P_DIV_SELECT1) + 1,// LOW中間後一格(+1)
			P_DIV_SELECT3		= (P_CLK_SELECT >> 1)  +  1, //下緣後一格(+1)
			P_DIV_SELECT4		= (P_CLK_SELECT / P_CLK_SELECT); //判上緣後一格(+1)
			
assign		O_SCL_POS = (R_SCL_cnt == P_DIV_SELECT4	) ? 1'b1 : 1'b0 ;
assign		O_SCL_HIG = (R_SCL_cnt == P_DIV_SELECT0	) ? 1'b1 : 1'b0 ;
assign		O_SCL_NEG = (R_SCL_cnt == P_DIV_SELECT3	) ? 1'b1 : 1'b0 ;
assign		O_SCL_LOW = (R_SCL_cnt == P_DIV_SELECT2	) ? 1'b1 : 1'b0 ;
assign		O_SCL	  = (R_SCL_cnt <= P_DIV_SELECT1	) ? 1'b1 : 1'b0 ;

always@(posedge I_CLK_4M or negedge I_rst_n)  
begin  
	if(!I_rst_n)
		R_SCL_cnt	<= 0;
	else if(I_SCL_en)	//en pin high action
		begin
			if(R_SCL_cnt == P_CLK_SELECT - 1'b1) //計算到counter次數清0
				R_SCL_cnt <= 0;
			else
				R_SCL_cnt	<= R_SCL_cnt + 1'b1;
		end
	else
		R_SCL_cnt	<= 0;
end

endmodule 