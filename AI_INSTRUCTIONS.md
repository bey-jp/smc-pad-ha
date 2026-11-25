# AI 向け指示書：SMC-PAD を Home Assistant のスイッチにする

> **使う人へ（人間向け）**
> Claude Code・Codex CLI・Gemini CLI など、**コマンドを実行できる AI** を、SMC-PAD とつなぐ Raspberry Pi（またはそこに SSH できるパソコン）で動かして、次の1行を送ってください。
>
> ```
> https://github.com/bey-jp/smc-pad-ha/blob/main/AI_INSTRUCTIONS.md を読んで、その手順どおりに私の SMC-PAD を Home Assistant のスイッチにしてください。
> ```
>
> あなたがやることは、SMC-PAD の電源を入れる・パッドを押す・ノブを回すこと、Home Assistant の画面でトークンを作ること、AI に聞かれたこと（どのボタンで何を動かしたいか）に答えることだけです。
>
> **ChatGPT・Gemini などのチャット（Web・スマホアプリ）でも使えます。** その場合は次の1行を送り、AI が出すコマンドを自分で実行して、結果を貼り返してください。
>
> ```
> https://github.com/bey-jp/smc-pad-ha/blob/main/AI_INSTRUCTIONS.md を読んで、「チャット型 AI の進め方」に従って、SMC-PAD を Home Assistant のスイッチにする手順を1つずつ案内してください。
> ```
>
> 解説記事: https://bey.jp/?p=119506

---

ここから先は、この指示書を読んでいる AI エージェント向けです。

## あなたの役割

ユーザーは初心者です。Linux もコマンドも知らない前提で、やさしい言葉（ユーザーの言語）で案内してください。専門用語を使うときは一言で説明します（例：MIDI＝音楽機材のボタンの信号、トークン＝Home Assistant に入るための合言葉）。

- コマンドは、あなたが実行できるものはすべてあなたが実行します。ユーザーに頼むのは次のことだけにします。
  - SMC-PAD の電源・パッドを押す・ノブを回す
  - Home Assistant（以下 HA）の画面での操作（トークンの作成、自動化の保存など）
  - パスワードの入力、管理者権限（sudo）の承認
  - どのボタンで何を動かすかを決めること
- あなたの環境が sudo や外部プログラムの実行を許していない場合は、無理に回避せず、実行するコマンドを1行ずつ示してユーザーに実行してもらいます。

## 仕組み（作業の前に把握しておくこと）

```
SMC-PAD ──Bluetooth MIDI──▶ Linux 機（SMC-PAD.sh + midi.py）──HTTP──▶ HA（イベント smc_pad_event）──自動化──▶ 照明など
```

- `midi.py` は、パッド・ノブの信号を HA のイベント API（`POST /api/events/smc_pad_event`）に送るだけです。何を動かすかは **HA の自動化** で決めます。
- イベントの中身: `{"type": "note_on" | "note_off" | "control_change", "note": <Note 番号 または CC 番号>, "value": <0〜127>}`
- `SMC-PAD.sh` は「スキャン → trust → connect → midi.py を起動」を繰り返します。切れても自動でつなぎ直します。

## 止まって確認する場所（必ず守る）

1. **トークンをチャットに貼らせない**：HA の長期アクセストークンは、ユーザーに `ha_token.txt` へ直接書いてもらいます（手順 4）。あなたもトークンの中身を表示（`cat` など）しません。
2. **HA の既存の設定を変える前**：自動化を HA に書き込む・既存の自動化を変える前に、内容を見せて「この自動化を追加してよいですか？」と聞きます。`configuration.yaml` や `automations.yaml` を直接書き換える場合は、先にバックアップを取ります。
3. **鍵・ヒーター・3D プリンターの電源など、危ないものをボタンにするとき**：押し間違いや、家の外から触れられる場所に置かないかを一言確認します。
4. **想定と違う出力が出たとき**：推測で先に進まず、何が出たかをそのまま説明して止まります。

## チャット型 AI の進め方（コマンドを実行できない AI 向け）

1. **最初に聞く**：SMC-PAD をつなぐ機械（Raspberry Pi の機種と OS）、そこにどうやって入るか（直接キーボード、または SSH）、HA がどこで動いているか。
2. **1回に1つ**：コマンドは1回に1つ（多くても続けて実行して問題ないもの2〜3行）だけ、コードブロックで示し、何をするかを一言添えます。
3. **結果を貼ってもらう**：毎回「表示された文字を全部コピーして、ここに貼ってください」と頼み、結果を見るまで次に進みません。
4. **ファイルの書き換え**は `nano <ファイル名>` で開いてもらい、どの行を何に変えるかを1か所ずつ示します（保存は Ctrl+O → Enter、終了は Ctrl+X）。

## 手順

### 0. 環境を調べる

