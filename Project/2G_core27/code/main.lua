--         ┌─┐       ┌─┐
--      ┌──┘ ┴───────┘ ┴──┐
--      │                 │
--      │       ───       │
--      │  ─┬┘       └┬─  │
--      │                 │
--      │       ─┴─       │
--      │                 │
--      └───┐         ┌───┘
--          │         │
--          │         │
--          │         │
--          │         └──────────────┐
--          │     神兽保佑                       │
--          │                        ├─┐
--          │         ＮＯ    ＢＵＧ       ┌─┘
--          │                        │
--          └─┐  ┐  ┌───────┬──┐  ┌──┘
--            │ ─┤ ─┤       │ ─┤ ─┤
--            └──┴──┘       └──┴──┘

MODULE_TYPE = "Air202"
PROJECT = "YQJ27"
VERSION = "1.0.8"
PRODUCT_KEY = "bpRyE77QKhHGd7urLkSioC3tHYYRctFw"
require"sys"
require"common"
require"pm"
require"body"
require"update"

sys.init(0,0)

sys.run()

--90s一次回收内存垃圾
collectgarbage("setpause", 90)
