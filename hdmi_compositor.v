// Displaying Image 224x224
module hdmi_compositor (
    input wire       pixel_clk,
    input wire       rst,
    input wire       active,
    input wire [10:0] x_coord,
    input wire [9:0]  y_coord,
    output reg  [$clog2(224*224)-1:0] img_rom_addr,
    input wire  [23:0]                img_rom_data,
    output reg [7:0] pdata_r,
    output reg [7:0] pdata_g,
    output reg [7:0] pdata_b
);

localparam IMG_WIDTH  = 224;
localparam IMG_HEIGHT = 224;
localparam IMG_X_START = 528;
localparam IMG_Y_START = 248;
localparam COLOR_BLACK = 24'h000000;

wire [10:0] x_prefetch = x_coord + 2;

wire in_image_area = (x_coord >= IMG_X_START) && (x_coord < IMG_X_START + IMG_WIDTH) &&
                     (y_coord >= IMG_Y_START) && (y_coord < IMG_Y_START + IMG_HEIGHT);

wire in_prefetch_area = (x_prefetch >= IMG_X_START) && (x_prefetch < IMG_X_START + IMG_WIDTH) &&
                        (y_coord >= IMG_Y_START) && (y_coord < IMG_Y_START + IMG_HEIGHT);

wire [7:0] img_x_prefetch = x_prefetch - IMG_X_START;
wire [7:0] img_y_prefetch = y_coord - IMG_Y_START;

reg [23:0] img_data_delayed;
reg        in_image_delayed;

always @(posedge pixel_clk) begin
    if (rst) begin
        pdata_r <= 0;
        pdata_g <= 0;
        pdata_b <= 0;
        img_rom_addr <= 0;
        img_data_delayed <= 0;
        in_image_delayed <= 0;
    end else if (~active) begin
        pdata_r <= 0;
        pdata_g <= 0;
        pdata_b <= 0;
        img_rom_addr <= 0;
    end else begin
        if (in_prefetch_area) begin
            img_rom_addr <= img_y_prefetch * IMG_WIDTH + img_x_prefetch;
        end else begin
            img_rom_addr <= 0;
        end

        img_data_delayed <= img_rom_data;
        in_image_delayed <= in_image_area;

        if (in_image_delayed) begin
            pdata_r <= img_data_delayed[23:16];
            pdata_g <= img_data_delayed[15:8];
            pdata_b <= img_data_delayed[7:0];
        end else begin
            pdata_r <= 0;
            pdata_g <= 0;
            pdata_b <= 0;
        end
    end
end

endmodule

// Displaying Text 8x8 Font
//module hdmi_compositor (
//    input wire       pixel_clk,
//    input wire       rst,
//    input wire       active,
//    input wire [10:0] x_coord,
//    input wire [9:0]  y_coord,
//    output reg  [$clog2(80)-1:0] text_rom_addr,
//    input wire  [7:0] text_rom_data,
//    output reg  [$clog2(128*8)-1:0] font_rom_addr,
//    input wire  [7:0] font_rom_data,
//    output reg [7:0] pdata_r,
//    output reg [7:0] pdata_g,
//    output reg [7:0] pdata_b
//);

//localparam TEXT_LENGTH = 12;
//localparam FONT_WIDTH = 8;
//localparam FONT_HEIGHT = 8;
//localparam SCALE_FACTOR = 4;
//localparam SCALED_WIDTH = FONT_WIDTH * SCALE_FACTOR;
//localparam SCALED_HEIGHT = FONT_HEIGHT * SCALE_FACTOR;
//localparam TEXT_X_START = 448;
//localparam TEXT_Y_START = 344;

//reg [7:0] fixed_text [0:11];
//initial begin
//    fixed_text[0] = 8'h48; // H
//    fixed_text[1] = 8'h45; // E  
//    fixed_text[2] = 8'h4C; // L
//    fixed_text[3] = 8'h4C; // L
//    fixed_text[4] = 8'h4F; // O
//    fixed_text[5] = 8'h20; // Space
//    fixed_text[6] = 8'h57; // W
//    fixed_text[7] = 8'h4F; // O
//    fixed_text[8] = 8'h52; // R
//    fixed_text[9] = 8'h4C; // L
//    fixed_text[10] = 8'h44; // D
//    fixed_text[11] = 8'h21; // !
//end

