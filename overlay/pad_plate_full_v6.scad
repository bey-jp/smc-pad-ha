// SMC-PAD 用 漢字パッドオーバーレイ(1枚板、全16パッド)
// v6 (2026-11-11): 引っ越しに伴いスイッチ配置を変更。厚み3.5mm/ソケット3mm(v5_t3.5と同じ)。
//   2段目は 和ダーク→和風強 / 洋ダーク→洋風強 なので、和→風・洋→風 の間に「→」を貫通で追加。
// 実測: 全幅131mm、上下147mm。パッド間・外周の隙間を5.6mm→1.5mmに縮小し、
// 浮いた分をパッドサイズに回して27mm→約30.9mm角に拡大。
// 隣のパッドを誤って押さないための仕切りは、表面に壁を足すのではなく
// 裏面ソケットを深くすることで作る(パッド間に残る土台そのものが
// 深いソケットの分だけ相対的に高い壁になる)。
// 土台厚み2mm→3.5mm、ソケット深さ1.5mm→3mm(天井0.5mmは維持)。
// 空欄(◯)も同じ深さ3mmまで彫り込み、斜めハッチングでパッドに当たらないようにする。

$fn = 48;

gap      = 1.5;   // パッド間・外周の隙間(旧5.6mmから縮小)
n        = 4;     // 1辺のパッド数

plate_w  = 131;
plate_h  = 147;
tile_t   = 3.5;   // 土台厚み(v5_t3.5と同じ。深さ3mm+天井0.5mm)

// 幅131mmを「パッドn個+隙間(n+1)個(外周含め全て1.5mm)」で埋まるように
// パッドサイズを逆算する。縦方向も同じパッドサイズ・同じ隙間を使い、
// 余った分は上下の外周余白(実機のベゼル分)に割り当てる。
pad_size = (plate_w - (n+1)*gap) / n; // ≒30.875mm
grid_w   = n*pad_size + (n-1)*gap;    // パッド4個+内側の隙間3個ぶん
grid_h   = grid_w;                    // 縦横とも同じパッドサイズ・隙間

margin_lr = gap;                // 左右の外周余白 = 隙間と同じ1.5mm
margin_tb = (plate_h - grid_h) / 2; // 上下の外周余白(余り。実機のベゼル分)

socket_depth = 3;   // 裏面ソケット深さ(天井 = tile_t-socket_depth = 0.5mm)
socket_clear = 0.3;
socket_size  = pad_size + socket_clear;
blank_size   = pad_size + 0.3; // 空欄パッドのハッチング範囲

font_name = "Noto Sans CJK JP:style=Bold";
bridge_w  = 1.0;

// 文字サイズはパッドの物理サイズ拡大(27mm→約30.9mm)と連動させない。
// 元の27mm基準のまま(パッドが大きくなっても文字は同じ大きさを維持)。
text_base_size = 27;

// 文字ごとの文字サイズ倍率(標準=text_base_size*0.8 に対する倍率)。
// "3D","B2"はラテン文字+数字で標準サイズだと横に広がりすぎるため、
// 他の漢字1文字と横幅が揃うよう縮小。
size_table = [
  ["3D", 0.796],
  ["B2", 0.865],
];
function size_for(ch) =
  let(idx = search([ch], size_table)[0])
  is_list(idx) ? text_base_size*0.8 : text_base_size*0.8*size_table[idx][1];

// 文字ごとの中抜け防止ブリッジ。[角度, y比, x比(省略時0), 長さ比(省略時1.9)]
// 空リスト = ブリッジ不要な字。全て実際に検証し、1体化する最小構成のみ設定。
bridge_table = [
  ["錠", [[-45,0]]],
  ["音", [[90,0]]],
  ["門", [[45,0],[-45,0]]],
  ["天", []],
  // 温: 「日」は横線2本、「皿」は縦線3本で中抜け防止(斜め十字より見た目が良い)
  ["温", [[0,0.39,0,0.5],[0,0.19,0,0.5],[90,-0.2,-0.05,0.5],[90,-0.2,0.15,0.5],[90,-0.2,0.35,0.5]]],
  ["風", [[45,0]]],
  ["常", [[45,0]]],
  ["植", [[0,0.2],[0,-0.2],[0,0]]],
  ["机", []],
  ["3D", [[0,0,0.15,0.4]]],
  ["床", []],
  ["B2", [[45,0],[-45,0]]],
  // v6で追加。bridge.py(ラスタで囲み部分を検出し最短の縦/横ブリッジを自動配置)で算出
  ["和", [[90,-0.38,0.229,0.194]]],
  ["洋", []],
  // 廊・厨・隠は細かいので、短いブリッジでなく斜め1本(diag.pyで1体化を確認)
  ["廊", [[-45,0]]],
  ["洗", [[90,0.373,0.063,0.199]]],
  ["厨", [[45,0]]],
  ["隠", [[45,0]]],
  ["事", [[45,0],[-45,0]]],  // Office電球。斜め1本では1体化せずバッテン
  ["全", [[90,0.069,-0.312,0.185]]],
];
function bridges_for(ch) =
  let(idx = search([ch], bridge_table)[0])
  is_list(idx) ? [] : bridge_table[idx][1];

function col_x(c) = -grid_w/2 + pad_size/2 + c*(pad_size + gap);
function row_y(r) = grid_h/2 - pad_size/2 - r*(pad_size + gap);

