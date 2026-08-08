# NICOLA 親指シフト 実装仕様書

現行実装（`keyboards/ts52k/keymaps/nicola4r/nicola.c`, master `e3d92a7463`, 1091行）の
**挙動を仕様として書き出したもの**。

目的は 2 つ:

1. コードを捨てて最新 QMK で書き直すときの**正解表**にする
2. 状態機械を「シンプルかつ一般的な形」に再設計するときの**入力仕様**にする

原型は https://github.com/eswai/qmk_firmware/ 。そこに NICOLA 規格のタイミング判定を追加したもの。

---

## 0. 設計原則 — 書き直しても必ず守ること

### 原則1: press と release は物理キーと厳密に対応させる

**物理キーを離したときに release を発行する。これは絶対に崩さない。**

同時打鍵判定の結果として出力するキーは、`register_code()` で押し、
**ユーザが物理キーを離すまで押しっぱなしにする**。`unregister_code()` は物理キーの解放イベントで発行する。

理由は「キーリピートのため」ではない。**あらゆる場面で、普通のキーボードとしての使用感を保つため**。
親指シフトで英数キーを処理する構成（TS52K）では、英数レイヤーが完全に普通のキーボードとして
振る舞わなければ使い物にならない。押しっぱなし・修飾キーとの組み合わせ・ゲームでの同時押しなど、
press/release が物理キーと 1:1 対応していることを前提にした挙動は無数にある。

> ⚠️ **書き直し時の罠: `tap_code()` / `tap_code16()` を使ってはいけない。**
> これらは press と release を即座に連続発行するため実装は簡単になるが、
> 押しっぱなしが効かなくなり、この原則を破る。
> 必ず `register_code()` / `unregister_code()` を分離して使うこと。
> （旧実装の `send_string()` も同じ理由で 2026-01 に廃止された）

**受け入れている帰結**: ローマ字入力でも押しっぱなしが効く。
かな入力で「な」(`NG_N` → `N`,`A`) を打って指を離さずにいると、
`N` も `A` も押されたままになり **「なあああああ」** とリピートする。
これは**バグではなく設計意図通り**。原則1を守った結果として必然的にこうなる。

### 原則2: 同時打鍵判定を通すかどうかは keymap 側で決める

`nicola.c` は「かなモード専用」にも「英数too」にも作らない。両方に使える 1 つの実装にして、
どちらの性格にするかは keymap の `process_record_user()` で決める（第 1 節ゲート1）。

---

## 1. 全体構成 — ゲートは 3 段ある

NICOLA の同時打鍵判定は、以下の 3 段のゲートを通過したキーにだけ適用される。
**どの段でスルーさせるかがキーボードごとの性格を決める。**

```
process_record_user()                    ← keymap 側
  │
  ├─[ゲート1] if (nicola_state()) …      ← かなモードのときだけ通す（任意）
  │
  ├─ nicola_mode(keycode, record)        ← [ゲート2] modifier 検出・レイヤー制御
  │
  └─ process_nicola(keycode, record)
        │
        └─[ゲート3] キー分類              ← M / O / その他 に振り分け
```

### ゲート1: keymap 側の `if (nicola_state())`

**これがキーボード間の唯一の差。`nicola.c` 側は共通。**

| キーボード | keymap の書き方 | 結果 |
|---|---|---|
| TS52K (`nicola4r`) | ガード**なし**（無条件呼び出し） | 英数モードでも `process_nicola()` に入る。英数レイヤーが `NG_E_*` を使うため必須 |
| TS69 (`users/nicola`) | `if (nicola_state()) { … }` | **英数モードでは `process_nicola()` が一度も呼ばれない。** 状態機械に入らない |

TS69 の英数レイヤーは全て素の `KC_*`（親指キーも `KC_SPC` が 2 つ）なので、
仮にガードが無くても全キーが「その他」分類に落ちて素通りする。ガードは二重の保険。