//reg [6:0] text_col;
//reg [2:0] text_x_sub;
//reg [2:0] text_y_sub;
//reg [7:0] current_char;

//always @(posedge pixel_clk) begin
//    if (rst) begin
//        pdata_r <= 0;
//        pdata_g <= 0;
//        pdata_b <= 0;
//        text_col <= 0;
//        text_x_sub <= 0;
//        text_y_sub <= 0;
//        current_char <= 0;
//        font_rom_addr <= 0;
//    end else if (active) begin
//        if ((x_coord >= TEXT_X_START) && (x_coord < TEXT_X_START + TEXT_LENGTH * SCALED_WIDTH) &&
//            (y_coord >= TEXT_Y_START) && (y_coord < TEXT_Y_START + SCALED_HEIGHT)) begin
            
//            text_col = (x_coord - TEXT_X_START) / SCALED_WIDTH;
//            text_x_sub = ((x_coord - TEXT_X_START) % SCALED_WIDTH) / SCALE_FACTOR;
//            text_y_sub = ((y_coord - TEXT_Y_START) % SCALED_HEIGHT) / SCALE_FACTOR;
            
//            current_char <= fixed_text[text_col];
//            font_rom_addr <= (fixed_text[text_col] * FONT_HEIGHT) + text_y_sub;
            
//            if (font_rom_data[7 - text_x_sub]) begin
//                pdata_r <= 8'hFF;
//                pdata_g <= 8'hFF;
//                pdata_b <= 8'hFF;
//            end else begin
//                pdata_r <= 8'h00;
//                pdata_g <= 8'h40;
//                pdata_b <= 8'h80; 
//            end
//        end else begin
//            pdata_r <= 8'h00;
//            pdata_g <= 8'h00;
//            pdata_b <= 8'h00;
//        end
//    end else begin
//        pdata_r <= 0;
//        pdata_g <= 0;
//        pdata_b <= 0;
//    end
//end


//always @(*) begin
//    text_rom_addr = 0;
//end

//endmodule

// Displaying Text 8x8 Font from ROM
//module hdmi_compositor (
//    input wire       pixel_clk,
//    input wire       rst,
    
//    input wire       active,
//    input wire [10:0] x_coord,
//    input wire [9:0]  y_coord,

//    output reg  [$clog2(80)-1:0]      text_rom_addr,
//    input wire  [7:0]                text_rom_data, 
//    output reg  [$clog2(128*8)-1:0]   font_rom_addr,
//    input wire  [7:0]                font_rom_data,

//    output reg [7:0] pdata_r,
//    output reg [7:0] pdata_g,
//    output reg [7:0] pdata_b
//);

//localparam FONT_WIDTH  = 8;
//localparam FONT_HEIGHT = 8;
//localparam SCALE_FACTOR = 4;
//localparam SCALED_WIDTH = FONT_WIDTH * SCALE_FACTOR;
//localparam SCALED_HEIGHT = FONT_HEIGHT * SCALE_FACTOR;
//localparam TEXT_X_START = 448;
//localparam TEXT_Y_START = 344;
//localparam TEXT_LENGTH = 12;

//localparam COLOR_BLACK = 24'h000000;
//localparam COLOR_WHITE = 24'hFFFFFF;

//wire [10:0] x_coord_plus3 = x_coord + 3;
//wire [9:0]  y_coord_plus3 = y_coord;

//wire [6:0] text_col_plus3 = (x_coord_plus3 >= TEXT_X_START && 
//                            x_coord_plus3 < TEXT_X_START + TEXT_LENGTH * SCALED_WIDTH) ?
//                           ((x_coord_plus3 - TEXT_X_START) / SCALED_WIDTH) : 0;

//wire [2:0] text_y_sub_plus3 = (y_coord_plus3 >= TEXT_Y_START && 
//                              y_coord_plus3 < TEXT_Y_START + SCALED_HEIGHT) ?
//                             (((y_coord_plus3 - TEXT_Y_START) % SCALED_HEIGHT) / SCALE_FACTOR) : 0;

