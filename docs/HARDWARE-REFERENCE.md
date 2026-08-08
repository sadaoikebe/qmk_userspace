# 自作キーボード ハードウェア・リファレンス

このリポジトリ（2022-01-03 の QMK upstream `1b953ac1e2` ベースのフォーク）で維持してきた
自作キーボードの**回路情報**をまとめたもの。

最新 QMK への移行にあたり、コードを捨てるキーボードについても
**この文書さえあれば再構築できる**ことを目的とする。

対象コミット: `master` = `e3d92a7463` (2026-02-13) / `nishimaki` = `c5f7cf0d26` (2026-04-17)

---

## 凡例

| 記号 | 意味 |
|---|---|
| 🟢 | 最新 QMK に移植する |
| 🟡 | コードは捨て、本文書の回路情報だけ残す（後日すぐ再構築できる状態にする） |
| ⚪ | 資料としてのみ残す。復活予定なし |

すべての AVR 機は **ATmega32U4**。fuse 設定は末尾の「共通: ISP / fuse」を参照。

## 処遇一覧

| キーボード | 処遇 | 備考 |
|---|---|---|
| TS52K | 🟢 移植 | 本命。ATmega版 / RP2040版とも **duplex 継続** |
| TS69 V3 | 🟢 移植 | 69系で一番使っている。duplex |
| 3×3 マクロパッド (winry / ymd09) | 🟡 資料化 | 現用。中身を差し替えて再構築する想定 |
| TS69 V1 / V2 | 🟡 資料化 | |
| Just68 / shobon62 | 🟡 資料化 | |
| upstream機 + keymap (just60, xd60, voyager60_alps, xd64) | 🟡 | `users/nicola` 移植後、keymap を置くだけ |
| TC69 | ⚪ 資料化（アルゴリズムのスタブ付き） | 静電容量。復活しやすい形で残す |
| ec3x3 | ⚪ 資料化のみ | **完全なプロトタイプ。復活予定なし** |
| cxt/12e4 | ⚪ ピン配置のみ | 使用終了 |
| handwired/ajazz82 | — **完全廃棄** | 資料も残さない（git 履歴にのみ存在） |

### ビルド済み `.hex` について

旧リポジトリにコミットされていたファームウェア `.hex`
（`ts52k_nicola4r.hex`, `xiudi_xd60_rev3_nicola.hex`, `xd60_rev3_nicola.hex`）は
**すべて破棄する。** 旧機種を焼き直す必要が生じた場合は、本文書の回路情報から再構築する。

> 旧フォークはビルド環境ごと失われており（第「参考」節）、
> `.hex` を再生成すること自体ができない。保全しても更新できない資産になるため残さない。
>
> `util/` 配下の ISP ライタ用 `.hex`（`pro_micro_ISP_B6_10.hex` 等）は upstream 由来なので対象外。

---

## 移行方針: フォークは不要

このリポジトリが upstream QMK のフォークである理由は、**`quantum/matrix.c` への duplex matrix パッチ 1 点のみ**だった。

duplex を `CUSTOM_MATRIX = lite` でキーボード側に実装すれば
（`matrix_init_custom()` / `matrix_scan_custom()` を各キーボードの `matrix.c` に書く）、
**コアへの差分がゼロになりフォークが不要になる。**

推奨する構成は QMK の **External Userspace**:

* 自分のリポジトリには `keyboards/` `users/` `keymaps/` だけを置く
* `qmk_firmware` は**無改造のまま** clone し、`qmk config user.overlay_dir=<自分のリポジトリ>` で結びつける
* QMK の追従は `git pull` するだけ。マージ競合が原理的に発生しない
* submodule は upstream 側の管理になるので、今回のような事故（`lib/ugfx` の孤児 gitlink）が起きない

> 機能名・コマンド名は本文書作成時点で未検証。着手時に最新の QMK ドキュメントで確認すること。

### 参考: 今回ビルド不能になった原因

`lib/ugfx` の gitlink が `master` に残っているのに `.gitmodules` にエントリが無い。

1. 2020-03-04 `05cae37503 "track parent"` で `lib/ugfx` を追加
2. upstream が 2021-10 に `b2a186cf92 "Purge uGFX. (#14720)"` で ugfx を削除（`.gitmodules` からも）
3. 2022-01 のマージで **`.gitmodules` は upstream 側・gitlink は自分側**が残り孤児化

→ `git submodule status` が `fatal: no submodule mapping found` で落ち、
`make git-submodule` も `qmk` CLI も動かなくなった。`git rm --cached lib/ugfx` で解消する。