```c
/* TS69 方式 — 英数では NICOLA 判定を完全にスルー */
bool a = true;
if (nicola_state()) {
    nicola_mode(keycode, record);
    a = process_nicola(keycode, record);
}
if (a == false) return false;

/* TS52K 方式 — 常に通す */
nicola_mode(keycode, record);
bool a = process_nicola(keycode, record);
if (a == false) return false;
```

> **書き直し後もこの形を維持する。** 「英数モードでは同時打鍵判定を一切使わない」は
> keymap 側 1 行で表現でき、`nicola.c` の分岐を増やさずに済む。

### ゲート2: `nicola_mode()` — modifier が押されている間はレイヤーを外す

```c
void nicola_mode(uint16_t keycode, keyrecord_t *record) {
  if (!is_nicola) return;                       // 英数モードでは何もしない
  switch (keycode) {
    case KC_LCTRL: case KC_LSHIFT: case KC_LALT: case KC_LGUI:
    case KC_RCTRL: case KC_RSHIFT: case KC_RALT: case KC_RGUI:
      if (record->event.pressed) {
        if (n_modifier == 0) layer_off(nicola_layer);   // 1個目で NICOLA レイヤーを外す
        n_modifier++;
      } else {
        n_modifier--;
        if (n_modifier == 0) layer_on(nicola_layer);    // 全部離したら戻す
      }
      break;
  }
}
```

意図: かなモード中に `Ctrl+C` などを押したら、NICOLA レイヤーを一時的に外して
素の QWERTY を露出させる。押している modifier の数を数えているので、
`Ctrl+Shift+X` のような複数同時でも正しく戻る。

> ⚠️ **既知の弱点**: レイヤーを外すのはキーコード解決より後なので、
> modifier と文字キーをほぼ同時に押すと取りこぼす余地がある。
> `603221b2e9 "modifier disrupted nicola state machine"` (2026-01-14) で一度修正されている箇所。
> 書き直し時は「modifier 押下中は `process_nicola()` を素通りさせる」形（下記の死んだガード）
> のほうが素直かもしれない。

### ゲート3: キー分類

`process_nicola()` の冒頭に、無効化されたガードが残っている:

```c
// if (!is_nicola || n_modifier > 0) return true;    ← コメントアウト
```

これは旧 `users/nicola` 方式の名残。TS52K が英数でも NICOLA を通すようになったため無効化された。
**`n_modifier > 0` の条件だけは復活させる価値がある**（modifier 併用時に同時打鍵判定を切る）。

---

## 2. キーの分類

`NG_*` キーコードは `nicola.h` で**連続した enum** として定義され、範囲比較で分類される。

```
NG_TOP = SAFE_RANGE
│
├── NG_M_TOP ─────────────────────────────────────┐
│   NG_E_TAB   ← 左手・英数の先頭                  │
│   NG_E_Q .. NG_E_B         (EISU1 = 英数左)      │
│   NG_Q   .. NG_B           (かな左)              │  M キー
│   NG_E_Y .. NG_E_SLSH      (EISU2 = 英数右)      │  (文字キー)
│   NG_Y   .. NG_SLSH        (かな右)              │
│   NG_LEFT, NG_DOWN, NG_UP, NG_RIGHT  (カーソル)  │
├── NG_M_BOTTOM = NG_RIGHT ───────────────────────┘
│
│   NG_SHFTL, NG_SHFTR                              ← O キー (親指キー)
└── NG_BOTTOM = NG_SHFTR
```

| 判定関数 | 範囲 | 意味 |
|---|---|---|
| `is_nicola_m_key()` | `NG_M_TOP` 〜 `NG_M_BOTTOM` | **M キー** = 文字キー。かな・英数・カーソルを全部含む |
| `is_nicola_o_key()` | `NG_SHFTL`, `NG_SHFTR` のみ | **O キー** = 親指キー |
| `is_nicola_left_finger()` | `NG_E_TAB` 〜 `NG_B` | 左手で打つキー（英数左 + かな左） |
| `is_nicola_right_finger()` | `NG_E_Y` 〜 `NG_SLSH` | 右手で打つキー（英数右 + かな右） |
| `is_nicola_eisu()` | `NG_E_TAB`〜`NG_E_B` または `NG_E_Y`〜`NG_E_SLSH` | 英数キー |
| 上記いずれでもない | — | **その他キー**。追い越し防止バッファの対象 |

