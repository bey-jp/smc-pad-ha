#!/bin/bash
export PYTHONUNBUFFERED=1

# このスクリプトと同じフォルダの midi.py を起動する
DIR="$(cd "$(dirname "$0")" && pwd)"

MAC_ADDR="XX:XX:XX:XX:XX:XX"

while true; do
    echo "[SMC-PAD] 周囲のデバイスをスキャン中..."
    bluetoothctl scan on > /dev/null 2>&1 &
    SCAN_PID=$!
    sleep 3
    kill $SCAN_PID > /dev/null 2>&1

    echo "[SMC-PAD] Trust（信頼）設定を適用します: ${MAC_ADDR}"
    bluetoothctl trust ${MAC_ADDR} > /dev/null 2>&1

    echo "[SMC-PAD] Bluetooth 接続を試行します: ${MAC_ADDR}"
    
    CONNECTED=0
    for i in {1..5}; do
        OUTPUT=$(bluetoothctl connect ${MAC_ADDR} 2>&1)
        if echo "$OUTPUT" | grep -q "Connection successful"; then
            echo "[SMC-PAD] Bluetooth 接続に成功しました！"
            CONNECTED=1
            break
        fi
        sleep 2
    done

    if [ $CONNECTED -eq 1 ]; then
        sleep 2
        echo "[SMC-PAD] Python MIDI ブリッジを起動します..."
        /usr/bin/python3 "${DIR}/midi.py"
    fi

    echo "[SMC-PAD] 切断されました。再接続を試みます..."
    sleep 3
done