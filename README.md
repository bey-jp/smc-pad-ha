# SMC-PAD × Home Assistant

Bluetooth MIDI パッド **M-VAVE SMC-PAD** を、Home Assistant の物理リモコンにします。

- 16 パッド × 2 ページ = 32 ボタン、8 ノブ × 2 バンク = 16 ノブ
- パッドを押すと HA のイベントが飛び、自動化で照明・家電・鍵を操作
- ノブで明るさ・風量を調整。**回す向きと明るさの向きが必ず一致する**工夫入り
- 3D プリントの漢字ラベル（パッド用）と 2 色刷りのノブ用ラベル板の STL / SCAD 付き

![パッド用ラベル](overlay/preview_v6_top.png)

## 仕組み

```
SMC-PAD ──BLE MIDI──▶ Raspberry Pi（SMC-PAD.sh + midi.py）──HTTP──▶ Home Assistant
                                                          イベント smc_pad_event
```

- `SMC-PAD.sh`: bluetoothctl でスキャン → trust → connect → midi.py を起動。切れたら最初からやり直す
- `midi.py`: MIDI を受けて HA のイベント API（`POST /api/events/smc_pad_event`）に送る
  - 送る中身: `{"type": "note_on" | "control_change", "note": <Note または CC 番号>, "value": <値>}`
  - ノブは間引き（回し始めは即送信、その後 0.25 秒ごとに最新値、最後の値は必ず送る）
  - ノブは「HA の今の明るさを起点に、回した分だけ動かす」方式（下記）
  - Flask で `:5001/set_led` を開き、HA からパッドの LED を制御できる（任意）

## セットアップ

1. 必要なもの: Python 3、`pip install mido python-rtmidi requests flask`、bluetoothctl
2. `SMC-PAD.sh` の `MAC_ADDR` を自分の SMC-PAD の MAC に書き換えます（`bluetoothctl scan on` で確認）。
3. `midi.py` の `HA_URL` と `HA_TOKEN`（HA の長期アクセストークン）を書き換えます。
4. 動作確認: `bash SMC-PAD.sh`。パッドを押すとログに Note 番号が出ます。
5. 常駐させる: `systemd/smc-pad.service` のパスとユーザーを直して `/etc/systemd/system/` に置き、
   `sudo systemctl enable --now smc-pad`
6. HA の自動化を作ります（`automations_example.yaml` を参照）。基本形:

```yaml
triggers:
  - trigger: event
    event_type: smc_pad_event
    event_data: {type: note_on, note: 104}
actions:
  - action: light.toggle
    target: {entity_id: light.hallway}
```

## ボタン番号（筆者の個体で実測）

| | 通常 | BANK ボタン ON |
|---|---|---|
| パッド | Note 100〜115 | Note 52〜67（PAD BANK） |
| ノブ 1〜8 | CC 30〜37 | CC 38〜45（KNOB BANK） |

パッドの並び（上段から）: `112-115 / 108-111 / 104-107 / 100-103`。ファームや設定で番号が違う場合があります。

## ノブの工夫

SMC-PAD のノブは本体が 0〜127 の「位置」を覚えていて、外から書き換えられません。
そのままだと「100% で点いているライトを、位置 10 のノブで右に回すと 1% に暗くなる」ことが起きます。

`midi.py` は回し始めに HA から今の明るさを読み、

- 右回し: 「ノブ位置〜127」を「今の明るさ〜最大」に割り当て
- 左回し: 「ノブ位置〜0」を「今の明るさ〜消灯」に割り当て

として送ります。どこから回しても、右に回せば明るく、左に回せば暗くなり、端まで必ず届きます。
明るさは HA 側で 2 乗カーブ `(値/127)^2 × 100 %` にしています（`automations_example.yaml`）。

## 3D プリントのラベル

| ファイル | 内容 |
|---|---|
| `overlay/pad_plate_full_v6.scad` / `pad_plate_full_v6_t3.5.stl` | パッド 16 個用の漢字ラベル（131×147mm、厚み 3.5mm）。文字は貫通穴で、パッドの LED が透ける |
| `overlay/knob_plate.scad` / `knob_plate_inlay.stl` | ノブ用ラベル板（57×147mm、厚み 2.8mm）。単色プリンターで 2 色刷り |
| `overlay/bridge.py` | 「口」「田」のような閉じた部分が抜け落ちないよう、自動でブリッジ（つなぎ線）を入れる補助スクリプト |

- 自分の字にするには SCAD の `grid_labels`（パッド）/ `labels`（ノブ）を書き換えて OpenSCAD で書き出します。フォントは Noto Sans CJK JP Bold。
- ノブ板の 2 色刷り（Creality K1C で確認）: 字の面を下にして印刷。0.8mm の層の前で一時停止して黒→白、1.6mm の層の前で一時停止して白→黒。
- 寸法は筆者の SMC-PAD の実測値です。

## 注意

- 鍵や 3D プリンターの電源など、遠隔操作するものは十分注意してください。自己責任でご利用ください。

## ライセンス

- このリポジトリのコードと 3D データ: MIT License（`LICENSE`）
- フォント（Noto Sans CJK JP）は同梱していません（SIL Open Font License）

紹介記事: https://bey.jp/