---

## 1. TS52K — 🟢 本命 / RP2040 版を別途進行中

50% (52キー) 分割スペースバー。**duplex matrix**。

* ハードウェア: https://github.com/sadaoikebe/ts52k
* 現行 MCU: ATmega32U4 / 5V 16MHz Pro Micro / bootloader `qmk-dfu`
* VID/PID: `0xFEED` / `0x1969`
* ファームウェア: `keyboards/ts52k/keymaps/nicola4r/`（現役・NICOLA 親指シフト）

### マトリクス（duplex / BOTHWAYS）

```
MATRIX_ROWS 10   MATRIX_COLS 6      ← 論理 10×6 = 60 ポジション
DIODE_DIRECTION BOTHWAYS
MATRIX_ROW_PINS { D2, D3, B5, B6, C6 }        ← 実ピン 5 本
MATRIX_COL_PINS { C7, D4, D5, D6, D7, B4 }    ← 実ピン 6 本
```

**実配線は 5 行 × 6 列 = 11 ピン。** 各交点にダイオードを 2 個、向きを逆にして配置することで
論理的に 10 行分を得ている。論理行のマッピングは:

* 論理行 `0..4` → COL2ROW 側（ダイオード: COL=アノード, ROW=カソード）
* 論理行 `5..9` → ROW2COL 側（ダイオード: 逆向き）

スキャンは「前半 5 行を COL2ROW で読む → 後半 5 行を ROW2COL で読む」の 2 パス。

> **duplex は配線量を半減させるための設計であり、MCU が RP2040 に変わっても維持する。**
> duplex をやめると行ピンが 5→10 本になり、基板の配線が大きく変わってしまうため。

### その他のピン

```
QMK_ESC_OUTPUT   C7      (col[0])
QMK_ESC_INPUT    D2      (row[0])
DEBOUNCE         5
RGB_DI_PIN       F7      RGBLED_NUM 1
ENCODERS_PAD_A   { D0 }
ENCODERS_PAD_B   { D1 }
ENCODER_RESOLUTIONS { 4 }
```

### 物理配置 ↔ マトリクス対応

`Krc` の `r` = 論理行 (0-9)、`c` = 列 (0-5)。

```
行1:  K00  K10  K01  K11  K31  K02  K12  K32  K03  K13  K04  K14  K34  K05  K15
行2:  K20  K30  K21  K41  K51  K22  K52  K63  K23  K33  K24  K54  K25       K35
行3:  K40       K50  K61  K71  K42  K62  K72  K43  K53  K64  K74  K65  K45
行4:  K60  K80  K90       K81            K92       K83  K93  K84  K94  K85  K95
```

マトリクス配列（未使用は `KC_NO`）:

```
COL2ROW:
  row0 { K00, K01, K02, K03,  K04,  K05 }
  row1 { K20, K21, K22, K23,  K24,  K25 }
  row2 { K40, K41, K42, K43,  --,   K45 }
  row3 { K60, K61, K62, K63,  K64,  K65 }
  row4 { K80, K81, --,  K83,  K84,  K85 }
ROW2COL:
  row5 { K10, K11, K12, K13,  K14,  K15 }
  row6 { K30, K31, K32, K33,  K34,  K35 }
  row7 { K50, K51, K52, K53,  K54,  --  }
  row8 { --,  K71, K72, --,   K74,  --  }
  row9 { K90, --,  K92, K93,  K94,  K95 }
```

### RP2040 版への移植メモ

* duplex は維持 → `CUSTOM_MATRIX = lite` で `matrix_init_custom()` / `matrix_scan_custom()` を自前実装する。
  これにより `quantum/matrix.c` へのコアパッチが不要になり、**フォークではなく素の QMK + 自分の keyboards/ で済む**。
* `key_duration.c` は AVR の TIMER1 直叩き（`TCCR1A/B`, `OCR1A`, `ISR(TIMER1_COMPA_vect)`）。
  RP2040 には TIMER1 が無いので **QMK の `defer_exec()` / `extend_deferred_exec()` に置き換え必須**。
  ついでに `BACKLIGHT_ENABLE = no` / `SLEEP_LED_ENABLE = no` の制約が外れる。

---

## 2. TS69 シリーズ — V3 は 🟢 移植 / V1・V2 は 🟡 資料化

65% (69キー) 分割スペースバー。見た目 5 行 16 列。ファームは `users/nicola`（旧世代）。

### TS69 V1 (thumbshift69)

