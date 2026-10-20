# EasyAchievement

EasyAchievement 是从 LiteTools 中独立拆分出的《魔兽世界》正式服成就增强插件。

- 作者：Observer007
- 版本：1.0.0
- 客户端：12.1.5（TOC `120105`）
- 保存变量：`EasyAchievementDB`
- 可选依赖：All The Things（ATT）
- 图标：暴雪 Atlas `UI-Achievement-Shield-NoPoints`

## 主要功能

- 独立的成就树面板，支持搜索、缩放、自适应和小地图导航。
- 单成就卡片、子成就跳转、前进/后退历史。
- 顶部前进/后退恢复路径、类别上下文和视图状态；类别卡片左右切换只更新当前历史项。
- 面包屑保留本次进入路径，过长时通过省略菜单展开；返回类别列表恢复选中项及位置。
- 收藏、最近查看、只显示未完成。
- 成就奖励预览：坐骑、宠物、玩具、外观、住宅装饰和普通物品。
- 按奖励类别浏览成就，并按面板高度自动排列可拖动网格。
- 可拖动成就浮窗，多个浮窗按打开顺序向下堆叠，并支持独立面板卡片与浮窗缩放。
- 面板右上角以及成就树节点、卡片右键菜单均可打开 ATT 攻略。
- 右键启动图标可管理收藏与最近查看，并支持搜索、筛选和拖动排序。
- 所有窗口尺寸、位置、缩放、收藏和浏览状态都保存到账号级数据库。

## 安装与使用

1. 将 `EasyAchievement` 目录放入 `_retail_/Interface/AddOns/`。
2. 在角色选择页启用 EasyAchievement。
3. 进入游戏后，点击屏幕上的成就盾牌图标打开面板。
4. 鼠标移到盾牌图标上会展开快速搜索框。

LiteTools 中仍保留原成就模块作为回退。安装本插件后，建议在 LiteTools
中取消勾选“成就增强”，避免同时显示两套界面。

## 项目结构

开发后运行 `zsh Tools/sync_to_wow.sh` 同步到正式服。同步白名单仅包含
`EasyAchievement.toc` 和 `Config`、`Core`、`Data`、`Locales`、`Modules`
内的 Lua 文件；`Tests`、`Tools`、`Exports`、README 和 Git 元数据不进入游戏目录。

```text
EasyAchievement/
├── EasyAchievement.toc       # 加载顺序、版本和插件元数据
├── Data/
│   └── AchievementRewardDatabase.lua # 由 wago.tools DB2 表生成的奖励 ID
├── Config/
│   └── Defaults.lua             # 框体、树、卡片和搜索常量
├── Core/
│   ├── Database.lua             # SavedVariables、设置校验和事件路由
│   ├── AchievementData.lua      # 成就读取、数据清洗和状态容量控制
│   └── Anchors.lua              # 屏幕位置的保存与恢复
├── Locales/
│   ├── enUS.lua                 # 英文核心语言和所有文本的回退值
│   ├── zhCN.lua                 # 简体中文核心语言（完整覆盖）
│   └── zhTW.lua                 # 可选繁体中文覆盖（未覆盖键回退英文）
└── Modules/
    ├── AchievementTreeData.lua  # 成就关系索引、构树和过滤
    ├── AchievementRewards.lua   # 奖励识别与异步住宅目录索引
    ├── AchievementTreeLayout.lua # 可独立测试的树坐标计算
    ├── AchievementUI.lua        # 成就界面的插件私有共享环境
    └── Achievements/
        ├── Core.lua             # 公共状态、收藏栏和基础工具
        ├── Navigation.lua       # 浏览历史快照、视图恢复和成就路径
        ├── Tooltip.lua          # 成就提示信息
        ├── RewardPanel.lua      # 奖励及模型预览面板
        ├── Cards.lua            # 成就卡片和浮窗
        ├── Favorites.lua        # 收藏与最近查看面板
        ├── Window.lua           # 主窗口和持久化界面状态
        ├── Navigator.lua        # 小地图导航与视口控制
        ├── Tree.lua             # 成就树节点、连线和布局呈现
        ├── RewardCategories.lua # 奖励类别索引与成就网格
        ├── Search.lua           # 面包屑、搜索和上下文菜单
        └── Launcher.lua         # 启动图标、事件和设置注册
```

## 更新奖励数据库

插件优先读取 `Data/AchievementRewardDatabase.lua`。数据库使用 `schema=2` 的
紧凑数值格式：成就 ID 是表键，分类使用位掩码，正奖励 ID 表示成就表直接奖励，
负奖励 ID 表示推导奖励，0 表示尚未解析。业务模块统一通过
`Core/AchievementRewardDatabase.lua` 访问，不直接依赖压缩格式。分类页直接
读取生成结果，不再在游戏中重新解析全部奖励。类别综合 Achievement、Mount、
BattlePetSpecies、Toy、HouseDecor、ItemSparse、ItemEffect、
ItemXItemEffect、ItemModifiedAppearance、TransmogSet、TransmogSetItem 和
RetroactiveDecorReward 表的物品、法术、来源及名称关联；明确的本地化奖励类型
文本用于补足类别和头衔。数据库同时保存阵营限定成就的 `Faction`，插件按当前
角色阵营过滤联盟、部落的同名对应成就。数据库没有可用物品 ID 时，插件才使用
游戏 API 和现有的奖励文本识别作为降级处理。

