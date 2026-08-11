# 旧フォーク退避 & GitHub リポジトリ整理 手順書

`sadaoikebe/qmk_firmware` を、旧フォークの歴史を失わずにまっさらな状態へ戻すための手順。

> ## ✅ 実施済み — 2026-08-10
>
> Phase 0〜6 すべて完了。結果:
>
> | | |
> |---|---|
> | Release | [`archive/oldfork-final`](https://github.com/sadaoikebe/qmk_firmware/releases/tag/archive/oldfork-final) — bundle 268,758,429 bytes + .sha256 + manifest |
> | bundle SHA256 | `cd590db4f4fc68d017567b4be15c218946b221001729493346b12a83514d3b78` |
> | タグ | `archive/oldfork-final` → tag obj `dd06ad4d` → commit `e3d92a7463` |
> | master | `e3d92a7463` → `9caa5f871d` (upstream 一致) |
> | 削除ブランチ | 85本（87 − master − docs/hardware-reference） |
> | 残ブランチ（当時） | `master`, `docs/hardware-reference` |
> | 検証 | GitHub から再ダウンロード → SHA256 `OK` → clone → 87 branches / 854 tags → 非祖先ブランチの内容読出成功 |
>
> ## ✅ 積み残しも完了 — 2026-08-11
>
> * `qmk_userspace` を `sadaoikebe/qmk_userspace` へ push（`a7d528a`）
> * `docs/hardware-reference` を削除。**削除前に、GitHub にも fork にも頼らず
>   bundle 単独から clone してツリー `05a9e8f5` が一致することを実証**した
> * `C:\Users\marur\qmk_firmware_oldfork` も削除済み
>
> **現在のフォークのブランチは `master`（upstream ミラー）と
> `sadao-master`（= master + `keyboards/ts52k/`、default branch）の 2 本だけ。**
>
> 以降の本文は**当時の手順と判断の記録**である。
> 「まだ push していない」「消してよい」等の記述は実施当時の状況を指す。
>
> 実施中に判明した手順書の誤り（修正済み）:
>
> 1. ブランチ数は 88 ではなく **87**。`git branch -r | wc -l` が `origin/HEAD` の行を数えていた。
>    数えるときは `git ls-remote --heads origin | wc -l` を使う
> 2. `git bundle verify` / `list-heads` は**リポジトリの中でないと動かない**（`-C` で指定するか、
>    先に clone してその中で実行する）
> 3. `gh release create` は `/` を含むタグ名を問題なく扱えた（懸念は杞憂だった）

## 最終形

```
sadaoikebe/qmk_firmware
├── master                          ← upstream (qmk/qmk_firmware) と完全一致
├── tag: archive/oldfork-final      → e3d92a7463 (旧 master 先端)
│    └── Release: qmk-oldfork.bundle (256MB, 全87ブランチ + 854タグ)
└── その他のブランチ: 全削除
```

## 設計の要点

- GitHub Release は git タグに紐づく。そのタグを旧 master 先端 `e3d92a7463` に打つことで、
  「Release の置き場所」と「旧 master 履歴のリポジトリ内到達可能性」を1本のタグで兼ねられる。
- 残る86ブランチは bundle でカバーする。
- **タグを打っても保存されないものがある**: `docs/hardware-reference` (`71bb18a098`) は
  `e3d92a7463` の祖先ではない。bundle にしか入らない。→ Phase 5 で明示的に判断する。

## 前提の実測値 (2026-08-10 時点)

| 項目 | 値 |
|---|---|
| `gh` | 2.97.0 / `sadaoikebe` 認証済 / scope `repo` |
| 旧フォーク | `C:\Users\marur\qmk_firmware_oldfork` |
| origin | `git@github.com:sadaoikebe/qmk_firmware.git` |
| リモートブランチ数 | 87 (`ls-remote --heads` 実測) |
| タグ数 | 854 |
| bundle SHA256 | `cd590db4f4fc68d017567b4be15c218946b221001729493346b12a83514d3b78` |
| `origin/master` | `e3d92a746304ba68d08e56a20b53da5dbc76859c` (2026-02-13) |
| `docs/hardware-reference` | `71bb18a0983a833ac6c607bc06035419fb708291` (2026-08-08) |
| bundle | 268,758,429 bytes |
| 新クローン | `C:\Users\marur\qmk_firmware`、`upstream` = qmk/qmk_firmware |
| upstream master | `0456ffb38e` (2026-08-05) |

## 破壊性の区分

| Phase | 内容 | 破壊性 |
|---|---|---|
| 0 | bundle を恒久パスへ + 検証 | なし |
| 1 | タグ作成・push | 追加のみ |
| 2 | Release 作成・bundle upload | 追加のみ |
| 3 | **検証ゲート** | なし (読み取りのみ) |
| 4 | master を upstream に force-push | **破壊的** |
| 5 | 86ブランチ削除 | **破壊的** |
| 6 | 最終確認・ドキュメント更新 | なし |

**Phase 3 を通過するまで Phase 4 以降には進まないこと。**

---

# Phase 0 — bundle を恒久パスへ退避し、検証する

現在 bundle はセッション用スクラッチパッドにある。これは一時領域なので、
**まずここから出さないと、他の作業より先に消える可能性がある。**

## 0-1. 保存先を作る

```sh
mkdir -p /c/Users/marur/qmk-archive
```

**期待状態:** `C:\Users\marur\qmk-archive\` が存在し、空。

## 0-2. bundle を移動

```sh
mv "/c/Users/marur/AppData/Local/Temp/claude/C--Users-marur/9e80fdcf-2fae-4dad-b1df-fc4c5bfdf6ad/scratchpad/qmk-oldfork.bundle" \
   /c/Users/marur/qmk-archive/qmk-oldfork.bundle
ls -l /c/Users/marur/qmk-archive/
```

**期待状態:** `qmk-oldfork.bundle` が `268758429` bytes。スクラッチパッド側からは消えている。

## 0-3. bundle の完全性を検証

`git bundle verify` は **リポジトリの中でないと動かない**（前提コミットの有無を
そのリポジトリに問い合わせるため）。`-C` で既存リポジトリを指定する。

```sh
git -C /c/Users/marur/qmk_firmware_oldfork bundle verify \
  /c/Users/marur/qmk-archive/qmk-oldfork.bundle
```

**期待出力:** 末尾に

```
The bundle records a complete history.
The bundle uses this hash algorithm: sha1
```

`complete history` の行が出ないなら **先へ進んではいけない**。bundle を作り直す。

## 0-4. SHA256 とマニフェストを記録

```sh
cd /c/Users/marur/qmk-archive
sha256sum qmk-oldfork.bundle | tee qmk-oldfork.bundle.sha256
git -C /c/Users/marur/qmk_firmware_oldfork bundle list-heads \
  /c/Users/marur/qmk-archive/qmk-oldfork.bundle > qmk-oldfork.manifest.txt
echo "total:      $(wc -l < qmk-oldfork.manifest.txt)"
echo "refs/heads: $(grep -c 'refs/heads/' qmk-oldfork.manifest.txt)"
echo "refs/tags:  $(grep -c 'refs/tags/'  qmk-oldfork.manifest.txt)"
grep -v -e 'refs/heads/' -e 'refs/tags/' qmk-oldfork.manifest.txt
```

**期待状態:**

```
total:      944
refs/heads: 87
refs/tags:  854
5204c8b159bed75f6a8d2430aa9cdfa4a77159fc refs/pull/1/head
05fcefd838211455234b3944edc72005a2535473 refs/pull/2/head
e3d92a746304ba68d08e56a20b53da5dbc76859c HEAD
```

`--mirror` クローンから作ったので PR の参照 (`refs/pull/*`) まで入っている。

数が合わなければ止まる。特に `refs/heads/` が 87 を大きく下回るなら、`--mirror` でない
クローンから作った bundle である疑いがある（過去に一度これで失敗している）。

> **ブランチ数の注意:** `git branch -r | wc -l` は `origin/HEAD -> origin/master` の
> 行も数えるので 88 になる。実ブランチ数は 87。数える時は
> `git ls-remote --heads origin | wc -l` を使うこと。

## 0-5. 重要ブランチがマニフェストにあるか目視

```sh
grep -E 'refs/heads/(master|docs/hardware-reference|nishimaki|capacitive|tc69|rp2040|blehack|bluefruit_uart|qmk-master|mechkbs)$' \
  qmk-oldfork.manifest.txt
```

**期待出力:** 10行。特に以下を確認。

```
e3d92a746304ba68d08e56a20b53da5dbc76859c refs/heads/master
71bb18a0983a833ac6c607bc06035419fb708291 refs/heads/docs/hardware-reference
c5f7cf0d26...                            refs/heads/nishimaki
```

---

# Phase 1 — アンカータグを作成して push

## 1-1. リモートの現状を取り込む

```sh
cd /c/Users/marur/qmk_firmware_oldfork
git fetch origin --prune
git rev-parse origin/master
```

**期待出力:** `e3d92a746304ba68d08e56a20b53da5dbc76859c`

**違う値が出たら止まる。** 誰か（＝過去の自分）が push している。
bundle を作り直すところからやり直し。

## 1-2. タグを作る

軽量タグではなく annotated タグにする。作成日時と意図が残る。

```sh
cd /c/Users/marur/qmk_firmware_oldfork
git tag -a archive/oldfork-final e3d92a746304ba68d08e56a20b53da5dbc76859c -F - <<'EOF'
Archive: final state of the old qmk_firmware fork

This tag pins the last commit of the pre-migration fork (master @ 2026-02-13),
kept so the old history stays reachable inside the repository after master is
reset to upstream.

The full fork -- all 87 branches and 854 tags, including branches that are NOT
ancestors of this commit (docs/hardware-reference, nishimaki, capacitive, tc69,
rp2040, blehack, bluefruit_uart, qmk-master) -- is preserved as a git bundle
attached to the GitHub Release on this tag.

To restore:
    gh release download archive/oldfork-final -R sadaoikebe/qmk_firmware
    git clone qmk-oldfork.bundle restored
    cd restored && git branch -a
EOF
```

**確認:**

```sh
git tag -n99 -l archive/oldfork-final
git rev-parse archive/oldfork-final^{commit}
```

**期待状態:** タグメッセージが表示され、指すコミットが `e3d92a7463...`。

## 1-3. タグを push

```sh
git push origin archive/oldfork-final
```

**期待出力:** `* [new tag]  archive/oldfork-final -> archive/oldfork-final`

## 1-4. GitHub 側で確認

```sh
gh api repos/sadaoikebe/qmk_firmware/git/refs/tags/archive/oldfork-final \
  --jq '.ref, .object.sha, .object.type'
```

**期待出力:**

```
refs/tags/archive/oldfork-final
<タグオブジェクトのSHA>
tag
```

`type` が `tag` = annotated タグとして正しく登録されている。

---

# Phase 2 — Release を作成し bundle をアップロード

## 2-1. Release ノートを用意

```sh
cat > /c/Users/marur/qmk-archive/release-notes.md <<'EOF'
# 旧フォークのアーカイブ

移行前の `sadaoikebe/qmk_firmware` フォーク全体のアーカイブ。

このリポジトリの `master` はこの後 upstream (qmk/qmk_firmware) にリセットされ、
旧ブランチは削除された。**このリリースが旧フォークの唯一の完全な記録**。

## 中身

`qmk-oldfork.bundle` — `git clone --mirror` から作った git bundle。

- 87 ブランチ / 854 タグ / PR 参照 2本
- 268,758,429 bytes
- SHA256: `cd590db4f4fc68d017567b4be15c218946b221001729493346b12a83514d3b78`

タグ `archive/oldfork-final` が指す `e3d92a7463` は旧 master の先端。
**それ以外のブランチはこのコミットの祖先ではないので、bundle にしか存在しない。**
特に `docs/hardware-reference` (回路情報 + NICOLA 仕様書) は bundle 経由でしか取れない。

## 復元手順

```sh
gh release download archive/oldfork-final -R sadaoikebe/qmk_firmware
sha256sum -c qmk-oldfork.bundle.sha256
git clone qmk-oldfork.bundle restored
cd restored
git bundle verify ../qmk-oldfork.bundle   # verify はリポジトリ内でないと動かない
git branch -r | grep -v HEAD | wc -l      # 87 branches
git tag | wc -l                           # 854 tags
```

## 主なブランチ

| ブランチ | 内容 |
|---|---|
| `master` | 旧フォーク本流。自作キーボード全部 + NICOLA |
| `docs/hardware-reference` | 回路情報 (HARDWARE-REFERENCE.md) と NICOLA 仕様書 (NICOLA-SPEC.md) |
| `nishimaki` | ts52k の特定個人向け改造 |
| `capacitive` / `tc69` | 静電容量式キーボード。デバウンスをアナログヒステリシスに置換 |
| `rp2040` | RP2040 移植の試み |
| `blehack` / `bluefruit_uart` | BLE 実験 |
| `qmk-master` / `mechkbs` | 本家追従・実験用 |

残り約78本は本家 qmk/qmk_firmware 由来のブランチ。
EOF
```

## 2-2. Release を作成しつつアップロード

タグは既に存在するので、`gh` は新規タグを作らずそれを使う。

```sh
cd /c/Users/marur/qmk-archive
gh release create archive/oldfork-final \
  --repo sadaoikebe/qmk_firmware \
  --title "Old fork archive (pre-migration, 2026-02-13)" \
  --notes-file release-notes.md \
  qmk-oldfork.bundle qmk-oldfork.bundle.sha256 qmk-oldfork.manifest.txt
```

**期待:** アップロードに数分。完了後に Release の URL が表示される。

> 256MB のアップロードなので回線次第では時間がかかる。途中で失敗した場合は
> `gh release delete archive/oldfork-final --yes --cleanup-tag=false` で消してやり直すか、
> Release だけ先に作って `gh release upload archive/oldfork-final qmk-oldfork.bundle` で
> 個別に再送する。**`--cleanup-tag` を付けるとタグまで消えるので付けない。**

## 2-3. Release の中身を確認

```sh
gh release view archive/oldfork-final --repo sadaoikebe/qmk_firmware \
  --json tagName,isDraft,isPrerelease,assets \
  --jq '.tagName, .isDraft, .isPrerelease, (.assets[] | "\(.name)\t\(.size)\t\(.state)")'
```

**期待出力:**

```
archive/oldfork-final
false
false
qmk-oldfork.bundle          268758429   uploaded
qmk-oldfork.bundle.sha256   <小さい>     uploaded
qmk-oldfork.manifest.txt    <数万>       uploaded
```

- `isDraft` が `true` なら公開されていない。`gh release edit archive/oldfork-final --draft=false`
- `state` が `uploaded` 以外なら再アップロード
- **`size` が 268758429 と一致しない場合は必ず再アップロード**

---

# Phase 3 — 検証ゲート（ここを通るまで破壊的操作をしない）

「アップロードできた」ではなく「アップロードしたものから復元できる」ことを確かめる。
ローカルの bundle ではなく、**GitHub から落とし直したもの**で検証するのが要点。

## 3-1. Release からダウンロード

```sh
rm -rf /c/Users/marur/qmk-archive/verify
mkdir -p /c/Users/marur/qmk-archive/verify
cd /c/Users/marur/qmk-archive/verify
gh release download archive/oldfork-final --repo sadaoikebe/qmk_firmware
ls -l
```

**期待状態:** 3ファイル。`qmk-oldfork.bundle` が 268,758,429 bytes。

## 3-2. SHA256 照合

```sh
cd /c/Users/marur/qmk-archive/verify
sha256sum -c qmk-oldfork.bundle.sha256
```

**期待出力:** `qmk-oldfork.bundle: OK`

**`FAILED` なら転送が壊れている。絶対に先へ進まない。**

## 3-3. clone して bundle 検証と件数確認

`git bundle verify` はリポジトリ内でないと動かないので、先に clone してその中で実行する。

```sh
cd /c/Users/marur/qmk-archive/verify
git clone --quiet qmk-oldfork.bundle restored
cd restored
git bundle verify ../qmk-oldfork.bundle 2>&1 | tail -3
echo "branches: $(git branch -r | grep -v HEAD | wc -l)"
echo "tags:     $(git tag | wc -l)"
```

**期待出力:**

```
The bundle records a complete history.
The bundle uses this hash algorithm: sha1
branches: 87
tags:     854
```

clone が成功した時点で bundle が読めることは証明されているが、`verify` は
「前提コミットを外部に頼っていない（自己完結している）」ことの確認なので別途行う。

## 3-4. 中身が本当に読めるか（内容レベルの検証）

参照が存在するだけでなく、blob が実在することを確かめる。

```sh
cd /c/Users/marur/qmk-archive/verify/restored

# (a) アンカーコミットから、廃棄予定キーボードのファイルが読めるか
git show e3d92a7463:keyboards/handwired/ajazz82/config.h | head -5

# (b) アンカーの祖先でないブランチが読めるか ← ここが本番
git show 71bb18a098:HARDWARE-REFERENCE.md | head -5
git show 71bb18a098:NICOLA-SPEC.md | head -5

# (c) nishimaki が読めるか
git log -1 --format='%H %s' origin/nishimaki
```

**期待状態:** (a)(b)(c) すべて内容が表示される。

**(b) が失敗する場合、`docs/hardware-reference` は Phase 5 で削除してはならない。**

`git show <sha>:<path>` で内容が出るということは、コミット・ツリー・blob が
すべて bundle に入っていることの証明になる。参照が存在するだけでは足りない。

## 3-5. ゲート判定

以下が全部 OK なら Phase 4 へ進む。ひとつでも NG なら止まる。

- [ ] 3-2 SHA256 `OK`
- [ ] 3-3 `complete history` / branches 87 / tags 854
- [ ] 3-4 (a)(b)(c) 全て内容表示
- [ ] ローカル `C:\Users\marur\qmk-archive\qmk-oldfork.bundle` も残っている（二重化）

---

# Phase 4 — master を upstream に合わせる（最初の破壊的操作）

旧 master `e3d92a7463` はタグ `archive/oldfork-final` から到達可能なので、
force-push しても GC されない。**Phase 1 のタグ push が済んでいることが絶対条件。**

## 4-1. タグが GitHub 上に存在することを再確認

```sh
gh api repos/sadaoikebe/qmk_firmware/git/refs/tags/archive/oldfork-final --jq '.ref'
```

**期待出力:** `refs/tags/archive/oldfork-final`

**ここでエラーが出たら Phase 4 を実行してはいけない。** 旧 master が消える。

## 4-2. 新クローン側から fork へ push する準備

旧フォークに upstream を足して4年分 fetch するより、
既に upstream 最新を持っている新クローンから push する方が速く安全。

```sh
cd /c/Users/marur/qmk_firmware
git remote add fork git@github.com:sadaoikebe/qmk_firmware.git
git remote -v
git fetch upstream master
git rev-parse upstream/master
```

**期待状態:** `fork` が SSH URL で追加されている。`upstream/master` の SHA が表示される
（2026-08-10 時点の実測は `0456ffb38e`。fetch で進んでいれば別の値でよい）。

## 4-3. force-push

期待値を明示した `--force-with-lease` を使う。リモートが `e3d92a7463` でなければ拒否される。

```sh
cd /c/Users/marur/qmk_firmware
git push --force-with-lease=master:e3d92a746304ba68d08e56a20b53da5dbc76859c \
  fork upstream/master:refs/heads/master
```

**期待出力:** `+ e3d92a74...<新SHA> upstream/master -> master (forced update)`

`stale info` で拒否されたら、リモート master が想定と違う。**握りつぶさず調査する。**

## 4-4. 確認

```sh
git ls-remote fork refs/heads/master
git -C /c/Users/marur/qmk_firmware rev-parse upstream/master
gh api repos/sadaoikebe/qmk_firmware/git/refs/tags/archive/oldfork-final --jq '.object.sha'
```

**期待状態:**

- 上2つの SHA が一致（fork の master = upstream master）
- タグは依然として存在

GitHub のリポジトリページで `This branch is up to date with qmk/qmk_firmware:master.`
のような表示になるのが目視での期待。

---

# Phase 5 — ブランチ削除

## 5-1. 削除対象リストを作る

`git branch -r` は `origin/HEAD` の行を含むので、`ls-remote --heads` から作る。

```sh
cd /c/Users/marur/qmk_firmware_oldfork
git fetch origin --prune
git ls-remote --heads origin | sed 's|.*refs/heads/||' | grep -v '^master$' \
  | sort > /c/Users/marur/qmk-archive/branches-to-delete.txt
wc -l < /c/Users/marur/qmk-archive/branches-to-delete.txt
```

**期待状態:** **86行**（87 − master）。

## 5-2. `docs/hardware-reference` の扱いを決める

このブランチには `HARDWARE-REFERENCE.md` と `NICOLA-SPEC.md` がある。
同じ内容は `C:\Users\marur\qmk_userspace\docs\` にもあるが、
**`qmk_userspace` はまだ GitHub に push していない。**

したがって、今削除すると「GitHub 上の唯一のコピー」が bundle の中だけになる。
bundle 検証は通っているので失われはしないが、掘り出しに手間がかかる。

**推奨: `qmk_userspace` を GitHub に push するまで残す。**

```sh
# 推奨（残す）
sed -i '/^docs\/hardware-reference$/d' /c/Users/marur/qmk-archive/branches-to-delete.txt
wc -l < /c/Users/marur/qmk-archive/branches-to-delete.txt   # → 85
```

残す判断をした場合、最終形は master + docs/hardware-reference の2ブランチになる。
`qmk_userspace` を push した後で改めて削除する。

## 5-3. リストを目視する

```sh
cat /c/Users/marur/qmk-archive/branches-to-delete.txt
```

**確認事項:**

- `master` が入っていない
- 残すと決めたものが入っていない
- 自分のブランチ（`nishimaki` `capacitive` `tc69` `rp2040` `blehack` `bluefruit_uart`
  `qmk-master` `mechkbs`）は **入っていてよい** — bundle に全部入っている

## 5-4. 分割して削除

一括ではなく10本ずつ。途中で止めたときに「どこまで消えたか」がわかる。

```sh
cd /c/Users/marur/qmk_firmware_oldfork
split -l 10 -d /c/Users/marur/qmk-archive/branches-to-delete.txt /c/Users/marur/qmk-archive/chunk-
ls /c/Users/marur/qmk-archive/chunk-*
```

**期待状態:** `chunk-00` .. `chunk-08` の9ファイル（85本 → 10本×8 + 5本）。

1ファイルずつ、**中身を見てから**実行する。

```sh
cat /c/Users/marur/qmk-archive/chunk-00
git push origin --delete $(cat /c/Users/marur/qmk-archive/chunk-00)
```

**期待出力:** 各ブランチについて `- [deleted]  <branch>`

以降 `chunk-01` .. `chunk-08` を同様に。

> `remote ref does not exist` が出たら、既に消えている。無害。

## 5-5. 削除後の確認

```sh
cd /c/Users/marur/qmk_firmware_oldfork
git fetch origin --prune
git branch -r | grep -v HEAD
```

**期待出力:**

```
origin/docs/hardware-reference
origin/master
```

（`docs/hardware-reference` を残さない判断をしたなら `origin/master` のみ）

## 5-6. タグの扱い

854個のタグは本家由来。upstream に合わせるなら残すのが自然（本家にも同じタグがある）。
`archive/oldfork-final` が混ざっても実害はない。**削除は不要。**

---

# Phase 6 — 最終確認とドキュメント更新

## 6-1. リポジトリの最終状態

```sh
gh repo view sadaoikebe/qmk_firmware --json defaultBranchRef,isFork,parent \
  --jq '.defaultBranchRef.name, .isFork, .parent.owner.login'
git ls-remote --heads origin
gh release list --repo sadaoikebe/qmk_firmware
gh api repos/sadaoikebe/qmk_firmware/git/refs/tags/archive/oldfork-final --jq '.object.sha'
```

**期待状態:**

- default branch = `master`、fork = `true`、parent = `qmk`
- heads = master (+ 残す判断をしたブランチ)
- Release 一覧に `archive/oldfork-final` が1件
- タグ健在

## 6-2. 検証用ディレクトリを片付ける

```sh
rm -rf /c/Users/marur/qmk-archive/verify
rm -f  /c/Users/marur/qmk-archive/chunk-*
ls -l  /c/Users/marur/qmk-archive/
```

**期待状態:** bundle / .sha256 / manifest / release-notes.md / branches-to-delete.txt が残る。

## 6-3. スクラッチパッドの残骸を消す

```sh
rm -rf "/c/Users/marur/AppData/Local/Temp/claude/C--Users-marur/9e80fdcf-2fae-4dad-b1df-fc4c5bfdf6ad/scratchpad/mirror.git"
rm -rf "/c/Users/marur/AppData/Local/Temp/claude/C--Users-marur/9e80fdcf-2fae-4dad-b1df-fc4c5bfdf6ad/scratchpad/restore2"
rm -rf "/c/Users/marur/AppData/Local/Temp/claude/C--Users-marur/9e80fdcf-2fae-4dad-b1df-fc4c5bfdf6ad/scratchpad/restore-test"
```

## 6-4. 旧フォーク作業ディレクトリ

`C:\Users\marur\qmk_firmware_oldfork` は、bundle 検証が通っていれば消してよい。
ただし急ぐ必要はない。**しばらく置いておいて、移行が一段落してから消す方が安全。**

## 6-5. ドキュメント修正（別件だが忘れないこと） — ✅ 2026-08-12 完了

「External Userspace があればフォーク不要」という記述は**誤り**。
External Userspace は keymap / layouts / users は外に置けるが、**キーボード定義は置けない**
（`build_keyboard.mk` の `KEYBOARD_PATH_N := keyboards/$(...)` がハードコード）。

修正対象:

- `C:\Users\marur\qmk_userspace\README.md`
- `C:\Users\marur\qmk_userspace\docs\HARDWARE-REFERENCE.md`
- memory: `qmk-migration-plan.md`

また `HARDWARE-REFERENCE.md` に、アーカイブの所在と復元手順を追記する。

> **完了記録（2026-08-12）**: 上記に加えて、`README.md` に残っていた
> 「ts52k の定義の置き場所は**未決**（案A / 案B）」も解消した。
> **案A（`sadao-master` に `keyboards/ts52k/` を足す）で決着し、実装も完了している。**
> 併せて README の `qmk compile -km nicola4r`（存在しない旧 keymap 名）と
> `user.overlay_dir=~/...`（`~` は Windows で壊れる）も直した。

---

# ロールバック / 事故対応

| 事故 | 対応 |
|---|---|
| Phase 2 のアップロードが途中で失敗 | `gh release upload archive/oldfork-final qmk-oldfork.bundle --clobber` で再送。タグは消さない |
| Phase 3 で SHA256 不一致 | 再アップロード。**Phase 4 に進まない** |
| Phase 4 で `stale info` 拒否 | 想定通り。リモート master を調査してから判断 |
| Phase 4 実行後に「やっぱり旧 master に戻したい」 | `git push --force fork archive/oldfork-final^{commit}:refs/heads/master` |
| Phase 5 で消しすぎた | bundle から復元 → `git push origin <sha>:refs/heads/<branch>` |
| bundle 自体を失った | ローカル `C:\Users\marur\qmk-archive\` と GitHub Release の二重化で担保 |

**最重要:** タグ `archive/oldfork-final` と Release の bundle、この2つが揃っている限り
何をやっても復旧できる。逆に、この2つが揃う前に Phase 4/5 をやってはいけない。
