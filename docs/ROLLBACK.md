# TS52K 切り戻し手順 / 既知の動作品ファームウェア

**困ったときに最初に開く文書。** TS52K が動かなくなったとき、既知の動作品に戻すための手順。

関連: [`HARDWARE-REFERENCE.md`](HARDWARE-REFERENCE.md)（ピン配置・ISP / fuse）、
[`WIRELESS-PLAN.md`](WIRELESS-PLAN.md)（無線版の計画。§8 撤退ライン）

---

## hex ファイルの置き場所

**`C:\Users\marur\qmk-archive\known-good\`**（ローカル。**git 管理外**）

| ファイル | 用途 |
|---|---|
| `ts52k_nicola.hex` | **新 QMK 版・現行**。NICOLA 親指シフト。移植完了版 |
| `ts52k_nicola4r.hex` | 旧フォーク版。**移植前に戻したいときの復帰ポイント** |
| `ts52k_default.hex` | 新 QMK 版・NICOLA なしの素 QWERTY。**マトリクス切り分け用の診断ツール** |

いずれも 2026-08-11 に実機へ書き込み、動作を確認済み（ベリファイ通過、往復で切り戻しも成功）。

> **バイナリはリポジトリに入れない**（`.gitignore` で `*.hex` を除外している）。
> だから**この文書に SHA256 と再生成手順を全部書いてある**。
> hex を失っても、再取得・再ビルドしたものがこの表の SHA256 と一致すれば同じものだと確認できる。

---

## 切り戻し手順

1. 基板上のリセットスイッチ **`SW1`** を押してブートローダに入る
2. `qmk flash`（または `dfu-programmer` 直叩き）で `ts52k_nicola4r.hex` を書き込む
3. 元の NICOLA 環境に戻る

**書き込みは QMK MSYS 同梱の `dfu-programmer` で通る。QMK Toolbox もドライバ導入も不要**
（2026-08-11 に実機で確認済み）。Administrator 権限も要らなかった。

### ブートローダへの入り方

**優先すべきはハードウェアリセット。基板上にリセットスイッチ `SW1` がある**
（回路図で `Switch:SW_SPST` / フットプリント `Button_Switch_SMD:SW_SPST_TL3342`、
グローバルラベル `RESET` に接続）。これを押せばブートローダに入る。

**マトリクスの実装を試している最中は、これが唯一信頼できる経路。**
`keyboard.json` の bootmagic (`matrix: [0,0]` = 電源投入時に左上キーを押しっぱなし) は
マトリクススキャンが正しく動くことを前提にしているので、
まさに検証中の `matrix.c` が壊れていたら効かない。
キーマップ側の `QK_BOOT` も同じ理由で当てにしない。

最後の手段として **ISP ヘッダ `J2`（6ピン）** がある。fuse ごと書き直せる
（手順は [`HARDWARE-REFERENCE.md`](HARDWARE-REFERENCE.md)「共通: ISP / fuse」）。

---

## 3 本の素性

### ts52k_nicola.hex — 現行

最新 QMK 上で状態機械を書き直し、`key_duration.c` の AVR TIMER1 直叩きを
`defer_exec()` に置き換えた版。状態機械は `users/nicola/`。

| | |
|---|---|
| ビルド元 | `sadaoikebe/qmk_firmware` `sadao-master` @ `e3ef3b895d` + この userspace の `users/nicola` |
| サイズ | 18,226 / 28,672 bytes (63%)。旧版 20,352 bytes より小さい |
| SHA256 | `75251d3aa0269a6eb1d872cb4bf43ca8c6af63083a4bd41f0534d0a75e757fb8` |
| 検証 | 単独打鍵・同時打鍵・押しっぱなしリピート・ロールオーバー・追い越し・小指シフト併用・英数の数字/記号・モディファイア・タイムアウト、および全キー打鍵 |

### ts52k_nicola4r.hex — 移植前への復帰ポイント

旧フォークで実際に運用していた TS52K の NICOLA 親指シフト版。

| | |
|---|---|
| 取得元 | タグ `archive/oldfork-final` (`e3d92a7463`) のリポジトリルート |
| 最後に更新したコミット | `5d7f8d5d53` (2026-02-12) "esc outside Fn, cursor key bugfix" |
| ファイルサイズ | 57,045 bytes (Intel HEX) |
| 最終データアドレス | `0x4F26` → 約 20.3 KB（`qmk-dfu` のアプリ領域上限 `0x7000` = 28,672 に収まる） |
| SHA256 | `a3ccd74cf4490bb66a1a19e45d8f5da710da5a07288089b07752c1627991f273` |

### ts52k_default.hex — マトリクス切り分け用

最新 QMK (0.33.13) 上で `CUSTOM_MATRIX = lite` により duplex matrix を再実装した版。
NICOLA は載せていない、素の QWERTY。

| | |
|---|---|
| ビルド元 | `sadao-master` @ `e3ef3b895d` + この userspace @ `9fb3b85` |
| サイズ | 14,586 / 28,672 bytes (50%) |
| SHA256 | `bb8294ba6f7a134b5ca0d61e2e9eec50786c497a6225d030125d77ba3df00fec` |
| 検証 | 2026-08-11、実機で 53 キーすべてが正しく認識されることを確認 |

**これを残す理由は切り分け。** NICOLA を載せた後に打鍵がおかしくなったとき、
これを焼けば「マトリクス（ハードウェア・スキャン）の問題」か
「状態機械の問題」かを一発で分離できる。全キーが正しく出るならマトリクスは無実。

**ZMK 版・無線版を作るときにも、同じ役割の基準として使う**
（[`WIRELESS-PLAN.md`](WIRELESS-PLAN.md) Phase A-2）。

---

## hex を失ったときの再生成

### ts52k_nicola4r.hex — bundle から取り直す

旧フォークのファイルなので、**再ビルドではなく再取得**になる。

```sh
git show e3d92a7463:ts52k_nicola4r.hex > ts52k_nicola4r.hex
sha256sum ts52k_nicola4r.hex   # a3ccd74c... と一致すること
```

タグ `archive/oldfork-final` は `sadaoikebe/qmk_firmware` に残っているので、
そこを clone すれば `git show` が通る。fork ごと失った場合は
Release `archive/oldfork-final` の `qmk-oldfork.bundle` から clone する
（手順は [`ARCHIVE-RUNBOOK.md`](ARCHIVE-RUNBOOK.md) Phase 3-3）。

### ts52k_nicola.hex / ts52k_default.hex — 再ビルドする

ソースは両方とも git に残っている。

* キーボード定義: `sadaoikebe/qmk_firmware` の `sadao-master` @ `e3ef3b895d`
* keymap と `users/nicola`: この userspace（`ts52k_nicola.hex` は `a7d528a` 以降、
  `ts52k_default.hex` は `9fb3b85`）

> ⚠️ **再ビルドしたものは SHA256 が一致しない可能性がある。**
> avr-gcc / QMK のバージョンが当時（QMK 0.33.13）と変わればコードも変わる。
> SHA256 が合わなくても異常ではない。**サイズが 28,672 bytes に収まっていることと、
> 実機で上記の検証項目が通ることを基準にする。**

---

## TS52K のハードウェア前提

* **ATmega32U4 直載せの自作基板**（5V 16MHz 外部クロック）/ bootloader `qmk-dfu`
* **Pro Micro は使っていない**
* VID/PID `0xFEED` / `0x1969`
* リセット `SW1` / ISP ヘッダ `J2`（6ピン）
* 詳細は [`HARDWARE-REFERENCE.md`](HARDWARE-REFERENCE.md) §1
