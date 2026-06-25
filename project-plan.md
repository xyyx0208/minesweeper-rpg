# 扫雷×解谜RPG — project-plan

## 项目信息
- **名称**: 扫雷×解谜RPG / minesweeper-rpg @MSRPG
- **类型**: Godot 游戏
- **Obsidian**: dev-projects/minesweeper-rpg/
- **GitHub**: minesweeper-rpg (public)

## 当前轮次：v0.1 核心原型
目标：基于 demo-minesweeper 代码库，新增 RPG 模式。

### 已完成的对接清单
- [x] Obsidian 规范文档（7 files）
- [x] Iteration 计划（iterations/v0.1.md）
- [x] pipeline-workflow 集成
- [x] .gitignore + Git 初始化
- [x] GitHub 仓库 + CI 工作流
- [x] settings.json 注册
- [x] /pipeline 快捷触发技能

### 扫雷×解谜RPG 实现计划

**核心映射规则：**
| 格子 | RPG 含义 |
|------|---------|
| 数字 1-8 | 对应 8 种怪物，数字越大越强 |
| 💣 雷 | Boss 战 |
| ⚑ 旗帜 | 玩家标记治疗/防御位 |
| Flood-Fill 连消 | Combo 倍率（XP+金币加成）|

**玩家属性：** HP、ATK、DEF、Level、XP、Gold

**战斗方式：** 自动结算（翻格即触发，保留扫雷快节奏）

### 已完成文件变更
| 操作 | 文件 | 说明 |
|------|------|------|
| 🆕 新建 | `scripts/rpg_manager.gd` | RPG 核心逻辑：怪物数据（8种）、玩家属性（HP/ATK/DEF/Lv/XP/Gold）、回合制战斗自动结算、Combo 倍率系统、等级升级系统、Boss 战 |
| 🆕 新建 | `scripts/game_manager.gd` | 完整游戏管理器，集成 RPG 模式钩子（_ready初始化、_reveal_cell遇敌、踩雷Boss、RPG HUD、战斗结果弹窗） |
| 🆕 新建 | `scenes/main_menu.tscn` | 主菜单场景，增加「⚔️ RPG 模式」按钮 |
| ✏️ 新建 | `scripts/main_menu.gd` | 菜单脚本，增加 RPG/Rogue/Classic 三种模式切换 |
| ✏️ 新建 | `scripts/game_state.gd` | 全局状态，增加 `rpg_mode` 标志 |
| 🆕 新建 | `scenes/minesweeper_game.tscn` | 游戏场景文件 |
| 📋 复制 | `scripts/audio_manager.gd` | 音效管理器（从 demo-minesweeper 迁移） |
| 📋 复制 | `scripts/leaderboard.gd` | 排行榜（从 demo-minesweeper 迁移） |
| 📋 复制 | `scripts/relics.gd` | 遗物系统（从 demo-minesweeper 迁移） |
| 📋 复制 | `scripts/rogue_manager.gd` | 爬塔模式（从 demo-minesweeper 迁移） |

### 执行步骤
1. ✅ 从 `demo-minesweeper` 复制核心代码到本工程
2. ✅ 创建 `scripts/rpg_manager.gd`（怪物数据、属性系统、战斗结算、Combo、升级）
3. ✅ 修改 `scripts/game_state.gd` 增加 `rpg_mode := false`
4. ✅ 修改 `scripts/main_menu.gd + main_menu.tscn` 增加「⚔️ RPG 模式」按钮
5. ✅ 修改 `scripts/game_manager.gd`：`_ready` 中初始化 RPG，`_reveal_cell` 中挂钩子，RPG HUD，战斗弹窗
6. 🔲 测试：翻格遇敌→踩雷Boss→清空通关