* 通常マトリクス（COL2ROW）。電気的に 9 行 8 列。
* MCU: ATmega32U4 / 5V 16MHz Pro Micro / `qmk-dfu`

```
MATRIX_ROWS 9    MATRIX_COLS 8
DIODE_DIRECTION COL2ROW
MATRIX_ROW_PINS { D1, D2, B6, B2, B3, B1, F7, F6, F5 }
MATRIX_COL_PINS { F4, D0, D4, C6, D7, E6, B4, B5 }
QMK_ESC_OUTPUT F4   QMK_ESC_INPUT D1
RGB なし
```

### TS69 V2

* 通常マトリクス（COL2ROW）。電気的に 10 行 8 列。
* ハードウェア: https://github.com/sadaoikebe/ts69v2

```
MATRIX_ROWS 10   MATRIX_COLS 8
DIODE_DIRECTION COL2ROW
MATRIX_ROW_PINS { C7, C6, B7, B0, D4, D6, B4, D7, F6, F7 }
MATRIX_COL_PINS { F5, B5, B6, D5, D3, D2, D1, D0 }
RGB_DI_PIN F4    RGBLED_NUM 8
QMK_ESC_OUTPUT F4   QMK_ESC_INPUT D1
```

> ⚠️ `QMK_ESC_OUTPUT F4` は V1 からのコピーのまま。V2 の COL に `F4` は無く、`F4` は RGB_DI に使われている。
> 再構築時は Esc の実際の交点を測って設定し直すこと（V1 の値が残っているだけの可能性が高い）。

### TS69 V3 — 🟢 移植 / **duplex matrix**

**69系で一番使っているキーボード。** TS52K と同じく `CUSTOM_MATRIX = lite` で duplex を自前実装して移植する。

* ハードウェア: https://github.com/sadaoikebe/ts69v3
* duplex の解説 PR: https://github.com/qmk/qmk_firmware/pull/8160

```
MATRIX_ROWS 10   MATRIX_COLS 8      ← 論理 10×8 = 80 ポジション
DIODE_DIRECTION BOTHWAYS
MATRIX_ROW_PINS { B5, D2, F7, F6, F5 }               ← 実ピン 5 本
MATRIX_COL_PINS { F4, D1, D0, D4, C6, D7, E6, B4 }   ← 実ピン 8 本
RGB_DI_PIN B6    RGBLED_NUM 11
QMK_ESC_OUTPUT F4   QMK_ESC_INPUT B5
```

**実配線 13 ピンで 69 キー。** 論理行 `0..4` が COL2ROW、`5..9` が ROW2COL。

物理配置 ↔ マトリクス（`Krc`, r = 論理行 0-9, c = 列 0-7）:

```
行1:  K00 K10 K01 K11 K02 K12 K03 K13 K04 K14 K05 K15 K06 K16 K07 K17
行2:  K20 K30 K21 K31 K22 K32 K23 K33 K24 K34 K25 K35 K26     K27 K37
行3:  K40 K50 K41 K51 K42 K52 K43 K53 K44 K54 K45 K46     K56 K47 K57
行4:  K60     K61 K71 K62 K72 K63 K73 K64 K74 K65 K75 K66 K76 K67 K77
行5:  K80 K90 K81 K91 K82     K83     K84 K94 K85 K95 K86 K96 K87 K97
```

キーキャップ・レイアウト別の注意（オリジナルのコメントより）:

