# 📺 HDMI Image & Text Display using Arty Z7-20

This project demonstrates how to generate HDMI video output using the **Arty Z7-20 (Zynq-7020)** FPGA board.  
It can display **images and text** on an HDMI monitor using custom Verilog modules for pixel generation, TMDS encoding, and serialization.

---

## ✅ Features

- 🎨 Display **image + text overlay** on HDMI screen  
- 🖥 Supports **1280×720 @ 60Hz (720p)** HDMI output  
- ⚡ Real-time pixel generation and compositing  
- 🔄 TMDS encoding + OSERDES high-speed serialization  
- 🧩 Fully modular Verilog design (easy to modify)

---

## 📁 Project Structure

| File / Module        | Description |
|----------------------|-------------|
| `top.v`              | Top-level design, connects HDMI TMDS outputs, clocking, and modules |
| `hdmi_compositor.v`  | Generates RGB pixel data, background, text, or images |
| `tmds_encode.v`      | TMDS encoding for each RGB channel |
| `tmds_oserdes.v`     | Uses OSERDES to serialize TMDS signals to HDMI differential outputs |
| `constraints.xdc`    | Pin assignments for Arty Z7-20, clock pins, HDMI pins |

## 🚀 Build & Run

### ✅ Requirements

| Tool/Hardware | Details |
|---------------|---------|
| Board         | Digilent Arty Z7-20 |
| Software      | Vivado 2020.2 or later |
| Display       | HDMI Monitor (supports 720p) |

### ▶ Steps

1. Open **Vivado → Create RTL Project**
2. Add source files (`top.v`, `hdmi_compositor.v`, `tmds_encode.v`, `tmds_oserdes.v`)  
3. Add constraints file (`.xdc`)  
4. Synthesize → Implement → Generate Bitstream  
5. Program FPGA → Connect HDMI monitor → Done! ✅