预览所需的结构化关联也随表生成：`mountItems` 保存物品到坐骑 ID，
`petItems` 保存宠物种类、显示模型、场景和图标 ID，`decorItems` 保存装饰、
模型文件和场景 ID，`toyItems` 标记玩具，`appearanceItems` 保存外观来源 ID。
这些映射仅保留奖励涉及的物品，使物品缓存尚未加载时也能识别类型和准备模型。
名称和描述仍由当前客户端语言提供。未就绪的信息在可见面板内最多自动重试三次，
收藏和装饰目录更新后会重新刷新。

在插件目录运行以下命令，会自动选取 wago.tools 最新正式服 `wow` 构建，下载
英文与简体中文 DB2 表并重新生成数据库：

```bash
./Tools/update_reward_database.sh
```

也可以指定构建以便复现结果：

```bash
./Tools/update_reward_database.sh 12.1.5.70448
```

数据库下载和生成部分依赖 `zsh`、`curl` 和 Python 3。下载缓存及未解析报告位于
`Tools/.cache/<build>/`，不会打包进插件或提交到 Git。
生成逻辑回归测试可运行
`python3 -m unittest Tests/test_reward_database_builder.py`。

奖励数据库更新完成后，还会生成
`Exports/EasyAchievement_奖励成就.xlsx`。工作簿包含中文成就名称、描述、奖励
描述、直接与推导奖励 ID、奖励分类，以及 zhCN Achievement 表的其余字段。
如果已经有下载缓存，也可以只重新生成 Excel：

```bash
./Tools/update_reward_workbook.sh 12.1.5.70448
```

Excel 生成器使用 Node.js 和 `@oai/artifact-tool`。如果依赖不在 Codex 默认运行
目录，可通过 `ARTIFACT_NODE_MODULES` 指定包含 `@oai/artifact-tool` 的
`node_modules` 目录。

## 国际化扩展

`Locales/enUS.lua` 始终最先加载，它是所有语言的默认回退。英文和简体中文
是必须保持完整且格式占位符一致的核心语言；其他语言可以只覆盖部分文本。
添加新语言时：

1. 复制 `Locales/zhCN.lua` 并改为新的 Locale 名，例如 `deDE.lua`。
2. 将文件开头的 `GetLocale()` 判断改为目标 Locale。
3. 只覆盖需要翻译的 `L.KEY`；未覆盖的键自动使用英文。
4. 将语言文件加到 `EasyAchievement.toc` 的 `enUS.lua` 之后。

修改文本后运行 `lua Tests/locale_smoke.lua`，检查核心语言键、格式占位符
以及代码中的本地化引用。

## 给后续 Codex 会话的修改入口

- 公共界面状态：`Modules/Achievements/Core.lua`
- 主窗口：`Modules/Achievements/Window.lua`
- 树绘制：`Modules/Achievements/Tree.lua`
- 搜索与菜单：`Modules/Achievements/Search.lua`
- 启动图标与事件：`Modules/Achievements/Launcher.lua`
- 成就关系与过滤：`Modules/AchievementTreeData.lua`
- 奖励识别：`Modules/AchievementRewards.lua`
- 奖励数据库生成：`Tools/update_reward_database.sh`
- 树坐标计算：`Modules/AchievementTreeLayout.lua`
- 数据清洗与容量：`Core/AchievementData.lua`
- 界面尺寸、缩放范围：`Config/Defaults.lua`
- 翻译：`Locales/*.lua`
- 数据库与事件：`Core/Database.lua`
- 位置保存：`Core/Anchors.lua`
- 加载顺序或版本：`EasyAchievement.toc`

修改后建议执行：

```bash
# 在 EasyAchievement 的父目录执行
lua EasyAchievement/Tests/run.lua

# 或在 EasyAchievement 目录内逐项检查语法
luac -p Core/Database.lua
luac -p Core/Anchors.lua
luac -p Core/AchievementData.lua
luac -p Config/Defaults.lua
luac -p Locales/enUS.lua
luac -p Locales/zhCN.lua
luac -p Locales/zhTW.lua
luac -p Modules/AchievementTreeData.lua
luac -p Modules/AchievementRewards.lua
luac -p Modules/AchievementTreeLayout.lua
for file in Modules/Achievements/*.lua; do luac -p "$file"; done
```

## 开发注意事项

- 不要直接修改或 Hook 原生成就列表；本插件只使用自己的面板和右键菜单。
- 与战斗、副本相关的数据读取必须允许 API 返回 `nil` 或受限值。
- 暴雪 Atlas 名称在客户端升级后可能变动，新材质应保留回退样式。
- 新增保存项时使用 `Addon:RegisterSetting`，不要直接散落写入全局变量。
- 全局框体名使用 `EasyAchievement` 前缀，避免与其他插件冲突。
