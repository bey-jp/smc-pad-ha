import mido
import requests
import json
import threading
import time
import sys
import os
from flask import Flask, request, jsonify

# ==================== 設定エリア ====================
HA_URL = "http://homeassistant.local:8123"
HA_TOKEN = "YOUR_LONG_LIVED_ACCESS_TOKEN"  # HAのプロフィール→長期アクセストークン
EVENT_NAME = "smc_pad_event"
LISTEN_PORT = 5001
# ====================================================

HEADERS = {
    "Authorization": f"Bearer {HA_TOKEN}",
    "Content-Type": "application/json",
}

outport = None
app = Flask(__name__)

@app.route('/set_led', methods=['POST'])
def set_led():
    global outport
    data = request.get_json(force=True) or {}
    note = int(data.get('note', 67))
    color = int(data.get('color', data.get('velocity', 0)))

    if outport:
        try:
            # 1. 通常の Note ON 送信 (Ch 0)
            msg_note = mido.Message('note_on', channel=0, note=note, velocity=color)
            outport.send(msg_note)

            # 2. CC (Control Change) 送信 (Ch 0)
            msg_cc = mido.Message('control_change', channel=0, control=note, value=color)
            outport.send(msg_cc)

            # 3. SMC-PAD / M-VAVE Dedicated SysEx LED Send
            sysex_data = [0x00, 0x02, 0x04, note & 0x7F, color & 0x7F]
            msg_sysex = mido.Message('sysex', data=sysex_data)
            outport.send(msg_sysex)

            print(f"[LED 送信完了] Note={note}, Color={color} (Note/CC/SysEx 一括送信)")
            return jsonify({"status": "ok", "note": note, "color": color}), 200

        except Exception as e:
            print(f"[LED 送信エラー] {e}")
            return jsonify({"status": "error", "message": str(e)}), 500
    else:
        print("[LED エラー] outport が未接続です")
        return jsonify({"status": "error", "message": "MIDI outport not connected"}), 500


def run_flask():
    app.run(host='0.0.0.0', port=LISTEN_PORT)

# ノブ(CC)は回すと大量に届くので、CCごとに間引いて送る。
#  - 回し始めの値は即送信(反応を速く)
#  - 以降は CC_INTERVAL 秒ごとに最新値だけ送信
#  - 回し終わりの値は必ず送信(取りこぼし無し)
CC_INTERVAL = 0.25   # 電球側の処理が追いつく間隔(速く回した時の詰まり対策)
_cc_lock = threading.Lock()
_cc_state = {}  # cc番号 -> {"latest": msg, "sent": 値, "timer": Timer or None}


def post_to_home_assistant(msg):
    val = getattr(msg, 'value', getattr(msg, 'velocity', None))
    url = f"{HA_URL}/api/events/{EVENT_NAME}"
    payload = {
        "type": msg.type,
        "channel": getattr(msg, 'channel', None),
        "note": getattr(msg, 'note', getattr(msg, 'control', None)),
        "value": val,
    }
    try:
        requests.post(url, headers=HEADERS, data=json.dumps(payload), timeout=2)
        print(f"[HA送信成功] Type: {msg.type}, Note/CC: {payload['note']}, Val: {val}")
    except Exception as e:
        print(f"[HA送信エラー] {e}")


def _cc_flush(cc):
    with _cc_lock:
        st = _cc_state[cc]
        msg = st["latest"]
        if msg.value == st["sent"]:
            st["timer"] = None  # 変化なし → 間引き終了
            return
        st["sent"] = msg.value
        st["timer"] = threading.Timer(CC_INTERVAL, _cc_flush, (cc,))
        st["timer"].daemon = True
        st["timer"].start()
    post_to_home_assistant(msg)


# ---- ノブの「今の状態から回した分だけ」変える処理(2026-11-12) ----
# SMC-PAD のノブは本体が 0〜127 の位置を覚えていて、外から書き換えできない
# (CCを送っても無視)。端では何も送ってこない。
# そのまま値を使うと、ライトが明るいのにノブ位置が低いと右回しで暗くなる。
# → 回し始め(と向きを変えた時)に「今のライトの状態」を起点にし、
#    右回しは ノブ位置〜127 を 起点〜127 に、左回しは ノブ位置〜0 を 起点〜0 に割り当てる。
#    これで回す向きと明るさの向きが必ず一致し、端まで必ず届く。
GESTURE_IDLE = 1.2      # これ以上止まったら次は新しい回し始め
RECENT_SENT = 10.0      # 直近に自分で送った値があればHAに聞かずそれを起点にする
BRIGHT_UNKNOWN = -1     # 点灯中で明るさ不明 → 最後に自分で点けた値(無ければ127)を起点にする(2026-11-23)
# CC -> (entity_id, 状態 -> 0〜127 に戻す関数)
def _bright_to_v(st):
    if st.get("state") != "on":
        return 0
    b = st.get("attributes", {}).get("brightness")
    if b is None:
        return BRIGHT_UNKNOWN   # 点灯中だが明るさを返さない電球(廊下の CozyLife など)
    return max(1, round((b / 255) ** 0.5 * 127))   # HA側の (v/127)^2*100 の逆
def _ct_to_v(st):
    k = st.get("attributes", {}).get("color_temp_kelvin")
    return None if k is None else min(127, max(0, round((k - 2700) / 3800 * 127)))