> ⚠️ **カーソルキー `NG_LEFT`/`NG_DOWN`/`NG_UP`/`NG_RIGHT` は M キーだが
> 左手・右手どちらの範囲にも入らない。** よって `is_cross_shift()` が常に false になる。
> 意図的なのか漏れなのかコードからは読み取れない。書き直し時に要判断。

### クロスシフト判定

```c
is_cross_shift(m, o) = (左手キー && o == NG_SHFTR) || (右手キー && o == NG_SHFTL)
```

打鍵した指と反対側の親指を使った = クロスシフト。同じ側なら同側シフト。

---

## 3. タイミング定数

```c
#define TIMEOUT_THRESHOLD (80)   // ms — 同時打鍵とみなす最大間隔
#define OVERLAP_THRESHOLD (20)   // ms — 「まだ結合の余地あり」とみなす重なり時間
```

### タイムアウトの実装が 2 系統ある

```c
#ifdef TIMEOUT_INTERRUPT
#define IF_TIMEOUT(x) if(0)      // ← 割り込み方式: ポーリング判定を無効化
#else
#define IF_TIMEOUT(x) if(x)      // ← ポーリング方式
#endif
```

TS52K / TS69 とも `rules.mk` で `OPT_DEFS = -DTIMEOUT_INTERRUPT` を指定しているので、
**実際に動いているのは割り込み方式**。`IF_TIMEOUT()` で囲まれた分岐は全て死んでいる。

割り込み側:

```c
keypress_timer_start(TIMEOUT_THRESHOLD * 16);   // キー押下のたびに再スタート
// TIMER1 は clock/1024、16MHz なので 1 tick = 64µs
// 80 * 16 = 1280 ticks = 81.92 ms ≒ TIMEOUT_THRESHOLD

void keypress_timer_expired(void) {             // ISR から呼ばれる
    if (!key_process_guard) nicola_trigger();   // 処理中でなければ確定出力
}
```

`key_process_guard` は `process_nicola()` の入口で 1、出口で 0 になる。
ISR と本処理の競合を防ぐだけの排他フラグ。

> ⚠️ **不整合**: `IF_TIMEOUT()` を使うべき箇所のうち 2 つが**素の `if` になっている**。
> `S6_OO` での M 押下時（L879）と、`S3_O` での O 押下時（L929）。
> 後者は OO 判定に必要なので意図的だが、前者はおそらく書き忘れ。
> `S6_OO` は廃止予定なので実害は消える。

---

## 4. 状態遷移表

### 状態

| 状態 | 意味 |
|---|---|
| `S1_INIT` | 待機。保留中の打鍵なし |
| `S2_M` | 文字キー(M)を 1 つ保留中 |
| `S3_O` | 親指キー(O)を 1 つ保留中 |
| `S4_MO` | M → O の順で押された。同時打鍵候補 |
| `S5_OM` | O → M の順で押された。同時打鍵候補 |
| `S6_OO` | 親指キー 2 つ。**廃止予定**（第 7 節） |

### 保持する変数

```
nicola_m_key,  nicola_m_time     保留中の M キーとその押下時刻
nicola_o_key,  nicola_o_time     保留中の O キーとその押下時刻
nicola_*_pressed                 その打鍵を既に register 済みか
```

### 出力アクションの語彙

| アクション | 意味 |
|---|---|
| `m_press` / `o_press` / `om_press` | **押しっぱなしで出力**（`register_code` のみ） |
| `m_release` / `o_release` / `om_release` | **確定して離す**。未 press なら press してから `unregister_code` |

`*_release()` は必ず `if (!*_pressed) *_press();` から始まるので、
**「まだ出していなければ出してから離す」**という意味になる。
タイムアウト（`nicola_trigger`）は `*_press()` を呼ぶので、キーは押されたままになり、
ユーザが実際に離したときに `*_release()` が `unregister` だけ行う。