//wire [6:0] text_col = (x_coord >= TEXT_X_START && 
//                      x_coord < TEXT_X_START + TEXT_LENGTH * SCALED_WIDTH) ?
//                     ((x_coord - TEXT_X_START) / SCALED_WIDTH) : 0;

//wire [2:0] text_x_sub = (x_coord >= TEXT_X_START && 
//                        x_coord < TEXT_X_START + TEXT_LENGTH * SCALED_WIDTH) ?
//                       (((x_coord - TEXT_X_START) % SCALED_WIDTH) / SCALE_FACTOR) : 0;

//wire [2:0] text_y_sub = (y_coord >= TEXT_Y_START && 
//                        y_coord < TEXT_Y_START + SCALED_HEIGHT) ?
//                       (((y_coord - TEXT_Y_START) % SCALED_HEIGHT) / SCALE_FACTOR) : 0;

//wire is_text_area = (active) && 
//                   (y_coord >= TEXT_Y_START) && (y_coord < TEXT_Y_START + SCALED_HEIGHT) &&
//                   (x_coord >= TEXT_X_START) && (x_coord < TEXT_X_START + TEXT_LENGTH * SCALED_WIDTH);

//reg [7:0] text_rom_data_d1, text_rom_data_d2;
//reg [7:0] font_rom_data_d1, font_rom_data_d2;
//reg [2:0] text_x_sub_d1, text_x_sub_d2;
//reg        is_text_area_d1, is_text_area_d2;

//wire [7:0] safe_text_rom_data = (text_rom_data < 128) ? text_rom_data : 8'h3F;

//always @(posedge pixel_clk) begin
//    if (rst) begin
//        text_rom_addr <= 0;
//        font_rom_addr <= 0;
//        text_rom_data_d1 <= 0; text_rom_data_d2 <= 0;
//        font_rom_data_d1 <= 0; font_rom_data_d2 <= 0;
//        text_x_sub_d1 <= 0; text_x_sub_d2 <= 0;
//        is_text_area_d1 <= 0; is_text_area_d2 <= 0;
//        pdata_r <= 0; pdata_g <= 0; pdata_b <= 0;
//    end else begin
//        if (active && (y_coord_plus3 >= TEXT_Y_START) && (y_coord_plus3 < TEXT_Y_START + SCALED_HEIGHT)) begin
//            text_rom_addr <= text_col_plus3;
//            font_rom_addr <= (safe_text_rom_data * FONT_HEIGHT) + text_y_sub_plus3;
//        end else begin
//            text_rom_addr <= 0;
//            font_rom_addr <= 0;
//        end

//        // Text ROM data delay (2 cycles)
//        text_rom_data_d1 <= safe_text_rom_data;
//        text_rom_data_d2 <= text_rom_data_d1;
        
//        // Font ROM data delay (2 cycles)  
//        font_rom_data_d1 <= font_rom_data;
//        font_rom_data_d2 <= font_rom_data_d1;
        
//        // Control signals delay
//        text_x_sub_d1 <= text_x_sub;
//        text_x_sub_d2 <= text_x_sub_d1;
        
//        is_text_area_d1 <= is_text_area;
//        is_text_area_d2 <= is_text_area_d1;

//        if (is_text_area_d2) begin
//            if (font_rom_data_d2[7 - text_x_sub_d2]) begin
//                pdata_r <= COLOR_WHITE[23:16];
//                pdata_g <= COLOR_WHITE[15:8];
//                pdata_b <= COLOR_WHITE[7:0];
//            end else begin
//                pdata_r <= COLOR_BLACK[23:16];
//                pdata_g <= COLOR_BLACK[15:8];
//                pdata_b <= COLOR_BLACK[7:0];
//            end
//        end else begin
//            pdata_r <= COLOR_BLACK[23:16];
//            pdata_g <= COLOR_BLACK[15:8];
//            pdata_b <= COLOR_BLACK[7:0];
//        end
//    end
//end

//endmodule
