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
- 收藏、最近查看、只显示未完成。
- 成就奖励预览：坐骑、宠物、玩具、外观、住宅装饰和普通物品。
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

```text
EasyAchievement/
├── EasyAchievement.toc       # 加载顺序、版本和插件元数据
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
        ├── Tooltip.lua          # 成就提示信息
        ├── RewardPanel.lua      # 奖励及模型预览面板
        ├── Cards.lua            # 成就卡片和浮窗
        ├── Favorites.lua        # 收藏与最近查看面板
        ├── Window.lua           # 主窗口和持久化界面状态
        ├── Navigator.lua        # 小地图导航与视口控制
        ├── Tree.lua             # 成就树节点、连线和布局呈现
        ├── Search.lua           # 面包屑、搜索和上下文菜单
        └── Launcher.lua         # 启动图标、事件和设置注册
```

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
