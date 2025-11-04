
module hdmi_compositor (
    input wire       pixel_clk,
    input wire       rst,
    
    input wire       active,
    input wire [10:0] x_coord,
    input wire [9:0]  y_coord,

    // IMAGE ROM Interface 
    output reg  [$clog2(224*224)-1:0] img_rom_addr,
    input wire  [23:0]                img_rom_data,

    // TEXT ROM Interface
    output reg  [$clog2(80)-1:0]      text_rom_addr,
    input wire  [7:0]                text_rom_data,
    output reg  [$clog2(128*8)-1:0]   font_rom_addr,
    input wire  [7:0]                font_rom_data,

    // Control Signals
    input wire        enable_image,
    input wire        enable_text,

    // Pixel Output
    output reg [7:0] pdata_r,
    output reg [7:0] pdata_g,
    output reg [7:0] pdata_b
);

// Cấu hình Image 
localparam IMG_WIDTH  = 224;
localparam IMG_HEIGHT = 224;
localparam IMG_X_START = 528;
localparam IMG_Y_START = 248;

// Text config
localparam FONT_WIDTH  = 8;
localparam FONT_HEIGHT = 8;
localparam SCALE_FACTOR = 4;
localparam SCALED_WIDTH = FONT_WIDTH * SCALE_FACTOR;
localparam SCALED_HEIGHT = FONT_HEIGHT * SCALE_FACTOR;
localparam TEXT_X_START = 448;
localparam TEXT_Y_START = 344;
localparam TEXT_LENGTH = 20;

// Color
localparam COLOR_BLACK = 24'h000000;
localparam COLOR_WHITE = 24'hFFFFFF;

// pipeline cho Image
wire [10:0] x_img_prefetch = x_coord + 2;
wire in_img_area = (x_coord >= IMG_X_START) && (x_coord < IMG_X_START + IMG_WIDTH) &&
                   (y_coord >= IMG_Y_START) && (y_coord < IMG_Y_START + IMG_HEIGHT);
wire in_img_prefetch_area = (x_img_prefetch >= IMG_X_START) && (x_img_prefetch < IMG_X_START + IMG_WIDTH) &&
                            (y_coord >= IMG_Y_START) && (y_coord < IMG_Y_START + IMG_HEIGHT);
wire [7:0] img_x_prefetch = x_img_prefetch - IMG_X_START;
wire [7:0] img_y_prefetch = y_coord - IMG_Y_START;

reg [23:0] img_data_delayed;
reg        in_img_area_delayed;

// Pipeline cho Text
wire [10:0] x_text_plus3 = x_coord + 3;
wire [6:0] text_col_plus3 = (x_text_plus3 >= TEXT_X_START && 
                            x_text_plus3 < TEXT_X_START + TEXT_LENGTH * SCALED_WIDTH) ?
                           ((x_text_plus3 - TEXT_X_START) / SCALED_WIDTH) : 0;
wire [2:0] text_y_sub_plus3 = (y_coord >= TEXT_Y_START && 
                              y_coord < TEXT_Y_START + SCALED_HEIGHT) ?
                             (((y_coord - TEXT_Y_START) % SCALED_HEIGHT) / SCALE_FACTOR) : 0;
wire [2:0] text_x_sub = (x_coord >= TEXT_X_START && 
                        x_coord < TEXT_X_START + TEXT_LENGTH * SCALED_WIDTH) ?
                       (((x_coord - TEXT_X_START) % SCALED_WIDTH) / SCALE_FACTOR) : 0;
wire is_text_area = (y_coord >= TEXT_Y_START) && (y_coord < TEXT_Y_START + SCALED_HEIGHT) &&
                    (x_coord >= TEXT_X_START) && (x_coord < TEXT_X_START + TEXT_LENGTH * SCALED_WIDTH);

reg [7:0] text_rom_data_d1, text_rom_data_d2;
reg [7:0] font_rom_data_d1, font_rom_data_d2;
reg [2:0] text_x_sub_d1, text_x_sub_d2;
reg        is_text_area_d1, is_text_area_d2;

wire [7:0] safe_text_rom_data = (text_rom_data < 128) ? text_rom_data : 8'h3F;

// Logic 
always @(posedge pixel_clk) begin
    if (rst) begin
        pdata_r <= 0; pdata_g <= 0; pdata_b <= 0;
        img_rom_addr <= 0; text_rom_addr <= 0; font_rom_addr <= 0;
        img_data_delayed <= 0; in_img_area_delayed <= 0;
        text_rom_data_d1 <= 0; text_rom_data_d2 <= 0;
        font_rom_data_d1 <= 0; font_rom_data_d2 <= 0;
        text_x_sub_d1 <= 0; text_x_sub_d2 <= 0;
        is_text_area_d1 <= 0; is_text_area_d2 <= 0;
    end else if (~active) begin
        // Vùng blanking
        pdata_r <= 0; pdata_g <= 0; pdata_b <= 0;
        img_rom_addr <= 0; text_rom_addr <= 0; font_rom_addr <= 0;
    end else begin
        if (enable_image && in_img_prefetch_area) begin
            img_rom_addr <= img_y_prefetch * IMG_WIDTH + img_x_prefetch;
        end else begin
            img_rom_addr <= 0;
        end

        if (enable_text && (y_coord >= TEXT_Y_START) && (y_coord < TEXT_Y_START + SCALED_HEIGHT)) begin
            text_rom_addr <= text_col_plus3;
            font_rom_addr <= (safe_text_rom_data * FONT_HEIGHT) + text_y_sub_plus3;
        end else begin
            text_rom_addr <= 0;
            font_rom_addr <= 0;
        end

        // Pipeline Delay
        img_data_delayed <= img_rom_data;
        in_img_area_delayed <= in_img_area;
        
        text_rom_data_d1 <= safe_text_rom_data;
        text_rom_data_d2 <= text_rom_data_d1;
        font_rom_data_d1 <= font_rom_data;
        font_rom_data_d2 <= font_rom_data_d1;
        text_x_sub_d1 <= text_x_sub;
        text_x_sub_d2 <= text_x_sub_d1;
        is_text_area_d1 <= is_text_area;
        is_text_area_d2 <= is_text_area_d1;

        // Pixel Output Priority (Text trên Image)
        if (enable_text && is_text_area_d2) begin
            // Hiển thị Text 
            if (font_rom_data_d2[7 - text_x_sub_d2]) begin
                pdata_r <= COLOR_WHITE[23:16];
                pdata_g <= COLOR_WHITE[15:8];
                pdata_b <= COLOR_WHITE[7:0];
            end else begin
                // hiển thị image bên dưới
                if (enable_image && in_img_area_delayed) begin
                    pdata_r <= img_data_delayed[23:16];
                    pdata_g <= img_data_delayed[15:8];
                    pdata_b <= img_data_delayed[7:0];
                end else begin
                    pdata_r <= COLOR_BLACK[23:16];
                    pdata_g <= COLOR_BLACK[15:8];
                    pdata_b <= COLOR_BLACK[7:0];
                end
            end
        end else if (enable_image && in_img_area_delayed) begin
            // Hiển thị Image
            pdata_r <= img_data_delayed[23:16];
            pdata_g <= img_data_delayed[15:8];
            pdata_b <= img_data_delayed[7:0];
        end else begin
            // Background
            pdata_r <= COLOR_BLACK[23:16];
            pdata_g <= COLOR_BLACK[15:8];
            pdata_b <= COLOR_BLACK[7:0];
        end
    end
end

endmodule

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
