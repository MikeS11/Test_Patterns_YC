/* Mike Simone Attempt to generate a YC source for S-Video and Composite / 
Colorspace
Y	0.299R' + 0.587G' + 0.114B'
U	0.492(B' - Y) = 504 (X 1024)
V	0.877(R' - Y) = 898 (X 1024)

YPbPr
Y =  0.299R +  0.587G + 0.114B
Pb = -0.172R - 0.339G + 0.551B + 128
Pr  =  0.511R - 0.428G - 0.083B + 128	
*/

module yc_out
(
	input   clk,		
	input 	[39:0] PHASE_INC,
	input	PAL_EN,
    input   SVIDEO_EN,
	input 	YC_EN,
	input	[4:0] CHRADD,
	input	[4:0] CHRMUL,
	input 	MULFLAG,

	input	hsync,
	input	vsync,
	input	csync,

	input	[23:0] din,
	output	[23:0] dout,

	output reg	hsync_o,
	output reg	vsync_o,
	output reg	csync_o
);
wire [4:0] chradd = CHRADD;
wire [4:0] chrmul = CHRMUL;

wire [7:0] red = din[23:16];
wire [7:0] green = din[15:8];
wire [7:0] blue = din[7:0];

typedef struct {
	logic signed [20:0] y;
	logic signed [20:0] cr;
	logic signed [20:0] cb;
	logic signed [20:0] c;
	logic signed [20:0] u;
	logic signed [20:0] v;
	logic        hsync;
	logic        vsync;
	logic        csync;
} phase_t;

localparam MAX_PHASES = 7'd8;

phase_t phase[MAX_PHASES];
reg [23:0] din1, din2;
reg [23:0] rgb; 
reg unsigned [7:0] Y, C, c, Cr, Cb, U, V;


reg [8:0]  cburst_phase;    // colorburst counter 
reg unsigned [7:0] vref = 'd128; // Voltage reference point (Used for Chroma)
reg [7:0]  chroma_LUT_COS = 8'd0; // Chroma cos LUT reference
reg [7:0]  chroma_LUT_SIN = 8'd0; // Chroma sin LUT reference 
reg [7:0]  chroma_LUT_BURST = 8'd0; // Chroma colorburst LUT reference   
reg [7:0]  chroma_LUT = 8'd0;  

/*
THe following LUT table was calculated by Sin(2*pi*t/2^8) where t: 0 - 255
*/

