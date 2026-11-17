// SMC-PAD ノブ用ラベルプレート(1枚板、ノブ8個 = 2列×4段)
// 2026-11-11 作成。2色印刷前提: 土台(base_t)の上に字・目盛りを raise_t 盛り上げる。
// 盛り上げ開始の高さ(base_t=2.0mm)でスライサーに一時停止/フィラメント交換を入れる。
//
// 実測: 全体 57×147mm、ノブ直径18mm、左右のノブ間13mm、上下のノブ間15mm、左端→ノブ5mm
// 上下の余白は不明のため中央配置(上下とも15mm)。

$fn = 96;

plate_w = 57;
plate_h = 147;
base_t  = 2.0;   // 土台の厚み(1色目)
raise_t = 0.8;   // 盛り上げ(2色目)。0.2mm層なら4層

knob_d     = 18;
hole_d     = 19;   // ノブが通る穴(片側0.5mmの隙間)
gap_x      = 13;   // 左右のノブ間(縁と縁)
gap_y      = 15;   // 上下のノブ間(縁と縁)
left_margin = 5;   // 左端からノブの縁まで
pitch_x = knob_d + gap_x;  // 31
pitch_y = knob_d + gap_y;  // 33
cols = 2; rows = 4;
grid_h = (rows-1)*pitch_y + knob_d;
top_margin = (plate_h - grid_h)/2;   // 15(中央配置)

function kx(c) = left_margin + knob_d/2 + c*pitch_x;            // 原点=左下
function ky(r) = plate_h - top_margin - knob_d/2 - r*pitch_y;   // r=0が上段

font_name = "Noto Sans CJK JP:style=Bold";

// ラベル [通常, KNOB BANK]。ノブ番号は実機どおり 下段左=1, 下段右=2, … 上段左=7, 上段右=8。
labels = [
  ["隠", "洋風"],   // 1: CC30 トイレ電球 / CC38 洋室ファン
  ["洗", "和風"],   // 2: CC31 洗面電球   / CC39 和室ファン
  ["事", "門"],     // 3: CC32 Office電球 / CC40 lumi gateway
  ["廊", "色温"],   // 4: CC33 廊下電球   / CC41 フロアライト色温度
  ["厨", ""],       // 5: CC34 キッチンE17 / CC42 空き
  ["和", "風量"],   // 6: CC35 和室 明るさ / CC43 サーキュレーター風量
  ["洋", "縦振"],   // 7: CC36 洋室 明るさ / CC44 縦首振り
  ["床", "横振"],   // 8: CC37 フロアライト / CC45 横首振り
];

// 2026-11-12 v2: 4.6mm/3.3mm では潰れ、BANK枠内の抜き字(黒い小島)が剥がれた。
// → 字を約2倍にし、通常と BANK を横1行に並べる。枠は廃止し、黒い小島を作らない。
// OpenSCAD の size に対し、このフォントの漢字は実寸で 幅≒1.25倍 高さ≒1.3倍。
main_size = 7.6;          // メインの字 実寸≒10mm角。BANKの字・凡例は刻印しない
bank_size = 4.5;          // KNOB BANK の字(右) 実寸≒6mm(旧3.3の約1.4倍)
label_gap = 1.2;          // 通常と BANK の間
label_dy  = -16.0;        // ノブ中心から字の中心まで(穴の下と下段ノブの目盛りの間)
col_dx    = [0, 0];        // 列ごとの左右補正(右列は右端に寄りすぎないよう左へ)
bank_r    = 1.2;

// 目盛り: 真上を0°として時計回り -150°〜+150°(一般的な300°回転)
tick_r0 = hole_d/2 + 0.3;
tick_len_minor = 1.8;     // 2026-11-12 潰れたため約2倍に
tick_len_major = 1.8;     // 字を大きくしたので長さは揃え、太さで区別
tick_w  = 1.4;
tick_w_major = 1.8;

module rrect(size, r) {
  offset(r = r) square([size[0]-2*r, size[1]-2*r], center = true);
}

module ticks() {
  for (i = [0:10]) {
    a = -150 + i*30;
    major = (i == 0 || i == 5 || i == 10);
    l = major ? tick_len_major : tick_len_minor;
    rotate(-a) translate([0, tick_r0 + l/2]) square([major ? tick_w_major : tick_w, l], center = true);
  }
}

// 2026-11-12: BANK の字は小さすぎて潰れるため刻印しない(labels[i][1] は記録用のみ)
module label2d(lb) {
  translate([0, label_dy])
    text(lb[0], size = main_size, font = font_name, halign = "center", valign = "center");
}

// 上の余白に凡例: 大きい字=通常、小さい字=BANK
module legend2d() {
  translate([plate_w/2, plate_h - 6.5]) {
    translate([-9, 0]) text("通常", size = 5.0, font = font_name, halign = "center", valign = "center");
    translate([13, 0]) text("BANK", size = 3.4, font = font_name, halign = "center", valign = "center");
  }
}

module raised2d() {
  for (r = [0:rows-1]) for (c = [0:cols-1])
    translate([kx(c), ky(r)]) { ticks(); translate([col_dx[c], 0]) label2d(labels[(rows-1-r)*cols + c]); }  // r=0が上段なので反転
}

// style = "raised": 字を盛り上げ(字の面を上にして刷る。z=base_tで色替え)
// style = "inlay" : 字を彫り込み(字の面を下にして刷る。下から inlay_d で色替え)
//   表面は平ら。表から見ると 1色目の面 に 2色目の字 が見える。厚みは raised と同じ。
style   = "inlay";
inlay_d = 0.6;   // 彫り込み深さ(0.2mm層なら3層)
total_t = base_t + raise_t;

module holes() {
  for (r = [0:rows-1]) for (c = [0:cols-1])
    translate([kx(c), ky(r), -1]) cylinder(d = hole_d, h = total_t + 2);
}

module art2d() {
  intersection() {
    offset(delta = 0.001) raised2d();
    square([plate_w, plate_h]);
  }
}

if (style == "raised") {
  difference() {
    union() {
      cube([plate_w, plate_h, base_t]);
      translate([0, 0, base_t - 0.01])
        linear_extrude(height = raise_t + 0.01) art2d();
    }
    holes();
  }
} else {
  // 字の面(z=total_t)から inlay_d だけ彫る。ここではまだ字の面が上向き。
  // 印刷時はスライサーで裏返し(字の面をベッドへ)。
  difference() {
    cube([plate_w, plate_h, total_t]);
    translate([0, 0, total_t - inlay_d])
      linear_extrude(height = inlay_d + 1) art2d();
    holes();
  }
}