---

### 4-1. M キー押下

| 現状態 | 条件 | 出力 | 次状態 |
|---|---|---|---|
| `S1_INIT` | — | なし | `S2_M` |
| `S2_M` | — | 前の M を単独確定 (`m_release`) | `S2_M` |
| `S3_O` | *(timeout — 割り込み方式では無効)* | O を単独確定 (`o_release`) | `S2_M` |
| `S3_O` | 上記以外 | なし | `S5_OM` |
| `S4_MO` | *(timeout — 無効)* | MO 同時打鍵を確定 (`om_release`) | `S2_M` |
| `S4_MO` | `t1 < t2` | MO 同時打鍵を確定 (`om_release`) | `S2_M` |
| `S4_MO` | `t1 >= t2` | 先頭 M を単独確定 (`m_release`) | `S5_OM` |
| `S5_OM` | — | OM 同時打鍵を確定 (`om_release`) | `S2_M` |

`S4_MO` の 3 キー判定: `t1 = o_time - m_time`（M→O の間隔）、`t2 = now - o_time`（O→今の間隔）

* `t1 < t2` … 間に挟まった O は**前の M と結合** → `[MO]` を出して、今の M を新規保留
* `t1 >= t2` … 先頭 M は**単独**、O は**今の M と結合** → `M` を出して `S5_OM` へ

**共通の後処理**（どの遷移でも実行）:

```c
nicola_m_key  = keycode;
nicola_m_time = now;
keypress_timer_start(TIMEOUT_THRESHOLD * 16);
cont_process = false;                  // キーを飲み込む（QMK に渡さない）
```

---

### 4-2. O キー押下

| 現状態 | 条件 | 出力 | 次状態 |
|---|---|---|---|
| `S1_INIT` | — | なし | `S3_O` |
| `S2_M` | *(timeout — 無効)* | M を単独確定 (`m_release`) | `S3_O` |
| `S2_M` | 上記以外 | なし | `S4_MO` |
| `S3_O` | `now - o_time <= 80` かつ **別の**親指キー | なし（前の O を `o2` に退避） | `S6_OO` ※廃止 |
| `S3_O` | 上記以外 | 前の O を単独確定 (`o_release`) | `S3_O` |
| `S4_MO` | — | MO 同時打鍵を確定 (`om_release`) | `S3_O` |
| `S5_OM` | *(timeout — 無効)* | OM 同時打鍵を確定 (`om_release`) | `S3_O` |
| `S5_OM` | `t1 < t2` | OM 同時打鍵を確定 (`om_release`) | `S3_O` |
| `S5_OM` | `t1 >= t2` | 先頭 O を単独確定 (`o_release`) | `S4_MO` |

`S5_OM` の 3 キー判定: `t1 = m_time - o_time`、`t2 = now - m_time`

**共通の後処理**:

```c
nicola_o_key  = keycode;
nicola_o_time = now;
keypress_timer_start(TIMEOUT_THRESHOLD * 16);
cont_process = false;
```

---

### 4-3. M / O キー解放

対象は `NG_TOP <= keycode <= NG_BOTTOM` の全て。**必ず `cont_process = false`（飲み込む）。**

| 現状態 | 条件 | 出力 | 次状態 |
|---|---|---|---|
| `S1_INIT` | — | なし | `S1_INIT` |
| `S2_M` | `m_key == keycode` | M を単独確定 | `S1_INIT` |
| `S2_M` | 別のキー | なし | `S2_M` |
| `S3_O` | `o_key == keycode` | O を単独確定 | `S1_INIT` |
| `S3_O` | 別のキー | なし | `S3_O` |
| `S4_MO` | `m_key == keycode` かつ `t1 >= t2` かつ `t2 < 20` | **M だけ**確定 (`m_release`) | `S3_O` |
| `S4_MO` | `m_key == keycode` かつ 上記以外 | MO 同時打鍵を確定 | `S1_INIT` |
| `S4_MO` | `o_key == keycode` | MO 同時打鍵を確定 | `S1_INIT` |
| `S5_OM` | `o_key == keycode` かつ `t1 >= t2` かつ `t2 < 20` | **O だけ**確定 (`o_release`) | `S2_M` |
| `S5_OM` | `o_key == keycode` かつ 上記以外 | OM 同時打鍵を確定 | `S1_INIT` |
| `S5_OM` | `m_key == keycode` | OM 同時打鍵を確定 | `S1_INIT` |