/*************************************
		8 bit Sine look up Table
**************************************/
wire signed [10:0] chroma_SIN_LUT[256] = '{
11'h000, 11'h006, 11'h00C, 11'h012, 11'h018, 11'h01F, 11'h025, 11'h02B, 11'h031, 11'h037, 11'h03D, 11'h044, 11'h04A, 11'h04F, 
11'h055, 11'h05B, 11'h061, 11'h067, 11'h06D, 11'h072, 11'h078, 11'h07D, 11'h083, 11'h088, 11'h08D, 11'h092, 11'h097, 11'h09C, 
11'h0A1, 11'h0A6, 11'h0AB, 11'h0AF, 11'h0B4, 11'h0B8, 11'h0BC, 11'h0C1, 11'h0C5, 11'h0C9, 11'h0CC, 11'h0D0, 11'h0D4, 11'h0D7, 
11'h0DA, 11'h0DD, 11'h0E0, 11'h0E3, 11'h0E6, 11'h0E9, 11'h0EB, 11'h0ED, 11'h0F0, 11'h0F2, 11'h0F4, 11'h0F5, 11'h0F7, 11'h0F8, 
11'h0FA, 11'h0FB, 11'h0FC, 11'h0FD, 11'h0FD, 11'h0FE, 11'h0FE, 11'h0FE, 11'h0FF, 11'h0FE, 11'h0FE, 11'h0FE, 11'h0FD, 11'h0FD, 
11'h0FC, 11'h0FB, 11'h0FA, 11'h0F8, 11'h0F7, 11'h0F5, 11'h0F4, 11'h0F2, 11'h0F0, 11'h0ED, 11'h0EB, 11'h0E9, 11'h0E6, 11'h0E3, 
11'h0E0, 11'h0DD, 11'h0DA, 11'h0D7, 11'h0D4, 11'h0D0, 11'h0CC, 11'h0C9, 11'h0C5, 11'h0C1, 11'h0BC, 11'h0B8, 11'h0B4, 11'h0AF, 
11'h0AB, 11'h0A6, 11'h0A1, 11'h09C, 11'h097, 11'h092, 11'h08D, 11'h088, 11'h083, 11'h07D, 11'h078, 11'h072, 11'h06D, 11'h067, 
11'h061, 11'h05B, 11'h055, 11'h04F, 11'h04A, 11'h044, 11'h03D, 11'h037, 11'h031, 11'h02B, 11'h025, 11'h01F, 11'h018, 11'h012, 
11'h00C, 11'h006, 11'h000, 11'h7F9, 11'h7F3, 11'h7ED, 11'h7E7, 11'h7E0, 11'h7DA, 11'h7D4, 11'h7CE, 11'h7C8, 11'h7C2, 11'h7BB, 
11'h7B5, 11'h7B0, 11'h7AA, 11'h7A4, 11'h79E, 11'h798, 11'h792, 11'h78D, 11'h787, 11'h782, 11'h77C, 11'h777, 11'h772, 11'h76D, 
11'h768, 11'h763, 11'h75E, 11'h759, 11'h754, 11'h750, 11'h74B, 11'h747, 11'h743, 11'h73E, 11'h73A, 11'h736, 11'h733, 11'h72F, 
11'h72B, 11'h728, 11'h725, 11'h722, 11'h71F, 11'h71C, 11'h719, 11'h716, 11'h714, 11'h712, 11'h70F, 11'h70D, 11'h70B, 11'h70A, 
11'h708, 11'h707, 11'h705, 11'h704, 11'h703, 11'h702, 11'h702, 11'h701, 11'h701, 11'h701, 11'h701, 11'h701, 11'h701, 11'h701, 
11'h702, 11'h702, 11'h703, 11'h704, 11'h705, 11'h707, 11'h708, 11'h70A, 11'h70B, 11'h70D, 11'h70F, 11'h712, 11'h714, 11'h716, 
11'h719, 11'h71C, 11'h71F, 11'h722, 11'h725, 11'h728, 11'h72B, 11'h72F, 11'h733, 11'h736, 11'h73A, 11'h73E, 11'h743, 11'h747, 
11'h74B, 11'h750, 11'h754, 11'h759, 11'h75E, 11'h763, 11'h768, 11'h76D, 11'h772, 11'h777, 11'h77C, 11'h782, 11'h787, 11'h78D, 
11'h792, 11'h798, 11'h79E, 11'h7A4, 11'h7AA, 11'h7B0, 11'h7B5, 11'h7BB, 11'h7C2, 11'h7C8, 11'h7CE, 11'h7D4, 11'h7DA, 11'h7E0, 
11'h7E7, 11'h7ED, 11'h7F3, 11'h7F9
};

reg [39:0] phase_accum;
reg PAL_FLIP = 1'd0;
reg	PAL_line_count = 1'd0;

/**************************************
	Generate Luma and Chroma Signals
***************************************/

