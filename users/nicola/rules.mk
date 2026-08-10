SRC += nicola.c \
       nicola_table.c

# タイムアウト判定に defer_exec() を使う。
# 旧実装は AVR の TIMER1 を直接叩いていたため BACKLIGHT_ENABLE = no の
# 制約があったが、こちらは MCU 非依存でその制約もない。
DEFERRED_EXEC_ENABLE = yes