* `S4_MO` の解放判定: `t1 = o_time - m_time`、`t2 = now - o_time`
* `S5_OM` の解放判定: `t1 = m_time - o_time`、`t2 = now - m_time`

`t2 < OVERLAP_THRESHOLD (20ms)` の意味:
**「先に押したキーを離すのが速すぎる = まだ後のキーは次の打鍵と結合する余地がある」**。
この場合だけ先のキーを単独で出し、後のキーを保留したまま状態を 1 段戻す。
早いロールオーバー入力を拾うための例外処理。

---

### 4-4. タイムアウト（ISR）

```
ISR 発火 (最後のキーイベントから約 80ms)
  → key_process_guard が立っていなければ nicola_trigger()
```

| 現状態 | 出力 | 次状態 |
|---|---|---|
| `S1_INIT` | なし | 変化なし |
| `S2_M` | `m_press`（**押しっぱなし**） | **変化なし** |
| `S3_O` | `o_press` | **変化なし** |
| `S4_MO` / `S5_OM` | `om_press` | **変化なし** |

> **重要: タイムアウトは状態を変えない。** キーを「押した状態で出力する」だけ。
> ユーザが指を離したときに 4-3 の表が走り、`*_release()` が
> 「既に press 済み」を検出して `unregister` だけ行う。
>
> これは**原則1（press/release を物理キーと厳密に対応させる）の実装**である。
> 「同時打鍵が確定したら押しっぱなしにし、物理キーを離すまで待つ」という構造になっているため、
> 出力キーの押下期間が物理キーの押下期間と一致する。

---

### 4-5. その他のキー（非 `NG_*`）— 追い越し防止

押下・解放とも同じ扱い。

| 現状態 | バッファ | 動作 |
|---|---|---|
| `S1_INIT` | — | **そのまま QMK に渡す** (`cont_process = true`) |
| `S1_INIT` 以外 | 空きあり | **バッファに積んで飲み込む** (`cont_process = false`) |
| `S1_INIT` 以外 | 満杯 (8個) | `nicola_trigger()` で現在の保留を吐き出してから渡す (`true`) |

```c
#define NICOLA_MAX_PENDING_EVENTS 8
typedef struct { uint16_t keycode; bool pressed; } pending_event_t;
pending_event_t nicola_pending_events[NICOLA_MAX_PENDING_EVENTS];
```

**これが追い越し防止の本体。** 状態機械が動作中（= `S1_INIT` 以外 = 打鍵が保留されている）に
非 NICOLA キーが来ると、そのキーを先に出力してしまうと**順序が逆転する**。
そこでバッファに積んでおき、保留中の打鍵が確定したときに一緒に吐き出す。

吐き出しは `nicola_flush_pending_events()` で、**全ての `*_press()` / `*_release()` の末尾**から呼ばれる:

```c
void nicola_flush_pending_events(void) {
    for (uint8_t i = 0; i < nicola_pending_count; ++i) {
        if (nicola_pending_events[i].pressed) register_code16(...);
        else                                  unregister_code16(...);
    }
    nicola_pending_count = 0;
}
```

> **TS69 方式（英数で NICOLA を通さない）ではこの機構は一度も働かない。**
> 英数レイヤーに `NG_*` が存在せず、状態は常に `S1_INIT` のままだから。
> TS52K のように英数も NICOLA を通す構成にして初めて必要になる。

### `nicola_release_guard()`

全ての `*_press()` の冒頭で呼ばれる保険。

```c
void nicola_release_guard(void) {
    if (nicola_m_pressed)  nicola_m_release();
    if (nicola_o_pressed)  nicola_o_release();
    if (nicola_om_pressed) nicola_om_release();
}
```