def _fan_to_v(st):
    if st.get("state") != "on":
        return 0
    pct = st.get("attributes", {}).get("percentage") or 0
    return min(127, max(0, round(pct / 100 * 127)))
KNOB_SOURCE = {
    30: ("light.e27_led_lamp1", _bright_to_v),
    31: ("light.e27_led_lamp2", _bright_to_v),
    32: ("light.philips_bulb_0888_light", _bright_to_v),
    33: ("light.smart_bulb_light", _bright_to_v),
    34: ("light.0xbc026efffeb1f0c5", _bright_to_v),
    37: ("light.floor_lamp_0a2a", _bright_to_v),
    40: ("light.lumi_gateway_v3_light", _bright_to_v),
    41: ("light.floor_lamp_0a2a", _ct_to_v),
    43: ("fan.zhimi_fa1_f5db_fan", _fan_to_v),
}
_knob = {}  # cc -> {raw_prev, t_prev, v, v_on, t_sent, anchor_raw, anchor_v, dir}


def _ha_state_v(cc):
    src = KNOB_SOURCE.get(cc)
    if not src:
        return None
    try:
        r = requests.get(f"{HA_URL}/api/states/{src[0]}", headers=HEADERS, timeout=0.6)
        return src[1](r.json())
    except Exception as e:
        print(f"[ノブ起点取得エラー] CC{cc} {e}")
        return None


def _knob_value(cc, raw):
    now = time.time()
    k = _knob.setdefault(cc, {"raw_prev": None, "t_prev": 0, "v": raw, "v_on": None, "t_sent": 0,
                              "anchor_raw": raw, "anchor_v": raw, "dir": 0})
    new_gesture = k["raw_prev"] is None or now - k["t_prev"] > GESTURE_IDLE
    if new_gesture:
        base = k["v"] if now - k["t_sent"] < RECENT_SENT else None
        if base is None:
            base = _ha_state_v(cc)
            if base == BRIGHT_UNKNOWN:
                base = k["v_on"] if k["v_on"] else 127
        if base is None:
            base = k["v"]
        # 回し始めの1目盛り分の向きは前回位置との差で判断
        prev = k["raw_prev"] if k["raw_prev"] is not None else raw
        k["anchor_raw"], k["anchor_v"], k["dir"] = prev, base, 0
    d = 1 if raw > (k["raw_prev"] if k["raw_prev"] is not None else raw) else -1
    if not new_gesture and k["dir"] != 0 and d != k["dir"]:
        # 向きを変えた → 今の値・位置を新しい起点に
        k["anchor_raw"], k["anchor_v"] = k["raw_prev"], k["v"]
    k["dir"] = d
    ar, av = k["anchor_raw"], k["anchor_v"]
    if raw >= ar:
        v = 127 if ar >= 127 else av + (raw - ar) * (127 - av) / (127 - ar)
    else:
        v = 0 if ar <= 0 else av - (ar - raw) * av / ar
    v = int(round(min(127, max(0, v))))
    k["raw_prev"], k["t_prev"], k["v"], k["t_sent"] = raw, now, v, now
    if v > 0:
        k["v_on"] = v
    return v


def send_to_home_assistant(msg):
    """MIDI受信時にコールバックで呼ばれる関数"""
    if msg.type not in ["note_on", "note_off", "control_change"]:
        return

    if msg.type == "control_change":
        msg = msg.copy(value=_knob_value(msg.control, msg.value))
        with _cc_lock:
            st = _cc_state.setdefault(msg.control, {"latest": None, "sent": None, "timer": None})
            st["latest"] = msg
            if st["timer"] is not None:
                return  # 間引き中: 最新値だけ覚えておく
            if msg.value == st["sent"]:
                return
            st["sent"] = msg.value
            st["timer"] = threading.Timer(CC_INTERVAL, _cc_flush, (msg.control,))
            st["timer"].daemon = True
            st["timer"].start()
        post_to_home_assistant(msg)
        return

    post_to_home_assistant(msg)

def main():
    global outport
    print("MIDIポートを探しています...")
    target_port = None
    for p in mido.get_input_names():
        if "SMC" in p or "BLE" in p or "M-VAVE" in p:
            target_port = p
            break

    if not target_port:
        print("エラー: SMC-PADが見つかりません。")
        os._exit(1)

    print(f"[{target_port}] との双方向ブリッジを開始しました。")

    # Flask サーバー起動
    threading.Thread(target=run_flask, daemon=True).start()

    # MIDI 出力ポートを開く
    try:
        outport = mido.open_output(target_port)
    except Exception as e:
        print(f"出力ポートの開放エラー: {e}")
        os._exit(1)

    # 元の動作コードと同じく open_input を保持
    inport = mido.open_input(target_port, callback=send_to_home_assistant)
    print("[MIDI 受信待機中...]")

    try:
        while True:
            time.sleep(2)
            # SMC-PADの電源が切れてポートが消えたかチェック
            active_ports = mido.get_input_names()
            if target_port not in active_ports:
                print(f"[WARN] MIDIポート ({target_port}) の切断を検知しました。再起動のためにスクリプトを終了します。")
                break
    except Exception as e:
        print(f"[ERROR] エラーが発生しました: {e}")
    finally:
        try:
            inport.close()
            outport.close()
        except:
            pass
        print("[INFO] midi.py を終了し、SMC-PAD.sh へ制御を戻します。")
        os._exit(1)

if __name__ == "__main__":
    main()