* `K16` = 2u Backspace
* `K27` = US配列の `|\`（**JP配列には無い**）
* `K56` = JP配列の `]}`（**US配列には無い**）、`K47` = Enter（US/JP共通）
* `K66` = JP配列の `_`（**US配列には無い**）、`K76` = RShift
* `K91` / `K94` = 変換 / 無変換（**2.25u スペースバー時のみ使用可**）
* `K83` = 6.25u スペースバー

KLE (keyboard-layout-editor.com) 用 JSON は `keyboards/ts69/v3/v3.h` 末尾のコメントに保存されている。
再構築時はそこからコピーすると物理配置がすぐ再現できる。

---

## 3. Just68 — 🟡 資料化

* 中国製 PCB（製造: Yang）。https://item.taobao.com/item.htm?id=604019589546
* 出荷時は TMK。QMK 化には **ISP でブートローダを書く必要がある**。
* MCU: ATmega32U4 / **F_CPU = 8 MHz**（3.3V 品。他機と違うので注意） / `qmk-dfu`

```
MATRIX_ROWS 6    MATRIX_COLS 13
DIODE_DIRECTION COL2ROW
MATRIX_ROW_PINS { B5, B4, B3, B2, B1, B0 }
MATRIX_COL_PINS { D7, D6, E2, C7, D0, B7, F7, F6, F5, F4, F1, F0, E6 }
```

見た目は 5 行 15 列だが電気的には 6 行 13 列。**右端のキー群が 6 行目に配線されている。**

```
行1:  K00 K01 K02 K03 K04 K05 K06 K07 K08 K09 K0A K0B K0C  K5B K5A K58
行2:  K10 K11 K12 K13 K14 K15 K16 K17 K18 K19 K1A K1B K1C      K2C K59
行3:  K20 K21 K22 K23 K24 K25 K26 K27 K28 K29 K2A K2B          K5C K57
行4:  K30 K32 K33 K34 K35 K36 K37 K38 K39 K3A K3B     K3C      K55 K53
行5:  K40 K41 K42     K44 K48                 K4A K4B K4C K56  K54 K52
```

### ISP パッド

ATMega32U4 チップのすぐ隣に 6 パッド。スイッチ実装後もアクセス可能。
**左から順に `VCC` `SCLK` `MOSI` `MISO` `RESET` `GND`**（`GND` が角型パッド）。

Pro Micro をライタにする場合の結線（`keyboards/just68/isp-flashing-promicro-conneciton.svg` に図あり）:

| Just68 側 | Pro Micro 側 |
|---|---|
| VCC (左端) | VCC |
| SCLK | 15 |
| MOSI | 16 |
| MISO | 14 |
| RESET | 10 |
| GND (右端) | GND |

> GND パッドは熱容量が大きくはんだ付けしにくい。ワット数の大きいこてを使うこと。

fuse: `H=0xd9` `L=0x5e` `E=0xc6`
（PCB にリセットボタンが無いので、ブートローダに戻れるよう bootmagic を有効にしておくとよい）

---

## 4. handwired/shobon62 — 🟡 資料化

手配線 62 キー、分割スペースバー。LAYOUT は XD60 由来。

```
MCU: ATmega32U4 / qmk-dfu
MATRIX_ROWS 5    MATRIX_COLS 14
DIODE_DIRECTION COL2ROW
MATRIX_ROW_PINS { D0, D1, D2, D3, F4 }
MATRIX_COL_PINS { B0, B2, E6, F7, C6, B6, D4, B1, F6, B5, B4, D7, F5, B3 }
BACKLIGHT_PIN F0
RGB_DI_PIN F6   RGBLED_NUM 12
```

> ⚠️ `RGB_DI_PIN F6` は `MATRIX_COL_PINS` の 9 番目 (`F6`) と衝突している。
> RGBLIGHT は rules.mk で無効なので実害は出ていないが、実機に LED が付いているかは要確認。
> 手配線なので、再構築時は実機のピンを当たり直すのが確実。

```
行1:  K00 K01 K02 K03 K04 K05 K06 K07 K08 K09 K0A K0B K0C K0D
行2:  K10 K11 K12 K13 K14 K15 K16 K17 K18 K19 K1A K1B K1C K1D
行3:  K20 K21 K22 K23 K24 K25 K26 K27 K28 K29 K2A K2B     K2D
行4:  K30     K32 K33 K34 K35 K36 K37 K38 K39 K3A K3B     K3D
行5:  K40 K41 K42         K45 K46             K4A K4B K4C K4D
```

---

## 5. handwired/ajazz82 — 完全廃棄

Ajazz の筐体を流用した手配線 82 キー。**廃棄決定につき回路情報も残さない。**

必要になった場合は git 履歴から復元できる: `git show e3d92a7463:keyboards/handwired/ajazz82/config.h`

---

## 6. 3×3 マクロパッド — 🟡 資料化（外形共通・中身は3種）

**外形が同じ 3×3 のマクロパッドが 3 種類**あり、今後も中身を差し替えて使う想定。
再構築コストが一番低いグループ（最新 QMK なら `keyboard.json` 20 行 + keymap 13 行）。

### 6-1. winry/3x3（自作定義）

```
MCU: ATmega32U4 / qmk-dfu
MATRIX_ROWS 1    MATRIX_COLS 9      ← 3×3 ではなく 1 行 9 列
DIODE_DIRECTION COL2ROW
MATRIX_ROW_PINS { F1 }
MATRIX_COL_PINS { B1, B2, D2, F4, B3, D3, E6, B4, D7 }
RGB_DI_PIN F7    RGBLED_NUM 8
```

物理配置 → マトリクス（1 行 9 列に左上から順に並ぶ）:

```
K00 K01 K02        row0 = { K00, K01, K02, K03, K04, K05, K06, K07, K08 }
K03 K04 K05
K06 K07 K08
```

> 最新 upstream QMK に `winry/3x3` が入っているかは要確認。あれば keymap だけ置けば済む。

### 6-2. ymdk/ymd09

**upstream のキーボード**。自作分は keymap (`devenv`) のみ。移植不要、keymap を 1 個置くだけ。

### 6-3. ec3x3（自作・静電容量）— ⚪ 資料のみ・復活予定なし

3×3 の**静電容量無接点**マクロパッド。`CUSTOM_MATRIX` (413行)。keymap は `KC_A`〜`KC_I` のまま。

> **完全なプロトタイプであり、復活させる予定はない。**
> 以下は「AVR で静電容量をやるとどういう構成になるか」の記録としてのみ残す。
> 実用する静電容量キーボードは TC69（RP2040版・第9節）のほうを参照すること。

```
MCU: ATmega32U4 / bootloader caterina (Pro Micro)
MATRIX_ROWS 3    MATRIX_COLS 3
MATRIX_ROW_PINS { D4, C6, D7 }
MATRIX_COL_PINS { E6, B4, B5 }
CHARGE_PIN B2       ← 充電パルス出力
ADC_PIN    B6       ← 静電容量センス (ADC入力)
```

センシングのパラメータ:

```
サンプリング周波数   150 Hz
デジタル LPF        1 次 IIR, カットオフ 1 Hz, Q = 1/√2
押下しきい値        90     (DEFAULT_THRESHOLD_DOWN)
離しきい値          25     (DEFAULT_THRESHOLD_UP)   ← ヒステリシス
キャリブレーション   起動時 20 サンプル / 以後 10 秒ごと / バッファ 5
```

TC69 との違い: ec3x3 は **1次IIRローパスフィルタ + 定期再キャリブレーション**という重い処理を
毎スキャン走らせている（`float` 演算を AVR でやっている）。TC69 では単純な移動加算 +
非対称しきい値だけに簡略化されており、そちらのほうが実用的だった。

### keymap（3 種共通で使っていた内容）

`winry/3x3` と `ymdk/ymd09` の `devenv` keymap は**完全に同一**。

```
devenv (Visual Studio):     kicad:
  S(F11)  F10     F11         Esc      X        Del
  F9      C(F10)  F5          LGUI     R        M
  MO(1)   ---     S(F5)       MO(1)    LSA(Z)   A(Z)