「前の打鍵がまだ register されたままなら強制的に離す」。二重出力を防ぐための後付けガード。
**状態機械が正しければ不要なはず**で、これが必要になっている時点で設計に緩みがある。
書き直し時の削除候補。

---

## 5. 出力の決定 — かな・英数・シフト

### 5-1. 単独打鍵

| | 出力 |
|---|---|
| M 単独 (`m_press`) | `NG_*` → かな（ローマ字を `register_code` で連続送出）<br>`NG_E_*` → 英数 1 文字 |
| O 単独 (`o_press`) | master: `NG_SHFTL` / `NG_SHFTR` とも **Space**<br>nishimaki: `NG_SHFTL`→Space, `NG_SHFTR`→`KC_LANG1` |

かなは IME にローマ字を送る方式。例: `NG_W` → `register_code(KC_K); register_code(KC_A);` で「か」。

### 5-2. 同時打鍵 (`om_press`)

`nicola_o_key` が `NG_SHFTL` か `NG_SHFTR` かで別テーブルを引く。

### 5-3. `invert_pinky_shift` — 小指シフトの反転

**現行実装で一番トリッキーな部分。** 出力直前に Shift の状態を反転させる。

```c
if (is_nicola_eisu(nicola_m_key)) {
    bool eisu_cross_shift = is_cross_shift(nicola_m_key, nicola_o_key);
    invert_pinky_shift = (eisu_cross_shift != is_nicola);      // XOR

    switch (nicola_m_key) {                                    // カーソルキーは例外
      case NG_E_C: case NG_E_V: case NG_E_N: case NG_E_M:
        invert_pinky_shift = is_nicola;
        break;
    }
} else {
    if (nicola_o_key == NG_SHFTL) {
        switch (nicola_m_key) {                                // "_" "+" "?" を出すため
          case NG_LBRC: case NG_RBRC: case NG_SLSH:
            invert_pinky_shift = true;
            break;
        }
    }
}

if (invert_pinky_shift) {
    uint8_t new_mods = get_mods();
    uint8_t shift_bits = MOD_BIT(KC_LSFT) | MOD_BIT(KC_RSFT);
    if (new_mods & shift_bits) new_mods &= ~shift_bits;   // 押されていれば外す
    else                       new_mods |= MOD_BIT(KC_LSFT);  // なければ足す
    set_mods(new_mods);
}
```

#### 前提: 2 種類のシフトが同時に存在する

この処理が複雑なのは、**親指シフトと小指シフト（普通の Shift キー）の組み合わせ**を
扱わなければならないため。

```
親指シフト … NICOLA の同時打鍵。同側シフト / クロスシフトの 2 種
小指シフト … 普通の Shift キー。QMK のレイヤーとは独立に modifier として効く
```

#### 意図: 英数モードの場合 (`is_nicola == false`)

素直な割当。

| 打鍵 | 出力 |
|---|---|
| 同側シフト | `1`〜`0` / `F1`〜`F12` |
| クロスシフト | `Shift+1`〜（`!` `@` …） / `Shift+F1`〜 |

クロスシフトのときだけ Shift を足す → `invert_pinky_shift = eisu_cross_shift`

#### 意図: かなモードの場合 (`is_nicola == true`)

**かなモード中に小指シフトを押すと、一時的に英数入力になる**（IME の通常動作）。
この状態で `NG_E_*`（英数キー）が来るということは、**既に小指シフトが押されている**ことを意味する。

このとき「親指シフト同時打鍵で `1` を打ったら、素直に `1` が出てほしい」というのが設計意図。
しかし小指シフトが押されたままなので、何もしないと `Shift+1` = `!` になってしまう。
そこで**小指シフトを打ち消す**ために反転する。

| 打鍵 | 意図した出力 | 反転 |
|---|---|---|
| 小指シフト + 同側シフト | `1`（Shift を打ち消す） | **する** |
| 小指シフト + クロスシフト | `!`（Shift を活かす） | しない |

