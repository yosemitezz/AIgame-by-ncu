# Bellkeep: Shattered Refrain

## Current checked game - 2026-10-25

Start the root `play.cmd`. The project opens the pixel title/settings screen and enters the complete dungeon. The current Boss room follows aerial combat and offers a five-tap audio calibration; contact parry is still required, with no missed-beat damage. The reference score and its four normal/four fast families, cubes and grouped laser volleys run through one music transport.

This version includes distinct three-sword actions, staged wing flight and historical trails, the red-haired katana Boss, and the physical flying-eye chapter. Kill corruption, once-only near-death rescue, earned Boss victory and the separate red narrative-death ending are integrated. Story identity/backstory remains undefined; dialogue is an editable draft based on the user's original plot. E/Enter continues, Backspace skips; after the ending Enter/R returns with completion preserved, V replays, and F5 starts over.

Validation: 60 bounded check groups passed, including 44 actual chapter-integration assertions, title/settings/quit, calibration, contact geometry and full-song coverage (2994 expected and actual shots for the current reference chart). This is not a hand-feel or full-song listening verdict. The old 04:25-05:03 climax pressure-blink is not yet adapted to the new aerial room; ordinary aerial repositioning is a different behavior.

`tools/build_windows.ps1` builds a versioned Windows portable PCK with the installed Godot runtime under ignored `exports/`; prior deliveries are preserved. No export templates, installer or external release is installed/published by this workflow. Build manifests identify the exact source commit and file hashes.


Godot 4.7 纯 2D 像素横版动作游戏：西方奇幻地牢、灵活跑跳、三剑连斩、接触弹刀与谱面 Boss 战。

## 当前本地精修

开发分支 `feat/polish-story-local-20261025`，仍从根目录 `play.cmd` 运行。本轮先完成分阶段展翼、连跳后持剑、三剑独特造型、按真实历史位置的移动残影，以及更清晰的主剑路。F2 控制镜头反馈，F3 控制速度拖尾与局部模糊。[飞行与持剑](docs/flight-polish.md) · [移动效果](docs/movement-trail.md) · [刀光精修](docs/attack-polish.md)。

剧情接入另作后续本地里程碑，当前不上传远端。

## 本地红发 Boss 与展翼冲刺版

当前本地分支 `feat/boss-redhair-local-20261024`，在三武器版上优化高挑红发太刀 Boss，并将主角空中翻滚改为展翼推进。Boss 刀刃判定与既有操作、位移规则保持原规格。入口仍是根目录 `play.cmd`，此次仅本地保存。

[Boss 外观与判定保护](docs/boss-redhair.md) · [展翼动作说明](docs/wing-flight.md)

## 本地三武器动作版

三武器基线分支 `feat/weapon-identities-local-20261024`：轻剑穿刺、第三段螺旋钻进；重剑三段劈砍、第三段释放真实剑气；双手剑前后圆斩。J 连按衔接，Q/K 或 1/2/3 切武器，左 Shift 格挡与方向双击闪避保持不变。此次只在本地保存，未推送 main。

[动作、范围与验证说明](docs/weapon-identities.md)

## 运行

双击**项目根目录 `play.cmd`**。本机主目录为 `D:\code\aigame-ncu-integrate`；也可用 Godot 4.7 打开根目录 `project.godot` 后运行主场景。`boss_attack/` 是保留的朋友原始子工程，不是当前完整游戏入口。

## 操作

| 操作 | 按键 |
| --- | --- |
| 左右移动 | A/D 或左右方向键 |
| 跳跃 / 现有光翼连跳 | 空格；松开可短跳 |
| 攀爬 / 蹲下 | W/S 或上下方向键；离开梯链时 S 蹲下 |
| 四向闪避 | 分别双击 W/A/S/D 或方向键，双击间隔 250ms |
| 攻击 / 三连斩 | J、Z 或鼠标左键 |
| 接触弹刀 | **左 Shift**；右 Shift 不绑定 |
| 换剑 | Q 下一把、K 上一把；1 轻剑、2 重剑、3 双手剑 |
| 门 / 传送门 | E；传送需再次独立按 E 确认，3 秒未确认会取消 |
| 地图 / 暂停 | Tab / Esc |
| 重试 / 新旅程 | R / F5 |
| 震屏 / 速度装饰 / 静音 | F2 / F3 / M |

跑速 232、闪避速度 520 逻辑像素/秒。移动支持跳跃缓冲、土狼时间、可变跳高、空中转向和合理的攻击恢复取消。交替方向仍可闪避移动，但不会无限续上无敌。

## 关卡与房间

地牢教学 → 平台与支路探索 → 灰烬检查点 → 精英 → 门户（约 x2560）→ **独立 Boss 决斗厅**。击败精英后 E 查看门户，再次 E 确认；黑幕期间卸载旧地形、小怪和弹幕，新房准备好才启动音乐与 Boss。

Boss 房战败按 R 直接在该房重试，保留本次运行中的地牢解锁记录；胜利后可用 E 确认返回地牢。F5 清空本次运行进度，从地牢起点重来。当前检查点是会话内保存，尚未新增跨进程磁盘存档。

## 音乐与战斗

默认选定音轨和完整谱面为 203 BPM / +245ms。原曲已按用户确认复用仓库已有文件，未声称音乐为原创或 MIT 资产。固定段、血量门槛与乐句循环、休息段禁伤，以及朋友普通/加速/方块 X/+ 和四类激光设计均保留；`fixed_2` 仍为空。

已移除源冲刺在释放拍之后再次等待蓄势帧的问题。`data/audio_calibration.json` 可配置额外设备延迟补偿，默认 0ms；不修改基础谱面偏移。逻辑测试不等于声卡、蓝牙或实际听感校准。重鼓提示仅作反馈，防御始终依据真实攻击接触和弹刀时间窗，不按漏拍扣血。

## 验证与协作

导入后运行 `tools/verify_main.ps1`。检查包含移动、接触伤害、弹刀破架、全曲事件计数、实际房间清理和重试、三剑切换及短启动。当前没有配置 GitHub Actions 工作流；远端未提供 CI 状态，验收依据本地有界测试和静态画面，手感由用户试玩。

实现与调参见 [移动和节奏](docs/response-mobility.md)、[独立房间](docs/room-transfer.md)、[Boss 攻防](docs/boss-duel-runtime.md)。协作边界见 [COLLABORATION.md](COLLABORATION.md)，素材许可见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。原 `LICENSE` 与所有贡献历史保留。

<details>
<summary>历史开发记录（以下可能包含已更新的路径、按键和旧验收结果）</summary>

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

</details>

> just for fun
> enjoy it XDDD
