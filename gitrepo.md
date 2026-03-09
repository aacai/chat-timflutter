# Git 仓库管理说明

## 仓库配置

- **主仓库（origin）**: `https://gitee.com/grainbud/chat-timflutter`
- **上游仓库（upstream）**: `https://github.com/TencentCloud/chat-demo-flutter`
- **当前分支**: `mycustom-feature`

## 从开源仓库更新代码

### 1. 获取上游仓库最新代码

```bash
git fetch upstream
```

### 2. 合并上游仓库的更新

切换到目标分支并合并：

```bash
git checkout mycustom-feature
git merge upstream/main
```

如果有冲突，解决冲突后：

```bash
git add <resolved-files>
git commit
```

### 3. 推送到 Gitee 仓库

```bash
git push origin mycustom-feature
```

## 日常开发流程

### 提交代码

```bash
git add <files>
git commit -m "提交信息"
git push origin mycustom-feature
```

### 查看远程仓库配置

```bash
git remote -v
```

### 查看分支状态

```bash
git status
git branch -a
```

## 注意事项

1. **定期同步上游代码**：建议每周至少同步一次上游仓库，以保持代码更新。

2. **合并前备份**：在合并上游代码前，确保当前工作区干净，或创建临时备份分支：
   ```bash
   git branch backup-mycustom-feature
   ```

3. **处理冲突**：
   - 合并冲突时，仔细检查每个冲突点
   - 优先保留上游的代码更新
   - 确保自定义功能不受影响

4. **提交规范**：
   - 提交信息清晰描述变更内容
   - 小步提交，便于回溯和审查

5. **推送前检查**：
   ```bash
   git log --oneline
   git diff origin/mycustom-feature
   ```

6. **强制推送警告**：
   - 避免使用 `git push -f`，除非确定需要
   - 强制推送会覆盖远程历史，可能导致代码丢失

## 常见问题

### 如何只查看上游更新而不合并？

```bash
git fetch upstream
git log upstream/main --oneline
```

### 如何回退合并？

```bash
git reset --hard HEAD~1
```

### 如何重新同步到上游最新版本？

```bash
git fetch upstream
git reset --hard upstream/main
git push origin mycustom-feature -f
```
⚠️ 注意：此操作会丢弃本地所有自定义提交，谨慎使用！
