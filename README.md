# ZCode-Deploy

ZCode 一键人格部署工具 — 把 system prompt 换成你自己的。

## 这是什么

ZCode 的 system prompt 由 `zcode.cjs` 内部的 `build()` 函数拼装。本工具通过修改该函数的四个注入点，把 system 层完整替换为外部文件 `人格.txt` 的内容。

部署后模型收到的 system 层：

```
system:   人格.txt 全文
messages: 正常对话
tools:    工具定义（不变）
```

不再包含产品预置的身份声明、上下文管理规则和日期提醒。

## 使用

1. 把你的人格写进 `人格.txt`（UTF-8）
2. 双击 `部署.bat`
3. 开新对话，生效

命令行方式：

```powershell
# 部署
powershell -ExecutionPolicy Bypass -File deploy.ps1 install

# 恢复原版
powershell -ExecutionPolicy Bypass -File deploy.ps1 restore

# 查看状态
powershell -ExecutionPolicy Bypass -File deploy.ps1 status
```

## 换人格

直接编辑 `人格.txt`，保存，开新对话生效。不需要重启，不需要重跑部署。

## 原理

| # | 修改点 | 作用 |
|---|--------|------|
| 1 | `Djo` 前缀置空 | 删除 CLI 身份声明 |
| 2 | `build()` 读外部文件 | system prompt 改为读 `人格.txt` |
| 3 | `Eut()` 读外部文件 | Agent Identity 片段同步替换 |
| 4 | `fre()` 返回 null | 移除日期提醒注入 |

详细分析见 `修改记录.md`。

## 验证

ZCode 的模型请求日志在 `~/.zcode/cli/rollout/model-io-*.jsonl`，可以直接检查 system 层内容。

## 注意

- ZCode 更新后补丁会被覆盖，重跑 `部署.bat` 即可
- 文件夹移动位置后需要重跑 `部署.bat`（路径写死在 cjs 里）
- `恢复.bat` 会还原代码但保留 `人格.txt`
- 仅修改本地安装的软件配置，用于个人定制

## 免责声明

本工具仅用于对本地安装的软件进行个人定制。请遵守 ZCode 服务条款，自行承担使用风险。