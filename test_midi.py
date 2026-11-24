"""SMC-PAD の動作確認用。パッドを押す・ノブを回すと MIDI の中身（Note / CC 番号）を表示する。
使い方: bluetoothctl connect <SMC-PAD の MAC> の後に python3 test_midi.py
"""
import mido

print("認識されているMIDI入力ポート一覧:")
ports = mido.get_input_names()
for p in ports:
    print(f" - {p}")

# SMC-PADまたはBLE MIDIの名前が含まれるポートを探す
target_port = None
for p in ports:
    if "SMC" in p or "BLE" in p or "M-VAVE" in p:
        target_port = p
        break

if not target_port and ports:
    # 見つからない場合は一番最初のポートを仮割り当て
    target_port = ports[0]

if not target_port:
    print("\nエラー: MIDIポートが見つかりません。bluetoothctl connect を確認してください。")
    raise SystemExit(1)

print(f"\n[{target_port}] に接続しました。パッドを押してください (Ctrl+Cで終了)")

try:
    with mido.open_input(target_port) as inport:
        for msg in inport:
            print(f"MIDI受信: {msg}")
except KeyboardInterrupt:
    print("\n終了します")
