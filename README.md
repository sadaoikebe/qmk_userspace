# qmk_userspace — sadaoikebe

無改造の [QMK Firmware](https://github.com/qmk/qmk_firmware) に対する
**External Userspace**。keymap と NICOLA 親指シフト実装を置く。

2022-01 ベースの古いフォーク（`qmk_firmware_oldfork`）を捨て、
2026-08 に QMK 0.33.13 上で作り直したもの。

## コアへの差分はゼロになった

古いフォークが upstream を改造していた理由は `quantum/matrix.c` の
duplex matrix パッチ 1 点だけだった。これを `CUSTOM_MATRIX = lite` で
キーボード側に実装することで、**QMK コアへの差分はゼロになった**。

## ただし External Userspace にキーボード定義は置けない

**要注意（一度誤解した点）:** External Userspace が外に置けるのは
`keyboards/<kb>/keymaps/<km>/`、`layouts/`、`users/` **だけ**で、
**キーボード定義そのもの（`keyboard.json` / `matrix.c` / `rules.mk`）は置けない。**

根拠:

- `build_keyboard.mk` が `KEYBOARD_PATH_1 := keyboards/$(...)` の形で
  5 段階すべてハードコードしており、上書きする変数がない
- Python 側も `base_path = os.path.join(os.getcwd(), "keyboards")` 固定
- `docs/newbs_external_userspace.md` も keymap / layouts / users しか挙げていない

コミュニティの実例（HolyKeebs、BastardKB、SplitKB など）も、
キーボード定義については **QMK の軽量フォークに `keyboards/` を足す**形を取っている。

したがって ts52k 等の定義の置き場所は別途決める必要がある。**未決**。

- 案A: `sadaoikebe/qmk_firmware`（upstream 追従の軽量フォーク）に `keyboards/` だけ足す
- 案B: 手元の `~/qmk_firmware` の作業ツリーに置き、定義だけ別途バージョン管理する

いずれにせよコアへの差分はゼロなので、`git merge upstream/master` で
競合なく追従できる。旧フォークのようなマージ地獄にはならない。

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
| [`docs/ARCHIVE-RUNBOOK.md`](docs/ARCHIVE-RUNBOOK.md) | 旧フォークを退避して GitHub リポジトリを整理した手順と実施記録 |

## 旧フォークの履歴

2026-08-10 に退避完了。`github.com/sadaoikebe/qmk_firmware` の `master` は
upstream と一致する状態に戻され、旧ブランチは削除された。

| 保存先 | 内容 |
|---|---|
| Release [`archive/oldfork-final`](https://github.com/sadaoikebe/qmk_firmware/releases/tag/archive/oldfork-final) | `qmk-oldfork.bundle` (257MB)。**全87ブランチ + 854タグ**。旧フォークの完全な記録 |
| タグ `archive/oldfork-final` | 旧 master 先端 `e3d92a7463`。GitHub 上でそのままファイルを閲覧できる |
| `C:\Users\marur\qmk-archive\` | 同じ bundle のローカル控え |

廃棄したキーボード定義（ajazz82 等）が必要になったら:

```sh
gh release download archive/oldfork-final -R sadaoikebe/qmk_firmware
sha256sum -c qmk-oldfork.bundle.sha256
git clone qmk-oldfork.bundle restored
```

**アンカーコミット `e3d92a7463` の祖先でないブランチ**
（`nishimaki` `capacitive` `tc69` `rp2040` `blehack` `bluefruit_uart` `qmk-master`）
は bundle にしか存在しない。タグを辿っても出てこないので注意。