Layer 1 (両方共通・RGB調整):
  RGB_RMOD  RGB_VAI  RGB_MOD
  RGB_HUI   RGB_HUD  RGB_SAI
  ---       RGB_VAD  RGB_SAD
```

> ⚠️ 最新 QMK では underglow のキーコードが改名されている
> (`RGB_MOD`→`UG_NEXT`, `RGB_RMOD`→`UG_PREV`, `RGB_HUI`→`UG_HUEU`, `RGB_VAI`→`UG_VALU`, `RGB_SAI`→`UG_SATU` …)。
> 再構築時は機械的に置換すること。

---

## 7. cxt/12e4 — ⚪ ピン配置のみ（使用終了）

4×4 = 12 キー + **ロータリーエンコーダ 4 個**のマクロパッド。復活予定なし。ピン配置のみ記録。

```
MCU: ATmega32U4 / qmk-dfu
MATRIX_ROWS 4    MATRIX_COLS 4
DIODE_DIRECTION ROW2COL          ← 他機と逆なので注意
MATRIX_ROW_PINS { C7, C6, D6, F4 }
MATRIX_COL_PINS { D4, D7, B4, B5 }
RGB_DI_PIN F7    RGBLED_NUM 12
ENCODERS_PAD_A { D3, B3, F0, F6 }
ENCODERS_PAD_B { D5, B2, E6, F5 }
```

エンコーダ 4 個の結線（A/B ペア）: `D3/D5`, `B3/B2`, `F0/E6`, `F6/F5`
LAYOUT は 4 行 4 列そのまま（`K00`〜`K33`）。

---

## 8. TC69 — ⚪ 資料化（アルゴリズムのスタブ付き / ブランチ `capacitive`）

RP2040 + **静電容量無接点**。`master` とは合流していない別系統で、
**このリポジトリで唯一 2023-04 の新しい QMK ベース**。

> 静電容量は回路さえ分かればアルゴリズムから再構築できるタイプなので、
> **ピン配置に加えて中核アルゴリズムを実コードのまま**下に残す。
> これがあれば後から復活させられる。

```
MCU: RP2040 / bootloader rp2040
CUSTOM_MATRIX = yes    (SRC += matrix.c, analog.c)