// 実機レイアウト: 上段から13-16, 9-12, 5-8, 1-4(各行左から右)
// PAD: [[13,14,15,16],[9,10,11,12],[5,6,7,8],[1,2,3,4]]
grid_labels = [
  ["机", "床", "温", "植"],
  ["和", "風", "洋", "風"],
  ["廊", "洗", "厨", "隠"],
  ["錠", "門", "事", "全"],
];

// 和→風、洋→風 の矢印(2段目、1-2列目と3-4列目の境目に貫通穴)。
// y=+1mm付近で文字の隙間が約9mm、中心は境目より約1mm右なので、そこに長さ7mmの矢印。
arrow_on    = true;
arrow_len   = 7;
arrow_shaft = 1.2;
arrow_head_l = 3;
arrow_head_h = 3.2;
arrow_dy    = 1.0;  // 行中心からのY補正
arrow_dx    = 1.0;  // 境目からのX補正(左右の文字の隙間の中央)
module arrow_2d() {
  translate([-arrow_len/2, 0])
    union() {
      translate([0, -arrow_shaft/2]) square([arrow_len - arrow_head_l + 0.01, arrow_shaft]);
      polygon([[arrow_len - arrow_head_l, -arrow_head_h/2],
               [arrow_len, 0],
               [arrow_len - arrow_head_l,  arrow_head_h/2]]);
    }
}

module kanji_hole(ch) {
  ts = size_for(ch);
  linear_extrude(height = tile_t + 4, center = true)
    difference() {
      // offset(delta=0.001): 「洗」などフォント輪郭が自己交差する字で
      // "mesh is not closed" になり穴ごと消えるのを防ぐ(見た目への影響なし)
      offset(delta = 0.001)
        text(ch, size = ts, font = font_name, halign = "center", valign = "center");
      for (b = bridges_for(ch)) {
        ang = b[0];
        xoff = (len(b) > 2) ? b[2] : 0;
        len_frac = (len(b) > 3) ? b[3] : 1.9;
        if (ang == 0)
          // 水平バー: 座標そのまま(回転無し)
          translate([xoff*ts, b[1]*ts, 0])
            square([len_frac*ts, bridge_w], center = true);
        else if (ang == 90)
          // 垂直バー: 座標そのまま(回転無し)
          translate([xoff*ts, b[1]*ts, 0])
            square([bridge_w, len_frac*ts], center = true);
        else
          // 斜め(45/-45等): 原点中心に回転(既存の指定と互換)
          rotate([0,0,ang])
            translate([0, b[1]*ts, 0])
              square([len_frac*ts, bridge_w], center = true);
      }
    }
}

// 空欄パッド用の斜めハッチング。ソケット部分(天井0.5mm)だけを貫通させ、
// 土台全体(3.5mm)は貫通させない(実機パッドがソケットに収まるようにする)。
hatch_w     = 2;   // ハッチ線の太さ
hatch_pitch = 4;   // ハッチ線の間隔
ceiling_t   = tile_t - socket_depth; // 天井の厚み(0.5mm)

module blank_hatch() {
  intersection() {
    // 天井部分(z=[socket_depth, tile_t])だけに限定。上下に0.5mmずつ
    // 余裕を持たせて面一致による欠けを防止。
    translate([-blank_size/2, -blank_size/2, socket_depth - 0.5])
      cube([blank_size, blank_size, ceiling_t + 1], center = false);
    // 斜め45度の帯を並べる
    union()
      for (i = [-6:6])
        translate([i*hatch_pitch, 0, 0])
          rotate([0,0,45])
            linear_extrude(height = tile_t + 4, center = true)
              square([hatch_w, blank_size*2], center = true);
  }
}

module pad_cut(cx, cy, ch) {
  translate([cx, cy, 0]) {
    // 裏面ソケット(パッドの出っ張りを受ける)。空欄パッドも同じ深さで彫り、
    // 実機の未使用パッドがちゃんと収まるようにする。
    translate([0,0,-1])
      linear_extrude(height = socket_depth + 1)
        square([socket_size, socket_size], center = true);
    if (ch == "◯") {
      // 空欄パッド: 天井(0.5mm)だけを斜めハッチングで貫通させる
      blank_hatch();
    } else {
      // 漢字(貫通穴、ブリッジで中抜け防止)
      kanji_hole(ch);
    }
  }
}

// 試し刷り用: 0〜3を指定するとその縦1列だけを出力(左右は隙間gap分の縁)。
// -1で全16パッドの1枚板。コマンドラインから -D sample_col=N で上書き可。
sample_col = -1;

cols = (sample_col < 0) ? [0:n-1] : [sample_col:sample_col];
body_w  = (sample_col < 0) ? plate_w : pad_size + 2*gap;
body_cx = (sample_col < 0) ? 0 : col_x(sample_col);

difference() {
  translate([body_cx, 0, tile_t/2])
    cube([body_w, plate_h, tile_t], center = true);
  for (r = [0:3])
    for (c = cols)
      pad_cut(col_x(c), row_y(r), grid_labels[r][c]);
  if (arrow_on && sample_col < 0)
    for (c = [0, 2])
      translate([(col_x(c)+col_x(c+1))/2 + arrow_dx, row_y(1) + arrow_dy, 0])
        linear_extrude(height = tile_t + 4, center = true) arrow_2d();
}