→ `invert_pinky_shift = !eisu_cross_shift`

例: 小指 Shift を押しながら「右親指 + U」を同時打鍵 → `F7` キー（＝カタカナ変換）が入力される。

#### 実装

上記 2 つを `(eisu_cross_shift != is_nicola)` という **XOR 1 行**で兼ねている。
動作は意図通りだが、**読み解くのに前提知識が要りすぎる。読みにくさの主因。**

書き直し時は英数モード / かなモードを分けて明示的に書くこと。

```c
/* 書き直しの方針（例） */
if (is_nicola) {
    /* かなモード: 小指シフト押下中に英数キー。同側なら小指シフトを打ち消す */
    invert_pinky_shift = !eisu_cross_shift;
} else {
    /* 英数モード: クロスシフトで Shift+n を出す */
    invert_pinky_shift = eisu_cross_shift;
}
```

#### 📌 未決: そもそもこの反転が要るのか

**かなモード側の反転は、単なる使用感の問題であって必然ではない。**

普通の IME でも、かなモード中に Shift を押しながら英字を打てば**大文字**になる。
つまり「小指シフトを押している以上、記号が出るのが自然」とも言える。
その立場に立てば、かなモード側の反転（`invert_pinky_shift = !eisu_cross_shift`）は不要で、
英数モードと同じ規則（`= eisu_cross_shift`）に統一できる。

* **反転する（現行）**: 小指シフト押下中でも親指同時打鍵の数字は素直に `1` が出る。一貫性より実用
* **反転しない**: 小指シフトは常に Shift として効く。規則が単純になり、実装が 1 行で済む

> **書き直し時に決めること。** 現行の挙動を保つなら上の分岐をそのまま実装、
> 統一するなら `invert_pinky_shift = eisu_cross_shift` の 1 行になり `is_nicola` 依存が消える。

### 5-4. かなキー側の反転（英数キーとは別の話）

`NG_E_*` ではない通常のかなキーにも、限定的な反転がある。

```c
if (nicola_o_key == NG_SHFTL) {
    switch (nicola_m_key) {
      case NG_LBRC: case NG_RBRC: case NG_SLSH:
        invert_pinky_shift = true;   // "_" "+" "?" を出すため
    }
}
```

左親指シフト + `[` `]` `/` のときだけ Shift を足して `_` `+` `?` を出す。
これは出力テーブルに直接 `Shift 付きキーコード` を書けば済む話で、
反転機構を使う必要はない。**書き直し時はテーブル側に吸収する。**

---

## 6. 出力テーブルの構造 — 書き直しの最大の対象

`case NG_*` が **371 個**。ほぼ同じ表が **4 回**書かれている。

| 関数 | 内容 |
|---|---|
| `nicola_m_press()` | 単独打鍵の `register_code` 表 |
| `nicola_m_release()` | 同じ表の `unregister_code` 版 |
| `nicola_om_press()` | 同時打鍵（左親指 / 右親指の 2 表）の `register_code` 版 |
| `nicola_om_release()` | 同じ表の `unregister_code` 版 |

1091 行のうち **6〜7 割がこの重複**。

### 提案する形

```c
typedef struct {
    uint16_t ng;          // NG_* キーコード
    uint8_t  out[3];      // 送出するキーコード列（0 終端。最大 3 = "xyo", "xtu" 用）
} nicola_entry_t;

static const nicola_entry_t nicola_table_plain[]  PROGMEM = { … };  // 単独
static const nicola_entry_t nicola_table_shftl[]  PROGMEM = { … };  // 左親指同時
static const nicola_entry_t nicola_table_shftr[]  PROGMEM = { … };  // 右親指同時
```

`register` と `unregister` を引数で切り替えれば press/release の重複が消える。
**1091 行 → 200 行台**になる見込み。

---

## 7. `S6_OO`（親指 2 つの同時打鍵）— 廃止

* 追加: `e65f145a67` (2026-01-20) "thumb shift arrow key and thumb-thumb combo"
* 削除: `5e855c7b57` (2026-02-15, `nishimaki` 枝) "replace kana on off keys"
* `users/nicola`（旧世代）には**最初から存在しない**

