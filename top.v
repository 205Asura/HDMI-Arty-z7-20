module top (
    input clk125,                     // 125 MHz input clock

    output tmds_tx_clk_p,             // TMDS clock p channel
    output tmds_tx_clk_n,             // TMDS clock n channel
    output [2:0] tmds_tx_data_p,      // TMDS data p channels
    output [2:0] tmds_tx_data_n       // TMDS data n channels
);

localparam TIMER = 75000000*2;      // two seconds @75MHz

wire pixel_clk;                     // 75 MHz pixel clock
wire serdes_clk;                    // 375 MHz serdes clock
wire rst;                           // active-high system reset
reg [7:0] rstcnt;
wire locked;

wire hsync, hblank, vsync, vblank, active, fsync; // video timing

wire [1:0] ctl [0:2];               // control bits for TMDS data channels
wire [9:0] tmds_data [0:2];         // encoded TMDS data

// Used to time the 2-second switch between red, green and blue pixels
integer count;
reg [1:0] sw;

// Utilize MMCM to generate 75 MHz pixel clock and 375 MHz TMDS serdes clock
mmcm_0 mmcm_0_inst (
   .clk_in1      (clk125),         // 125 MHz input clock
   .clk_out1     (pixel_clk),      // 75 MHz pixel clock output
   .clk_out2     (serdes_clk),     // 375 MHz TMDS serdes clock output
   .locked       (locked),         // locked indicator
   .reset        (1'b0)            // reset active low
);


localparam H_RESOLUTION = 1280; 
localparam V_RESOLUTION = 720;  

reg [$clog2(H_RESOLUTION)-1:0] x_coord;
reg [$clog2(V_RESOLUTION)-1:0] y_coord;


always @(posedge pixel_clk) begin
    if (rst) begin
        x_coord <= 0;
        y_coord <= 0;
    end else if (active) 
    begin 
        if (x_coord == H_RESOLUTION - 1) 
        begin
            x_coord <= 0;
            if (y_coord == V_RESOLUTION - 1) 
            begin
                y_coord <= 0; 
            end 
            else 
            begin
                y_coord <= y_coord + 1; 
            end
        end 
        else 
        begin
            x_coord <= x_coord + 1; 
        end
    end 
    else 
    begin
        
        x_coord <= 0;
        if (vblank) 
        begin 
            y_coord <= 0; 
        end
    end
end

wire [7:0] pdata_r, pdata_g, pdata_b;

// ROM image 224x224 
// (IP: image_rom, W:24, D:50176)
wire [$clog2(224*224)-1:0] img_addr;
wire [23:0]                img_data;

image_rom image_rom_inst (
  .clka(pixel_clk),
  .addra(img_addr),
  .ena(1'b1),
  .douta(img_data)
);

// ROM font chữ 8x8
// (IP: font_rom, W:8, D:1024)
wire [$clog2(128*8)-1:0] font_addr;
wire [7:0]                font_data;

font_rom font_rom_inst (
    .clka(pixel_clk),
    .ena(1'b1),
    .addra(font_addr),
    .douta(font_data)
);

// ROM text 80
// (IP: text_rom, W:8, D:80, File: text_rom.coe)
wire [$clog2(80)-1:0] text_addr;
wire [7:0]            text_data;

text_rom text_rom_inst (
    .clka(pixel_clk),
    .ena(1'b1),
    .addra(text_addr),
    .douta(text_data)
);

// --- 1d. Module Compositor ---
hdmi_compositor compositor_inst (
    .pixel_clk      (pixel_clk),
    .rst            (rst),
    .active         (active),
    .x_coord        (x_coord),
    .y_coord        (y_coord),

    .img_rom_addr   (img_addr),
    .img_rom_data   (img_data),
    
//    .text_rom_addr  (text_addr),
//    .text_rom_data  (text_data),

//    .font_rom_addr  (font_addr),
//    .font_rom_data  (font_data),

    .pdata_r        (pdata_r),
    .pdata_g        (pdata_g),
    .pdata_b        (pdata_b)
);

// Transition into system reset following MMCM locked indicator
always @(posedge pixel_clk or negedge locked)
begin
    if (~locked) begin
        rstcnt <= 0;
end else begin
        if (rstcnt != 8'hff) begin
            rstcnt <= rstcnt + 1;
        end
    end
end

assign rst = (rstcnt == 8'hff) ? 1'b0 : 1'b1;

// Video timing generator
video_timing video_timing_inst (
    .clk            (pixel_clk),
    .clken          (1'b1),
    .gen_clken      (1'b1),
    .sof_state      (1'b0),
    .hsync_out      (hsync),
    .hblank_out     (hblank),
    .vsync_out      (vsync),
    .vblank_out     (vblank),
    .active_video_out (active),
    .resetn         (~rst),
    .fsync_out      (fsync)
);

assign ctl[0] = {vsync, hsync};                      // vsync and hsync go onto TMDS channel 0
assign ctl[1] = 2'b00;
assign ctl[2] = 2'b00;

wire [7:0] pdata [0:2]; 
assign pdata[2] = pdata_r;  
assign pdata[1] = pdata_g;  
assign pdata[0] = pdata_b;  

// Encode video data onto three TMDS data channels
generate
    genvar i;

    for (i=0; i<3; i=i+1) begin
        // TMDS data encoder
        tmds_encode tmds_encode_inst (
            .pixel_clk      (pixel_clk),        // pixel clock
            .rst            (rst),              // reset
            .ctl            (ctl[i]),           // control bits
            .active         (active),           // active pixel indicator
            .pdata          (pdata[i]),         // 8-bit pixel data
            .tmds_data      (tmds_data[i])      // encoded 10-bit tmds data
        );

        // TMDS data output serdes
        tmds_oserdes tmds_oserdes_inst (
            .pixel_clk      (pixel_clk),        // pixel clock
            .serdes_clk     (serdes_clk),       // serdes clock
            .rst            (rst),              // reset
            .tmds_data      (tmds_data[i]),     // encoded 10-bit TMDS data
            .tmds_serdes_p  (tmds_tx_data_p[i]),// TMDS data p channel
            .tmds_serdes_n  (tmds_tx_data_n[i]) // TMDS data n channel
        );
    end
endgenerate

// TMDS clock output serdes
tmds_oserdes tmds_oserdes_clock (
    .pixel_clk      (pixel_clk),        // pixel clock
    .serdes_clk     (serdes_clk),       // serdes clock
    .rst            (rst),              // reset
    .tmds_data      (10'b1111100000),   // pixel clock pattern
    .tmds_serdes_p  (tmds_tx_clk_p),    // TMDS clock p channel
    .tmds_serdes_n  (tmds_tx_clk_n)     // TMDS clock n channel
);


endmodule