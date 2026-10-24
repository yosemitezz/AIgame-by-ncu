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

具体招式时间与参数集中在 `data/boss_moves.json`，运行时由 `BossAttackPlanner` 转成音乐时间轴动作。

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
- `normal_cycle` 按 `move_1` → `move_2` → `move_3` → `move_4` 循环。
- 加速段使用 `fast_cycle` 的四 note 动作句循环。
- 固定招式1由同拍至少两条带 `endbeat` 的 laser note 触发。
- 固定招式2继续禁用，不填充未知内容。

## 两 note 分组

`ChartParser` 在单个战斗阶段内寻找至少三个等间隔 timing group。最大连续等间隔序列从左到右拆成不重叠的两 note 组。若拍间隔不超过 1.01 拍，再合并相邻两组为四 note 动作句；更长间隔则以两 note 动作句触发普通四招。

## 激光

ChartParser 在激光 `beat` 产生预警数据，在 `endbeat` 产生伤害事件。方向只由激光几何规划器生成，不从 `column` 推导。

- `diamond`：四条斜线依次围出菱形区域。
- `parallel`：四条平行线形成走廊，相邻调用镜像。
- `grid`：左右竖线与上下横线形成井字安全区。
- `rotating`：四条不等位置斜线围出偏置安全区。

固定招式1的两条线从正方体中心产生：正方形姿态对应 X 型，菱形姿态对应 + 型。

## 替换贴图

在 Godot Inspector 打开 `data/asset_slots.tres`，设置：

- `boss_texture`
- `player_texture`
- `boss_projectile_texture`
- `laser_warning_texture`
- `arena_background_texture`
- `heavy_marker_texture`

无贴图时程序绘制高对比几何占位。替换贴图不改变碰撞半径、谱面时间、输入窗口或招式逻辑。

