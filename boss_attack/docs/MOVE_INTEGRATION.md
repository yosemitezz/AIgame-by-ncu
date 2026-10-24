# 招式接入说明

## 稳定槽位

槽位 ID 与显示名固定为：

| ID | 显示名 | 类型 |
| --- | --- | --- |
| `move_1` | 招式1 | normal |
| `move_2` | 招式2 | normal |
| `move_3` | 招式3 | normal |
| `move_4` | 招式4 | normal |
| `fixed_1` | 固定段招式1 | fixed |
| `fixed_2` | 固定段招式2 | fixed |

具体招式接入时修改 `data/boss_moves.json`，不要在不同脚本里新增散落的时间常量。

## 字段

```json
{
  "move_slot": "move_1",
  "display_name": "招式1",
  "segment_type": "normal",
  "enabled": true,
  "pattern_id": "spread",
  "phase_indices": [3, 4],
  "start_beat": 301.0,
  "end_beat": 385.0,
  "parameters": {
    "count": 5,
    "speed": 280.0,
    "spread_degrees": 55.0,
    "damage": 6.0,
    "ttl_seconds": 1.2
  }
}
```

- `phase_indices` 为空时不限阶段。
- `start_beat` / `end_beat` 为 `null` 时不限 beat。
- normal 槽位由 `BossMoveSlots.select_for_timing_group()` 在 timing group 时机选择。
- fixed 槽位通过 `BossMoveSlots.request_slot()` 显式触发；固定段安排仍等待用户谱面。
- 已提供通用弹幕原语 `aimed`、`spread`、`radial`、`rain`，未绑定任何招式槽位。
- 未识别 `pattern_id` 只记录警告，不伪造攻击。

## 激光

ChartParser 在激光 `beat` 产生预警数据，在 `endbeat` 产生伤害事件。弹幕系统支持横/纵两种基础路径，但当前参考配置使用临时横向训练路径。最终方向、持续、重叠和同时覆盖规则应由用户招式设计指定；不得从 `column` 推导方向。

可在 `ProjectileSystem.configure_pending_laser()` 中为单个激光配置方向。事件源索引由 `ChartParser` 保留。

## 替换贴图

在 Godot Inspector 打开 `data/asset_slots.tres`，设置：

- `boss_texture`
- `player_texture`
- `boss_projectile_texture`
- `laser_warning_texture`
- `arena_background_texture`
- `heavy_marker_texture`

无贴图时程序绘制高对比几何占位。替换贴图不改变碰撞半径、谱面时间、输入窗口或招式逻辑。

