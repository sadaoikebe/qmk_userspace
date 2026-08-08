# qmk_userspace — sadaoikebe

無改造の [QMK Firmware](https://github.com/qmk/qmk_firmware) に対する
**External Userspace**。自作キーボードと NICOLA 親指シフト実装だけを置く。

2022-01 ベースの古いフォーク（`qmk_firmware_oldfork`）を捨て、
2026-08 に QMK 0.33.13 上で作り直したもの。

## なぜフォークではないのか

古いフォークが upstream を改造していた理由は `quantum/matrix.c` の
duplex matrix パッチ 1 点だけだった。これを `CUSTOM_MATRIX = lite` で
キーボード側に実装することでコアへの差分がゼロになり、フォークが不要になった。

QMK 本体は `git pull` するだけで追従でき、マージ競合が原理的に発生しない。

## 使い方

```bash
qmk config user.overlay_dir=~/qmk_userspace
qmk userspace-doctor            # 疎通確認
qmk userspace-compile           # build_targets を全部ビルド
qmk compile -kb ts52k -km nicola4r
```

## ドキュメント

| | |
|---|---|
| [`docs/HARDWARE-REFERENCE.md`](docs/HARDWARE-REFERENCE.md) | 全キーボードの回路情報。ピン配置・LAYOUT・fuse・ISP手順・duplex matrix 配線 |
| [`docs/NICOLA-SPEC.md`](docs/NICOLA-SPEC.md) | 親指シフト実装の挙動仕様。設計原則・状態遷移表・書き直し指針 |

旧フォークの git 履歴は `qmk_firmware_oldfork` および
`github.com/sadaoikebe/qmk_firmware` ブランチ `docs/hardware-reference` に保存されている。
廃棄したキーボード定義（ajazz82 等）が必要になった場合はそこから復元する。