CAP_ROW_PINS { GP2, GP4, GP1, GP0, GP7 }       ← 5 行を順に駆動
CAP_COL_PINS { GP3, GP6, GP27, GP26 }          ← 4bit をデコードして 16 列を選択
CAP_PURGE     GP28                             ← 電荷抜き
CAP_SENSE     GP29                             ← ADC 入力 (analogReadPin)
```

### 検出方式 — デバウンスをアナログ・ヒステリシスに置換

`matrix_scan()` に **`debounce()` の呼び出しが一切無い**のが特徴。代わりに:

1. ADC 値を 3 サンプルのリングバッファに貯めて**加算**（`ADC_RING_BUFFER_SIZE 3`）
2. 起動時に**キーごとにキャリブレーション値** `calibration_val[col][row]` を取得
3. 押下・解放で**非対称のしきい値**を使う:
   ```
   加算値 > cal + press_threshold    → 押下  (adc_press_threshold   = 150 × 3)
   加算値 < cal + release_threshold  → 解放  (adc_release_threshold =  30 × 3)
   ```
   この差がそのままヒステリシス幅になり、チャタリングが原理的に発生しない。
4. **ホームポジションのキーだけ別のしきい値**を使う（`is_home_position()` で判定、
   `adc_press_threshold_2` / `adc_release_threshold_2`）。指を置きっぱなしにするキーの誤爆対策。

### 復活用スタブ: ADC 取得

列は 4 本のピンに 2 進で値を出して 16 列をデコードする。行は 5 本を順に駆動。
1 キーごとに「行を H → ADC 読み → 行を L → PURGE で電荷を抜く」を繰り返す。

```c
void acquire_adc(int adc_measured_val[][5]) {
  for (int j = 0; j < 16; ++j) {
    writePin(CAP_COL_PINS[0], (j & 1) ? true : false);
    writePin(CAP_COL_PINS[1], (j & 2) ? true : false);
    writePin(CAP_COL_PINS[2], (j & 4) ? true : false);
    writePin(CAP_COL_PINS[3], (j & 8) ? true : false);
    for (int i = 0; i < 5; ++i) {
      writePinHigh(CAP_ROW_PINS[i]);
      adc_measured_val[j][i] = analogReadPin(CAP_SENSE);
      writePinLow(CAP_ROW_PINS[i]);
      setPinOutput(CAP_PURGE);
      writePinLow(CAP_PURGE);
      /* ... PURGE を戻す ... */
    }
  }
}
```

ピン初期化（`matrix_init`）: `CAP_ROW_PINS` と `CAP_COL_PINS` を全て `setPinOutput`、
`CAP_PURGE` と `CAP_SENSE` を `setPinInput`。

### 復活用スタブ: キャリブレーション

起動時に「捨て読み `ADC_RING_BUFFER_SIZE` 回 → 本読み `ADC_RING_BUFFER_SIZE` 回を加算」して
キーごとの基準値を作る。**TC69 は起動時のみで、以後の再キャリブレーションはしない**（ec3x3 との違い）。

```c
for (int i = 0; i < ADC_RING_BUFFER_SIZE; ++i) acquire_adc(adc_measured_val);   // 捨て読み
for (int i = 0; i < ADC_RING_BUFFER_SIZE; ++i) {
    acquire_adc(adc_measured_val);
    for (int j = 0; j < 16; ++j)
      for (int k = 0; k < 5; ++k)
        calibration_val[j][k] += adc_measured_val[j][k];
}
```

### 復活用スタブ: ヒステリシス判定（デバウンスの代替）

**ここが本質。** `debounce()` を一切呼ばず、押下・解放で非対称のしきい値を使う。

```c
uint8_t matrix_scan(void) {
    matrix_row_t curr_matrix[5] = {0, 0, 0, 0, 0};
    acquire_adc(adc_ring_buffer[adc_ring_index]);
    adc_ring_index = (adc_ring_index + 1) % ADC_RING_BUFFER_SIZE;

    for (int i = 0; i < MATRIX_COLS; ++i) {
      for (int j = 0; j < MATRIX_ROWS; ++j) {
        int adc_total = 0;
        for (int k = 0; k < ADC_RING_BUFFER_SIZE; ++k)
            adc_total += adc_ring_buffer[k][i][j];      // 移動加算 = 簡易ローパス

        bool home = is_home_position(i, j);
        int press   = home ? adc_press_threshold_2   : adc_press_threshold;
        int release = home ? adc_release_threshold_2 : adc_release_threshold;

        if      (adc_total > calibration_val[i][j] + press)   curr_matrix[j] |=  (1 << i);
        else if (adc_total < calibration_val[i][j] + release) curr_matrix[j] &= ~(1 << i);
        // どちらでもない = 前の状態を維持 ← これがヒステリシス
      }
    }

    bool changed = memcmp(matrix, curr_matrix, sizeof(curr_matrix)) != 0;
    if (changed) memcpy(matrix, curr_matrix, sizeof(curr_matrix));
    matrix_scan_kb();
    return changed;
}
```

`press` と `release` の差（150×3 と 30×3 → 差 360）がそのままヒステリシス幅になる。
どちらのしきい値にも達しない範囲では前の状態を保持するため、**チャタリングが原理的に発生しない**。
だからデバウンス処理そのものが不要になっている。

再構築時の調整ポイントはこの 2 つのしきい値と `ADC_RING_BUFFER_SIZE`（大きいほど鈍いが安定）。

---

## 9. upstream キーボード + 自作 keymap のみ

キーボード定義は upstream にあるので**移植不要**。`users/nicola` さえ移植すれば keymap を置くだけで復活する。

| キーボード | keymap | 備考 |
|---|---|---|
| `just60` | `nicola` | |
| `xiudi/xd60` | `nicola` | |
| `ai03/voyager60_alps` | `nicola` | 中身は xd60 と同一（実質コピー） |
| `xd64` | `nicola` | README 1 行のみ。実体なし |
| `ymdk/ymd09` | `devenv` | 上記 6-2 |

---

## 共通: ISP / fuse

リセットボタンの無い基板や、`qmk-dfu` ブートローダを新規に書く場合は ISP が必要。

### Pro Micro をライタにする場合

```
make <keyboard>:<keymap>:production
avrdude -p m32u4 -P COM4 -c avrisp -U flash:w:<...>_production.hex:i
avrdude -p m32u4 -P COM4 -c avrisp -U hfuse:w:0xd9:m
```

### 汎用 ISP プログラマ (stk500v1) の場合

```
avrdude -p m32u4 -c stk500v1 -P COM4 -b 19200 -U flash:w:<...>_production.hex:i
avrdude -p m32u4 -c stk500v1 -P COM4 -b 19200 -U hfuse:w:0xd9:m
```

### fuse 値

| 機種 | LOW | HIGH | EXT | 備考 |
|---|---|---|---|---|
| TS52K / TS69 V2,V3 | `0xff` | `0xd9` | `0xcb` | 5V 16MHz 外部クロック |
| Just68 / shobon62 / ajazz82 | `0x5e` | `0xd9` | `0xc6` | Just68 は 8MHz |

* `qmk-dfu` を使う場合、**BOOTRST は unprogrammed（アプリケーションから起動）にすること。**
* fuse 計算機: http://eleccelerator.com/fusecalc/fusecalc.php?chip=atmega32u4

### リポジトリ内の ISP 関連ツール

```
util/pro_micro_ISP_B6_10.hex     Pro Micro を ISP ライタにするファーム
util/teensy_2.0_ISP_B0.hex       Teensy 2.0 を ISP ライタにするファーム
```

---

## 付録: NICOLA 親指シフト実装の系譜

キーボードではないが、移植時に必要な設計情報として記録。

**方針: `nicola4r`（ts52k版）に一本化する。** 詳細は「統合方針」節を参照。

| | 場所 | 状態機械 | 使用 |
|---|---|---|---|
| 旧世代 | `users/nicola/` (nicola.c 516行 + jtu.c 343行) | **5 状態** | just60, just68, ts69, xd60, shobon62, tc69 |
| 現行 | `keyboards/ts52k/keymaps/nicola4r/` (nicola.c 1091行) | **6 状態** | ts52k |
| `nishimaki` 枝 | 同上 | **5 状態に戻した** | ts52k（他人用の改造） |

### 状態機械

```
S1_INIT  初期状態
S2_M     文字キー(M)のみ押下中
S3_O     親指キー(O)のみ押下中
S4_MO    M → O の順で押下
S5_OM    O → M の順で押下
S6_OO    親指キー2つ同時打鍵          ← 2026-01-20 追加 / 2026-02-15 に nishimaki で削除
```

`S6_OO` は「左親指→右親指でかなON、右親指→左親指でかなOFF」を実現するために追加したもの。
3 キーが絡んだときに `t1 = O2→O の間隔` と `t2 = O→現在キー の間隔` を比較して、
中間の親指キーを前のキーと結合するか次のキーと結合するかを決めるロジックを持つ。

**結論: 5 状態版を最終採用とする。** `S6_OO` は作ってみたが実際にはあまり使わなかったため。
（`nishimaki` で削除されたからではなく、機能として不要という判断。5 状態版のほうが歴史が長く枯れている。）
かなON/OFF は親指同時打鍵ではなく専用キーに割り当てる。

### AVR 依存部（移植時に書き直しが必要）

`key_duration.c` — NICOLA の同時打鍵判定タイムアウトに **AVR の 16bit TIMER1** を直接使用。

```c
TCCR1B = (1<<CS12)|(1<<CS10);   // clock/1024
OCR1A  = count;                  // タイムアウト値
TIMSK1 = 2;                      // compare match A 割り込み有効
ISR(TIMER1_COMPA_vect) { callback(); }
```

TIMER1 を占有するため `BACKLIGHT_ENABLE = no` / `SLEEP_LED_ENABLE = no` が必須になっている。
**QMK の `defer_exec()` / `extend_deferred_exec()` に置き換えれば MCU 非依存になり、この制約も消える。**

### 統合方針: `nicola4r` に一本化する

2 実装に分かれているが、**違いはアーキテクチャではなくキーコード表だけ**。`nicola4r` が上位互換なので
そちらに寄せる。

| | `users/nicola` (ts69系) | `nicola4r` (ts52k) |
|---|---|---|
| かな | `NG_Q`〜`NG_SLSH` + **`NG_1`〜`NG_0`, `NG_MINS`, `NG_EQL`（数字行）** | `NG_Q`〜`NG_SLSH`（数字行なし） |
| 英数 | **なし**（素の `KC_*`） | `NG_E_*`（英数にも親指シフトが効く） |
| カーソル | なし | `NG_LEFT` / `NG_DOWN` / `NG_UP` / `NG_RIGHT` |
| 出力 | `send_string()` | `register_code()`（2026-01 に改善済） |
| JIS変換 | `jtu.c` 343行 | なし |

一本化できる根拠:

1. **「英数では NICOLA を通さない」は keymap 側 1 行で表現できる。**
   ゲートは `nicola.c` ではなく keymap の `process_record_user()` にある。
   TS69 は `if (nicola_state()) { … }` で囲っているため、英数モードでは
   `process_nicola()` が一度も呼ばれない。`nicola.c` は共通のまま両方の挙動が出せる。

2. **`nicola4r` は非NICOLAキーを既に処理できる。**
   `process_nicola()` に「その他のキー」分岐があり、状態機械が動作中なら
   pending バッファ（最大 8）に積んで追い越しを防ぐ。
   → TS69 の英数レイヤーは素の `KC_*` のままで共存できる（そもそも状態が `S1_INIT` から動かない）。

3. **かなの割当は両者完全に一致。**
   `NG_Q`=`.`、`NG_W`=`ka`、`NG_E`=`ta`、`NG_R`=`ko`、`NG_T`=`sa`、
   `NG_A`=`u`、`NG_S`=`si`、`NG_D`=`te`、`NG_F`=`ke`、`NG_G`=`se` … 標準NICOLAなので当然だが確認済み。

4. **`jtu.c`（JIS/US変換）は捨てて良い。**
   TS69 の keymap で既に `// bool continue_process = process_jtu(keycode, record);` と
   コメントアウトされている。2021-04 の
   `fb60a5f035 "removed jis to ansi conversion as kbd101 layer driver recognizes ime on/off"`
   の判断が生きている。343 行まるごと削減できる。

5. **`NG_1`〜`NG_0` は新方式に全面乗り換え。**
   数字・記号は親指同側シフトで 2 行目から、`Shift+数字` はクロスシフトで出す。
   TS69 の `_QWERTY` レイヤーの数字行は**既に素の `KC_1`〜`KC_0`** なので、移行作業は発生しない。
   `send_string` → `register_code` の変換も `SS_ALNUM()` の再現も不要になる。

**→ 統合に伴う実作業はゼロ。** `nicola4r` を採用し、`users/nicola`（`jtu.c` 含む）を削除するだけ。

詳細な挙動仕様は **[`NICOLA-SPEC.md`](NICOLA-SPEC.md)** を参照。
状態遷移表・ゲートの仕組み・追い越し防止・小指シフト反転を全て書き出してある。
