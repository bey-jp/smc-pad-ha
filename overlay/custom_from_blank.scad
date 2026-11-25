// 無地の STL（pad_plate_blank_t3.5.stl / knob_plate_blank.stl）に好きな字を入れる
// 使い方:
//   1. このファイルを無地の STL と同じフォルダに置いて OpenSCAD で開く
//   2. part と、pad_labels（パッド）または knob_labels（ノブ）の字を書き換える
//   3. F6（レンダリング）→ F7（STL を書き出す）
// 字が無い所は "" にする。フォントは Noto Sans CJK JP Bold を入れておく。

part = "pad";   // "pad" = パッド板 / "knob" = ノブ板

font = "Noto Sans CJK JP:style=Bold";

// ── パッド板: 上の段から 4 文字ずつ。字は板を貫通する穴になり、パッドの光が透ける ──
pad_labels = [
  ["机", "床", "温", "植"],
  ["和", "風", "洋", "風"],
  ["廊", "洗", "厨", "隠"],
  ["錠", "門", "事", "全"],
];
pad_text_size = 21.6;   // 字の大きさ（パッドは約 30.9mm 角）

// ── ノブ板: ノブ 1〜8 の下に入る字。並びは 下段左=1, 下段右=2, … 上段左=7, 上段右=8 ──
knob_labels = ["隠", "洗", "事", "廊", "厨", "和", "洋", "床"];
knob_text_size = 7.6;   // 実寸で約 10mm 角。これより小さいと潰れやすい
knob_inlay = 0.6;       // 表から彫り込む深さ（2 色刷り用）

// ── 中抜け防止のつなぎ線（パッド板だけ）: 「口」「田」のように囲まれた部分は抜け落ちるので棒でつなぐ ──
// [字, [[角度, 上下の位置, 左右の位置, 長さ], ...]]。位置・長さは字の大きさに対する割合。
// 一番かんたんなのは斜め 1 本 [[45, 0]]。ダメならバッテン [[45, 0], [-45, 0]]。
// 下は筆者の 16 字で、すべて 1 枚につながることを確認済み。
bridges = [
  ["錠", [[-45, 0]]],
  ["門", [[45, 0], [-45, 0]]],
  ["温", [[0, 0.39, 0, 0.5], [0, 0.19, 0, 0.5], [90, -0.2, -0.05, 0.5], [90, -0.2, 0.15, 0.5], [90, -0.2, 0.35, 0.5]]],
  ["風", [[45, 0]]],
  ["植", [[0, 0.2], [0, -0.2], [0, 0]]],
  ["和", [[90, -0.38, 0.229, 0.194]]],
  ["廊", [[-45, 0]]],
  ["洗", [[90, 0.373, 0.063, 0.199]]],
  ["厨", [[45, 0]]],
  ["隠", [[45, 0]]],
  ["事", [[45, 0], [-45, 0]]],
  ["全", [[90, 0.069, -0.312, 0.185]]],
];
bridge_w = 1.0;   // つなぎ線の太さ(mm)

// ───────────── ここから下は書き換え不要 ─────────────
pad_pos = [-48.5625, -16.1875, 16.1875, 48.5625];   // パッドの中心（板の中心が原点）

function bridges_for(ch) = let(i = search([ch], bridges)[0]) is_list(i) ? [] : bridges[i][1];

module label2d(ch, size, use_bridges = true) {
  difference() {
    offset(delta = 0.001)   // フォントの輪郭が壊れている字で穴が消えるのを防ぐ
      text(ch, size = size, font = font, halign = "center", valign = "center");
    for (b = use_bridges ? bridges_for(ch) : []) {
      x = len(b) > 2 ? b[2] : 0;
      l = len(b) > 3 ? b[3] : 1.9;
      if (b[0] == 0)       translate([x * size, b[1] * size]) square([l * size, bridge_w], center = true);
      else if (b[0] == 90) translate([x * size, b[1] * size]) square([bridge_w, l * size], center = true);
      else rotate([0, 0, b[0]]) translate([0, b[1] * size]) square([l * size, bridge_w], center = true);
    }
  }
}

if (part == "pad") {
  difference() {
    import("pad_plate_blank_t3.5.stl");
    for (r = [0:3]) for (c = [0:3]) if (pad_labels[r][c] != "")
      translate([pad_pos[c], pad_pos[3 - r], 0])
        linear_extrude(height = 20, center = true) label2d(pad_labels[r][c], pad_text_size);
  }
} else {
  // ノブ板: 原点は左下、厚み 2.8mm。ノブの中心 x = 14 / 45、y = 24 / 57 / 90 / 123
  difference() {
    import("knob_plate_blank.stl");
    for (i = [0:7]) if (knob_labels[i] != "")
      translate([14 + (i % 2) * 31, 24 + floor(i / 2) * 33 - 16, 2.8 - knob_inlay])
        linear_extrude(height = 1) label2d(knob_labels[i], knob_text_size, false);   // 彫り込みは貫通しないので、つなぎ線は不要
  }
}
