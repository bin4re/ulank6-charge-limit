# Changelog

## v0.1.0 (2026-11-24)

- 初始版本，基于 [gedulab/ulank6](https://github.com/gedulab/ulank6) `4ff601f9 add ndb`
- DTS：`ti,max-charge-voltage` 8700000 → 8240000（8.24V ≈ 80%）
- bq25700 驱动：
  - CV 复位序列（写 0 → 目标 → 恢复 ChargeCurrent）
  - 充电电流 clamp 到 1.472A（23×64mA）
  - 30s 轮询重写 Ichg/IIN/VINDPM
  - AC 插入重下发 CV + 限流
  - probe 清 `CHRG_INHIBIT` / `EN_HIZ`
- 本机实测：1472mA 恒流 → 8.24V CV → 平滑衰减 → ~80% 浮充；电量计真实；拔插自动续充
