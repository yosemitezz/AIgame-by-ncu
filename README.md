# Bellkeep: Shattered Refrain

原创 Godot 4.7 横版 2D 像素闯关首章。新代码与程序逐帧像素占位，不使用旧项目代码、Blender 渲染或商业资产。最终美术/UI 可由 Cursor 独立替换。

## 启动

双击 `play.cmd`，或运行 `./run.ps1`。也可用 Godot 4.7 打开 `project.godot` 后按 F6/F5。启动脚本自动寻找 D 盘的便携 Godot，或以 `./run.ps1 -Godot <Godot executable>` 指定。

原生画面 800×450（默认窗口 1600×900），整数倍缩放与最近邻采样。启动器把日志、用户数据和缓存目录指向项目旁的忽略目录 `.local/`。无外部音频或资源下载。

## 首章内容与操作

教学教堂 → 上层悬链书库 / 下层淤水墓廊 → 门与回环捷径 → 余烬神龛检查点 → 精英守门战 → 钟楼 Boss → 叙事渐黑与重开。六类小怪、十一处遭遇，保留探索碎片和可返回支路。击败精英后会补满血，重试点前移至Boss门前。检查点在本次运行/重试中保留，退出游戏后不保存。

- A/D 或左右方向键：移动；SPACE：跳跃 / 连续空中跳跃；W/S 或上下方向键：攀爬；S：离开链条时蹲下；E：门与机关。
- 双击同一方向（W/A/S/D 或方向键，间隔不超过 0.25 秒）：四向闪避。位移 0.17 秒，各方向独立冷却 0.42 秒，无敌 0.23 秒；使用实体碰撞，不能穿墙或穿地板。
- J/Z/鼠标左键：三连击；按下左 SHIFT：0.16 秒接触格挡 / 弹刀。右 SHIFT 不触发。按住不会延长窗口；金色弹幕接触后反射，近战按真实交刃判定。
- R：从最近检查点重开；F5：全新旅程；ESC：暂停；M：音乐静音。

Boss有追击、冲刺换位、近战、扇形、环形和落雨弹幕。固定段的起手只在拍点触发；随机段达到血量门槛后等完整乐句结束再推进，否则继续循环；休息段双方禁伤并清除旧弹与旧攻击；终段才解除最后的血量封印。漏拍从不直接扣血。

主 Boss 默认使用 `data/full_song_timeline.json` 的完整谱面：203 BPM、+245ms，复用已存在的 `boss_attack/audio/if_infinity.ogg`。用户已确认该选定音轨公开使用；歌曲单独归属，不属于项目 MIT 原创素材。`data/music_timeline.json` 保留原创合成曲供开发回归。详见 [全曲与重鼓说明](docs/full-song-runtime.md)。

## 验证与视觉审查

运行 `./tools/verify.ps1`：无头导入、关卡/接触弹刀/胜负重开集成检查、音乐合同检查、短启动烟测。检查退出码和错误文本。`tools/capture_review.gd` 只捕获固定场景截图；`tools/build_pixel_placeholders.py` 生成原创像素占位与接触表（需 Pillow）。验证日志及截图保存到忽略的 `artifacts/`，无人工或自动通关试玩。

美术和手感仍是首个功能版本，尚未经用户实际试玩校准；可替换占位图不宣称为最终美术。

## Cursor 并行工作

先读 [COLLABORATION.md](COLLABORATION.md) 与 [美术/UI接口](docs/art-ui-contract.md)。用独立目录和 `cursor/art-ui` 分支；从最新逻辑分支同步接口后再编辑。已存在的分支或未提交改动先检查并保留，不强制重置。

Cursor负责最终 `assets/art/`、`assets/vfx/`、`ui/` 外观；战斗和音乐脚本通过信号传数据。不要跨所有权边界覆盖文件。团队未直接连接或向 Cursor 发送消息。

保留原有 MIT LICENSE。新原创代码、像素占位与合成占位音乐适用仓库许可证。详见 [关卡设计](docs/level-design.md) 和 [实现记录](docs/implementation-notes.md)。