用途は「左親指→右親指でかな ON、右親指→左親指でかな OFF」。
`S3_O` で 80ms 以内に**別の**親指キーが押されると `S6_OO` に入り、
前の O を `o2` に退避して 2 キーの組み合わせで判定する。
M キーが続いた場合は `t1 = o_time - o2_time` / `t2 = now - o_time` の 3 キー判定を行う。

**結論: 廃止する。** 実際にはあまり使わなかったため。
かな ON/OFF は専用キー（`KC_EISU` など）に割り当てる。

> 判断の根拠は「機能として不要」であって「`nishimaki` で削除されたから」ではない。
> 5 状態版のほうが歴史が長く枯れている（`users/nicola` は一貫して 5 状態）。

廃止に伴い削除できるもの: `nicola_o2_key` / `nicola_o2_time` / `nicola_o2_pressed` /
`nicola_oo_pressed` / `nicola_o2_press` / `nicola_o2_release` / `nicola_oo_press` / `nicola_oo_release`

---

## 8. 書き直しに向けた指摘事項

| # | 問題 | 対策 |
|---|---|---|
| 1 | 出力テーブルが 4 回重複（全体の 6〜7 割） | テーブル駆動化（第 6 節）。**最優先** |
| 2 | 状態ごとに専用関数が生える設計 | `m/o/om` × `press/release` で 6 関数。`S6_OO` 追加時に 10 関数に膨れて破綻しかけた。状態→アクションを表で持つ |
| 3 | `IF_TIMEOUT()` の適用漏れ 2 箇所 | 割り込み方式に一本化し、ポーリング分岐を削除 |
| 4 | `nicola_release_guard()` への依存 | 状態機械が正しければ不要。削除を目指す |
| 5 | `invert_pinky_shift` の XOR 1 行 | 英数モード / かなモードを分けて明示的に書く。**かなモード側の反転を残すか統一するかは未決**（第 5-3 節） |
| 6 | AVR TIMER1 直叩き (`key_duration.c`) | QMK の `defer_exec()` / `extend_deferred_exec()` へ。MCU 非依存になり `BACKLIGHT_ENABLE = no` 制約も外れる |
| 7 | カーソルキーが左右どちらの手にも属さない | `is_cross_shift()` が常に false。意図か漏れか要判断 |
| 8 | `S6_OO` 関連の変数・関数が残存 | 廃止に伴い削除（第 7 節） |
| 9 | 3 キー判定の `t1`/`t2` が状態ごとに別の意味 | `S4_MO` と `S5_OM` で参照する時刻が入れ替わる。共通の「直前の打鍵」「その前の打鍵」に抽象化する |
| 10 | かなキー側の限定反転（`_` `+` `?`） | 反転機構ではなく出力テーブルに Shift 付きキーコードとして吸収する（第 5-4 節） |

### 書き直しで壊してはいけないもの

第 0 節の設計原則。特に:

* **`tap_code()` を使わない。** `register_code()` / `unregister_code()` を物理キーの press/release に厳密に対応させる
* 「なあああああ」とリピートする挙動は**仕様**。修正対象ではない

### 廃止するもの

| 対象 | 理由 |
|---|---|
| `users/nicola/` 一式 | `nicola4r` が上位互換。TS69 は keymap 側ガードで同じ挙動になる |
| `jtu.c`（343行, JIS/US 変換） | TS69 keymap で既にコメントアウト済み。`fb60a5f035` (2021-04) の判断が生きている |
| `NG_1`〜`NG_0`, `NG_MINS`, `NG_EQL` | **新方式に全面乗り換え。** 数字・記号は親指同側シフトで 2 行目から、`Shift+数字` はクロスシフトで出す。TS69 の英数レイヤーは既に素の `KC_*` なので移行作業は発生しない |
| `SS_ALNUM()` マクロ | 上記に伴い不要（`send_string` 廃止済みのため使用箇所も消える） |
