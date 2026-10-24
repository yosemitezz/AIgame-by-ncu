# Refrain: Boss Attack Contract

这是一个从空主干新建的独立 Godot 4.7 Boss 节奏战工程，不导入、不读取、也不复制 `game2`。当前实现完成交接文档中的通用底座：

- 严格从 `note` 数组读取谱面；BPM 和 Offset 由战斗配置提供。
- 保留每条定时 note、唯一时间、timing group、重鼓、激光和自动阶段的统计。
- 音乐、左侧重鼓落下轨、判定窗和输入共用同一音乐时钟。
- Godot 不支持 FLAC 运行时流，因此用 FFmpeg/`libvorbis` 将用户提供的 `IF = Infinity.flac` 转为 234 kb/s OGG；判定仍以同一音乐起点和谱面配置为准。
- A/D/S/W 双击闪避互相独立，支持短暂无敌；左 Shift 进入重鼓格挡判定。
- 招式1–4、固定段招式1已经按用户设计启用；固定段招式2继续留空。
- 等间隔普通 note 按两 note 一组拆分；加速段再把两组组成四 note 动作句。
- 同拍存在两个带 `endbeat` 的 laser note 时，触发固定段招式1的正方体双对角线激光。
- 正方体姿态随机为正方形或菱形，分别产生 X 型或 + 型无限延伸激光。
- 四套全屏激光几何：收束菱形、平行阶梯、井字切割、旋转包围。
- Boss、玩家、弹幕、背景贴图通过 `BattleAssetSlots` 替换，不影响时间轴与碰撞。

## 启动

需要 Godot 4.7。双击 `play.cmd`，或：

```powershell
.\run.ps1
.\run.ps1 -Godot "D:\Godot\Godot_v4.7-stable_win64_console.exe"
```

原生画面为 640×360，默认窗口 1280×720，整数缩放到桌面。

## 操作

- 双击 A / D / S / W：向左 / 右 / 下 / 上闪避。
- 左 Shift：重鼓格挡；判定为拍点前后各 125ms。
- J 或鼠标左键：大剑攻击。
- R：重开；Esc：退出。

## 当前样本统计

`data/if_infinity.chart.json` 是本次用户提供的谱面：

| 项目 | 数量 |
| --- | ---: |
| note 原始记录 | 1172 |
| 可定时 note | 1171 |
| 唯一精确 beat key | 862 |
| timing group | 703 |
| 重鼓组 | 107 |
| 激光实例 | 230 |
| 双 note 等间隔组 | 315 |
| 动作句 | 228 |
| 同拍双 laser 固定招触发 | 24 |
| 普通激光几何组 | 48 |
| 自动战斗阶段 | 21 |

这些数量由解析器实时计算，没有写死为游戏逻辑。

## 数据入口

- `data/battle_config.json`：音乐、谱面、BPM、Offset、阶段间隔、判定窗、战斗基线和临时训练配置。
- `data/boss_moves.json`：普通四招、加速四组动作句、固定招式1、激光几何参数；固定招式2保持空置。
- `data/asset_slots.tres`：可替换贴图槽位。
- `data/if_infinity.chart.json`：参考谱面。
- `audio/if_infinity.ogg`：从用户提供 FLAC 转码的游戏运行时音乐。

具体招式的接入约定见 [docs/MOVE_INTEGRATION.md](docs/MOVE_INTEGRATION.md)。

## 验证

```powershell
.\tools\verify.ps1
```

验证包含无头导入、谱面合同、双击/重鼓判定、六槽位完整性、调度事件和短启动烟测。结果写入被忽略的 `artifacts/`。

## 资源状态

Boss 模型、招式贴图和最终特效贴图均保持为空槽。当前只以程序几何体验证碰撞、时序和可躲空间。格挡成功后的生命/硬直数值仍未锁定。