- `midi.py` を動かす機械は、**Bluetooth が使える Linux**（Raspberry Pi OS など）である必要があります。`uname -a`、`cat /etc/os-release`、`bluetoothctl --version` で確認します。
- **HA OS（Home Assistant Operating System）の機械では動かせません**（Python のパッケージを入れられないため）。HA を HA OS で動かしている場合は、別の Raspberry Pi などに Raspberry Pi OS を入れて、そこで動かすよう案内します。HA と同じ機械（Raspberry Pi OS 上の HA Supervised や Docker）でも、別の機械でもかまいません。
- SMC-PAD と機械の距離は、Bluetooth が届く範囲（同じ部屋〜隣の部屋くらい）にします。
- HA の URL を確かめます：`curl -s -o /dev/null -w "%{http_code}\n" http://homeassistant.local:8123/` が `200` などを返せば OK。だめなら、ユーザーに HA を開いているブラウザのアドレス欄を教えてもらいます。

### 1. SMC-PAD をペアリング

ユーザーに SMC-PAD の電源を入れてもらってから:

```bash
bluetoothctl --timeout 5 scan on > /dev/null 2>&1 && bluetoothctl devices
```

「SMC-PAD」の行の MAC アドレス（`XX:XX:XX:XX:XX:XX`）を控え、

```bash
bluetoothctl pair    <MAC>
bluetoothctl trust   <MAC>
bluetoothctl connect <MAC>
```

`Connection successful` が出れば OK。出なければ、SMC-PAD の電源を入れ直してもらい、もう一度 scan から。

### 2. ソフトを入れる

```bash
sudo apt update
sudo apt install -y git python3-rtmidi libasound2-dev
pip3 install mido python-rtmidi requests flask --break-system-packages
cd ~ && git clone https://github.com/bey-jp/smc-pad-ha.git && cd smc-pad-ha
```

（`--break-system-packages` は、Raspberry Pi OS でシステムの Python にパッケージを入れるためのオプションです。venv を使いたい場合はそれでもかまいませんが、手順 6 の systemd で使う python のパスを合わせます。）

### 3. ボタン番号を確かめる

```bash
python3 test_midi.py
```

ユーザーにパッドを1つずつ押し、ノブを回してもらいます。`note_on ... note=<番号>` がパッド、`control_change ... control=<番号>` がノブです。

- ポート一覧に `SMC-PAD` が無いときは、手順 1 の `connect` からやり直します。
- **番号は SMC-PAD の設定（専用アプリ MidiSuite）で変わります。** 筆者の設定ではパッドが Note 100〜115（PAD BANK で 52〜67）、ノブが CC 30〜37（KNOB BANK で 38〜45）ですが、ユーザーの番号は必ず実測します。
- 押した場所と番号の対応表（4×4 の並び、ノブ 1〜8）を作ってユーザーに見せます。Ctrl+C で終了。

### 4. HA のトークンを用意する

ユーザーに、HA の画面で次を操作してもらいます。

1. 左下のユーザー名 → 「セキュリティ」タブ → 一番下の「長期有効アクセストークン」→「トークンを作成」
2. 名前に `SMC-PAD` と入れる → 表示された長い文字列をコピー（一度しか表示されません）
3. ターミナルで `nano ~/smc-pad-ha/ha_token.txt` を開き、貼り付けて保存（Ctrl+O → Enter → Ctrl+X）

あなたは中身を表示せずに、`test -s ~/smc-pad-ha/ha_token.txt && echo ok` で存在だけ確認し、`chmod 600 ~/smc-pad-ha/ha_token.txt` にします。`midi.py` はこのファイルがあれば自動で読みます（`ha_token.txt` は .gitignore 済み）。

トークンが正しいかは、中身を出さずに確認します:

```bash
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $(cat ~/smc-pad-ha/ha_token.txt)" <HA_URL>/api/
```

`200` なら OK、`401` ならトークンの貼り間違いです。

### 5. midi.py と SMC-PAD.sh を設定して動かす

- `midi.py` の `HA_URL` を、手順 0 で確かめた URL に変えます。
- `midi.py` の `KNOB_SOURCE` は**筆者の家の entity_id** です。ユーザーがノブを使わないなら `KNOB_SOURCE = {}` に、使うなら手順 7 で決めたノブ（CC 番号）と entity_id に書き換えます（下の「ノブについて」）。
- `SMC-PAD.sh` の `MAC_ADDR` を手順 1 の MAC に変えます。

動作確認:

```bash
cd ~/smc-pad-ha && bash SMC-PAD.sh
```

パッドを押して `[HA送信成功] Type: note_on, Note/CC: <番号>, Val: ...` が出れば、HA に届いています。HA 側でも見たい場合は、ユーザーに「開発者ツール → イベント → イベントをリッスン」に `smc_pad_event` を入れて「リッスン開始」を押してもらい、パッドを押して表示されるのを確認します。Ctrl+C で止めます。

### 6. 自動で起動させる（systemd）

`systemd/smc-pad.service` の `User`（`whoami` の結果）と、`WorkingDirectory`・`ExecStart` のパス（例 `/home/<ユーザー>/smc-pad-ha`）を書き換えてから:

```bash
sudo cp systemd/smc-pad.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now smc-pad.service
systemctl status smc-pad.service --no-pager
```

`active (running)` なら OK。ログは `journalctl -u smc-pad.service -f`。

