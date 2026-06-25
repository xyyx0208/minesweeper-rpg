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
- [x] pipeline-workflow 集成
- [x] .gitignore + Git 初始化
- [x] GitHub 仓库 + CI 工作流
- [x] settings.json 注册

### 后续开发步骤
1. 复制扫雷 Demo 代码到本工程
2. 新增 `rpg_manager.gd`
3. 修改 `main_menu.gd` 增加 RPG 入口
4. 修改 `game_state.gd` 增加 rpg_mode
5. 修改 `game_manager.gd` 集成 RPG 钩子
6. 测试验证