always_ff @(posedge clk) begin
	if (YC_EN) begin
		
		for (logic [3:0] x = 0; x < (MAX_PHASES - 1'd1); x = x + 1'd1) begin
			phase[x + 1] <= phase[x];
		end

		// Calculate Luma signal
		phase[0].y <= {red, 8'd0} + {red, 5'd0}+ {red, 4'd0} + {red, 1'd0};
		phase[1].y <= {green, 9'd0} + {green, 6'd0} + {green, 4'd0} + {green, 3'd0} + green;
		phase[2].y <= {blue, 6'd0} + {blue, 5'd0} + {blue, 4'd0} + {blue, 2'd0} + blue;
		phase[3].y <= phase[0].y + phase[1].y + phase[2].y;
		phase[4].y <= phase[3].y;

		// Calculate chroma signal 
		
		// Generate the LUT values using the phase accumulator reference.
		if (~MULFLAG)
			phase_accum <= phase_accum + PHASE_INC + (chradd<<<chrmul);
		else
			phase_accum <= phase_accum + PHASE_INC - (chradd<<<chrmul);
		chroma_LUT <= phase_accum[39:32];
			
		// Adjust SINE carrier reference for PAL (Also adjust for PAL Switch)
		if (PAL_EN) begin
			if (PAL_FLIP)
				chroma_LUT_BURST <= chroma_LUT + 8'd160;
			else
				chroma_LUT_BURST <= chroma_LUT + 8'd96;
		end else  // Adjust SINE carrier reference for NTSC
			chroma_LUT_BURST <= chroma_LUT + 8'd128;
			
		// Prepare LUT values for sin / cos (+90 degress)
		chroma_LUT_SIN <= chroma_LUT;
		chroma_LUT_COS <= chroma_LUT + 8'd64;

		// Calculate for U, V - Bit Shift Multiple by u = by * 1024 x 0.492 = 504, v = ry * 1024 x 0.877 = 898
		phase[0].u <= $signed({2'b0 ,(blue)}) - $signed({2'b0 ,phase[4].y[17:10]});
		phase[0].v <= $signed({2'b0 ,(red)}) - $signed({2'b0 ,phase[4].y[17:10]});
		phase[1].u <= $signed({phase[0].u, 8'd0}) +  $signed({phase[0].u, 7'd0}) + $signed({phase[0].u, 6'd0})  + $signed({phase[0].u, 5'd0}) + $signed({phase[0].u, 4'd0})  + $signed({phase[0].u, 3'd0}) ; 										
		phase[1].v <= $signed({phase[0].v, 9'd0}) +  $signed({phase[0].v, 8'd0}) + $signed({phase[0].v, 7'd0})  + $signed({phase[0].v, 1'd0});
		
		phase[0].c <= vref;
		phase[1].c <= phase[0].c;
		phase[2].c <= phase[1].c;
		phase[3].c <= phase[2].c;

		if (hsync) begin // Reset colorburst counter, as well as the calculated cos / sin values.
			cburst_phase <= 'd0; 	
			phase[2].u <= 21'b0;	
			phase[2].u <= 21'b0;  
			phase[4].c <= phase[3].c;

			if (PAL_line_count) begin
				PAL_FLIP <= ~PAL_FLIP;
				PAL_line_count <= ~PAL_line_count;
			end
		end	else begin // Generate Colorburst for 9 cycles 
			if (cburst_phase >= 'd40 && cburst_phase <= 'd240) begin // Start the color burst signal at 45 samples or 0.9 us
				// COLORBURST SIGNAL GENERATION (9 CYCLES ONLY or between count 40 - 240)
				phase[2].u <= $signed({chroma_SIN_LUT[chroma_LUT_BURST],5'd0});
				phase[2].v <= 21'b0;
					
				// Division to scale down the results to fit 8 bit. 
				phase[3].u <= $signed(phase[2].u[20:8]) + $signed(phase[2].u[20:9]);
				phase[3].v <= phase[2].v;
			end	else if (cburst_phase > 'd240) begin  // MODULATE U, V for chroma 
				/* 
				U,V are both multiplied by 1024 earlier to scale for the decimals in the YUV colorspace conversion. 
				U and V are both divided by 2^12 to divide by 10 for the scaling above as well as chroma subsampling from 4:4:4 to 4:1:1 (25% or from 8 bit to 6 bit)
				*/
				phase[2].u <= $signed((phase[1].u)>>>12) * $signed(chroma_SIN_LUT[chroma_LUT_SIN]);
				phase[2].v <= $signed((phase[1].v)>>>12) * $signed(chroma_SIN_LUT[chroma_LUT_COS]);		
		
				// Divide U*sin(wt) and V*cos(wt) to fit results to 8 bit 
				phase[3].u <= $signed(phase[2].u[20:7]) + $signed(phase[2].u[20:8]) + $signed(phase[2].u[20:13]);
				phase[3].v <= $signed(phase[2].v[20:7]) + $signed(phase[2].v[20:8]) + $signed(phase[2].u[20:13]);
			end

			// Stop the colorburst timer as its only needed for the initial pulse
			if (cburst_phase <= 'd400) 
				cburst_phase <= cburst_phase + 9'd1;

				// Calculate for chroma (Note: "PAL SWITCH" routine flips V * COS(Wt) every other line)
			if (PAL_EN) begin
				if (PAL_FLIP) 
					phase[4].c <= vref + phase[3].u + phase[3].v;
				else 
					phase[4].c <= vref + phase[3].u - phase[3].v;
					PAL_line_count <= 1'd1;
			end else
					phase[4].c <= vref + phase[3].u + phase[3].v;	
			
		end
		// Adjust sync timing correctly for RGB or S-Video
		phase[1].hsync <= hsync; phase[1].vsync <= vsync; phase[1].csync <= csync;
		phase[2].hsync <= phase[1].hsync; phase[2].vsync <= phase[1].vsync; phase[2].csync <= phase[1].csync;
		phase[3].hsync <= phase[2].hsync; phase[3].vsync <= phase[2].vsync; phase[3].csync <= phase[2].csync;
		phase[4].hsync <= phase[3].hsync; phase[4].vsync <= phase[3].vsync; phase[4].csync <= phase[3].csync;
		hsync_o <= phase[4].hsync; 	vsync_o <= phase[4].vsync; csync_o <= phase[4].csync;

		// Set Chroma / YUV output
		C <= phase[4].c[7:0];
		Y <= phase[4].y[17:10];
	end
end

assign dout = {C, Y, 8'd0};

endmodule