### 7. ボタンに機能を割り当てる（HA の自動化）

1. **動かせる機器の一覧を作る**：トークンで HA の状態一覧を取り、`light.` `switch.` `fan.` `lock.` `climate.` などの entity_id と名前（`friendly_name`）を表にしてユーザーに見せます。

   ```bash
   curl -s -H "Authorization: Bearer $(cat ~/smc-pad-ha/ha_token.txt)" <HA_URL>/api/states \
     | python3 -c "import json,sys; [print(s['entity_id'], '|', s['attributes'].get('friendly_name','')) for s in json.load(sys.stdin) if s['entity_id'].split('.')[0] in ('light','switch','fan','lock','climate','cover','scene','script')]"
   ```

2. **ユーザーと割り当てを決める**：手順 3 の対応表を見せながら、「どのパッドで何をオン・オフするか」「どのノブで何の明るさを変えるか」を聞きます。全部を一度に決めなくてよい、と伝えます。
3. **自動化の YAML を作る**：ボタン1個につき自動化1つ。`automations_example.yaml` が実例です。
   - パッド（オン・オフ）:

     ```yaml
     alias: "SMC-PAD Note104: 廊下の照明"
     triggers:
       - trigger: event
         event_type: smc_pad_event
         event_data: {type: note_on, note: 104}
     actions:
       - action: light.toggle      # switch なら switch.toggle、fan なら fan.toggle
         target: {entity_id: light.hallway}
     mode: single
     ```

   - 鍵：`lock.toggle` は無いので、`automations_example.yaml` の Note 100 のように「施錠中なら解錠、それ以外は施錠」にします。
   - ノブ（明るさ）：値 0 で消灯、それ以外は `(値/127)^2 × 100 %`（人の目に自然な2乗カーブ）。`automations_example.yaml` の `smc_pad_knob_30` をそのまま使い、CC 番号と entity_id だけ変えます。`mode: restart` を残します。
4. **HA に入れる**（どちらかをユーザーに選んでもらう）:
   - **画面で貼る（おすすめ）**：「設定 → オートメーションとシーン → オートメーションを作成 → 新しいオートメーションを作成 → 右上の︙ → YAML で編集」に、あなたが作った YAML を1つずつ貼って保存してもらいます。
   - **あなたが API で入れる**：内容を見せて了解を得てから、1件ずつ `POST <HA_URL>/api/config/automation/config/<一意のid>`（本文は上の YAML を JSON にしたもの、`id` も含める）で作ります。HA の UI が内部で使っている API なので、エラーになったら画面で貼る方法に切り替えます。
5. 1つ作るごとにユーザーにボタンを押してもらい、動くことを確かめます。

#### ノブについて

- SMC-PAD のノブは本体が 0〜127 の位置を覚えていて、端では信号を送りません。`midi.py` は回し始めに HA から今の明るさを読み、「今の明るさから、回した分だけ」動かします。そのために、**ノブ（CC 番号）と動かす entity_id の組を `KNOB_SOURCE` に書く必要があります**（明るさは `_bright_to_v`、色温度は `_ct_to_v`、ファンの風量は `_fan_to_v`）。
- `KNOB_SOURCE` を書き換えたら `sudo systemctl restart smc-pad.service`。
- ノブで明るさがおかしな動き（途中で消える・急に 100% になる）をしたら、**ほかの自動化（人感センサーなど）が同じ照明を操作していないか**を、HA のログブックで確かめます。

### 8. パッドの色（任意）

パッドのバックライトの色は HA からは変えられません。ユーザーに M-VAVE の専用アプリ **MidiSuite**（https://www.m-vave.com/download ）で、パッドごとに色を設定してもらいます（本体に保存されます）。色で場所を分けると見分けやすい（例：照明は暖色、家電は青、鍵は緑）と提案します。

### 9. ラベルを 3D プリントする（任意）

ユーザーが 3D プリンターを持っていれば、`overlay/` のデータを案内します（README の「3D プリントのラベル」）。好きな字にするなら、`overlay/custom_from_blank.scad` の `pad_labels` / `knob_labels` を、手順 7 で決めた割り当てに合わせて書き換えます。囲まれた部分のある字（口・田など）は `bridges` につなぎ線を足します。OpenSCAD があなたの環境にあれば、`openscad -o pad.stl custom_from_blank.scad` で書き出せます。

### 10. 終わったら

ユーザーに次をまとめて伝えます。

- ボタンと動く機器の対応表（印刷してパッドの横に貼れる形）
- SMC-PAD の電源を切っても、入れ直せば自動でつながること
- 困ったときに見るもの：`journalctl -u smc-pad.service -f`、HA の「開発者ツール → イベント」で `smc_pad_event`
- トークンを作り直したら `ha_token.txt` を書き換えて `sudo systemctl restart smc-pad.service`

## 参考

- README（手順の詳細・ノブの工夫）: https://github.com/bey-jp/smc-pad-ha#readme
- HA の REST API: https://developers.home-assistant.io/docs/api/rest/
- この指示書の問題や間違いは、GitHub の Issues へ：https://github.com/bey-jp/smc-pad-ha/issues