## 美术 / UI 预览（cursor/art-ui）

像素美术与界面在 `assets/art`、`assets/vfx`、`assets/ui`、`ui/` 中独立维护，与玩法互不覆盖。可单独查看的展示场景：`scenes/showcase_hub.tscn`（在 Godot 编辑器中打开后按 F6 运行）。交接说明见 [docs/art/HANDOFF.md](docs/art/HANDOFF.md)，美术方向见 [docs/art/ART_DIRECTION.md](docs/art/ART_DIRECTION.md)。

当前战斗修订已整合到同一个 play.cmd 入口：三连阶段逐帧动作、命中确认取消、角色局部停顿、像素刀弧与限量残影。F2 可关闭镜头冲击。验证记录见 docs/combat-feel-validation.md；开源改编来源见 THIRD_PARTY_NOTICES.md。

弹刀/Boss反馈修订已接同一入口：左 SHIFT 架刀，真实交刃触发反震和渐变流光，三点架势破架；紫色标记霸体招可弹但续段继续，珊瑚 X 冲刺需闪避。普通命中/弹刀/破架分级震屏，F2 可关闭。黑底白边像素中英状态栏仅显示已实现状态。详见 docs/parry-validation.md。


## Unified main project milestone

This integrate/vfx-primary checkout is the selected main project. Start the root play.cmd (not boss_attack/play.cmd). The real main scene now includes the lower flooded crypt, upper archive, climb chains, working doors and a return shortcut. Native viewport is 800x450 with a 1600x900 default window and nearest integer scaling.

Controls: A/D or arrows move; Space jumps; W/up and S/down climb; S/down crouches away from a chain; E opens doors; double-tap WASD/arrows dodges; J/Z/left click attacks; left Shift opens the contact-parry window (right Shift is unbound); Tab maps; Escape pauses; R retries; F5 restarts; F2 toggles camera motion, F3 toggles background speed accents, M mutes.

The newer long-limb hero, infinite air jumps, light wings, angular effects, heavy impact and layered original sounds are preserved. Shared sword envelopes now reach 180/204/228 logical pixels, with swept geometry and world occlusion. The original pixel katana Boss family is integrated with current reaction-state fallbacks. See docs/main-project-migration.md.

Run tools/verify_main.ps1 for bounded migration checks after the normal Godot import. The final friend PR3 action plans now run in the main Boss: four normal, four accelerated, random square/diamond X/+ and four geometric laser formations. The original boss_attack subproject is retained unchanged, and the main full-song configuration now reuses its existing selected OGG without adding another copy.


## Authored Boss and enemy cast milestone

The main Boss calls the friend planners through the existing MusicDirector, contact-parry/posture rules and one damage authority. The six enemy kinds are bone sentry, water wisp, armored elite, lantern cleric, chain jailer and winged imp; eleven encounters introduce them across the dungeon, with delayed finite barrages, readable gaps, occlusion and room gates.192 original native-pixel cells and their editable generator are in presentation/enemy_frames and tools/generate_enemy_cast.py.

Validation: the19-check unified migration suite passed, followed by the203BPM configuration3/0, music30/0 and startup checks. Main Boss runtime62/0, authored logic86/0, source-chart audit14/0, enemy cast90/0 and enemy visual859/0. The large visual count mostly checks individual frame bounds and anchors; visual taste and difficulty remain for the user to play. Those checks describe the earlier generated-score milestone. The full-song milestone below replaces that runtime default and adds the heavy-beat lane; see docs/friend-handoff-compatibility.md for the remaining design differences. No exported package or full-song latency claim is made.

Full-song milestone: the main encounter defaults to the existing selected OGG and complete 203 BPM/+245 ms chart. The left heavy lane previews two seconds and judges ±125 ms for feedback only; real defense still requires contact. See docs/full-song-runtime.md and THIRD_PARTY_NOTICES.md.
