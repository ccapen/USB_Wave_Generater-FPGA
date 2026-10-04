// vim: ts=4 sw=4 expandtab

// THIS IS GENERATED VERILOG CODE.
// https://bues.ch/h/crcgen
// 
// This code is Public Domain.
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted.
// 
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
// SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER
// RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
// NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE
// USE OR PERFORMANCE OF THIS SOFTWARE.

`ifndef CRC16_CCITT_V_
`define CRC16_CCITT_V_

// CRC polynomial coefficients: x^16 + x^12 + x^5 + 1
//                              0x1021 (hex)
// CRC width:                   16 bits
// CRC shift direction:         left (big endian)
// Input word width:            8 bits

module crc16_ccitt (
    input [15:0] I_crc,
    input [7:0] I_din,
    output [15:0] O_crc
);
    assign O_crc[0] = I_crc[8] ^ I_crc[12] ^ I_din[0] ^ I_din[4];
    assign O_crc[1] = I_crc[9] ^ I_crc[13] ^ I_din[1] ^ I_din[5];
    assign O_crc[2] = I_crc[10] ^ I_crc[14] ^ I_din[2] ^ I_din[6];
    assign O_crc[3] = I_crc[11] ^ I_crc[15] ^ I_din[3] ^ I_din[7];
    assign O_crc[4] = I_crc[12] ^ I_din[4];
    assign O_crc[5] = I_crc[8] ^ I_crc[12] ^ I_crc[13] ^ I_din[0] ^ I_din[4] ^ I_din[5];
    assign O_crc[6] = I_crc[9] ^ I_crc[13] ^ I_crc[14] ^ I_din[1] ^ I_din[5] ^ I_din[6];
    assign O_crc[7] = I_crc[10] ^ I_crc[14] ^ I_crc[15] ^ I_din[2] ^ I_din[6] ^ I_din[7];
    assign O_crc[8] = I_crc[0] ^ I_crc[11] ^ I_crc[15] ^ I_din[3] ^ I_din[7];
    assign O_crc[9] = I_crc[1] ^ I_crc[12] ^ I_din[4];
    assign O_crc[10] = I_crc[2] ^ I_crc[13] ^ I_din[5];
    assign O_crc[11] = I_crc[3] ^ I_crc[14] ^ I_din[6];
    assign O_crc[12] = I_crc[4] ^ I_crc[8] ^ I_crc[12] ^ I_crc[15] ^ I_din[0] ^ I_din[4] ^ I_din[7];
    assign O_crc[13] = I_crc[5] ^ I_crc[9] ^ I_crc[13] ^ I_din[1] ^ I_din[5];
    assign O_crc[14] = I_crc[6] ^ I_crc[10] ^ I_crc[14] ^ I_din[2] ^ I_din[6];
    assign O_crc[15] = I_crc[7] ^ I_crc[11] ^ I_crc[15] ^ I_din[3] ^ I_din[7];
endmodule

`endif // CRC16_CCITT_V_
