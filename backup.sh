#!/bin/bash
# -----------------------------------------------------------------------------
# backup.sh - 自动备份脚本 (支持 URL 解析版)
# -----------------------------------------------------------------------------

# ================= 配置区域 =================

# 1. 监控源文件 (容器内的固定路径)
SOURCE_FILE="${DB_PATH:-/app/database/nav.db}"

# 2. 备份目录 (容器内的临时目录)
BACKUP_DIR="/app/nav-backup-repo"

# 3. GitHub 身份信息
GITHUB_EMAIL="${GITHUB_EMAIL:-bot@nav.backup}"
GITHUB_NAME="${GITHUB_NAME:-NavBackupBot}"
# 注意：GITHUB_TOKEN 必须由外部环境变量传入，脚本内不设置默认值以保证安全

# 4. 仓库地址解析逻辑 (核心修改)
# 用户可以通过 BACKUP_REPO_URL 传入完整地址，例如: https://github.com/kystor/navtest
# 也可以继续使用 GITHUB_USER 和 GITHUB_REPO 分别传入

if [ -n "$BACKUP_REPO_URL" ]; then
    # --- 逻辑 A: 用户传入了完整 URL，进行拆解 ---
    
    # 1. 去除协议头 (https://github.com/ 或 http://github.com/)
    # ${VAR#pattern} 是 Shell 的字符串截取语法，# 表示从左边删除匹配的部分
    TEMP_URL="${BACKUP_REPO_URL#https://github.com/}"
    TEMP_URL="${TEMP_URL#http://github.com/}"
    
    # 2. 去除结尾的 .git (如果用户复制的是 clone 地址)
    # % 表示从右边删除匹配的部分
    TEMP_URL="${TEMP_URL%.git}"
    
    # 3. 去除可能存在的末尾斜杠 /
    TEMP_URL="${TEMP_URL%/}"

    # 4. 提取用户名和仓库名
    # cut -d'/' -f1 表示以 / 为分隔符，取第 1 段
    GITHUB_USER=$(echo "$TEMP_URL" | cut -d'/' -f1)
    GITHUB_REPO=$(echo "$TEMP_URL" | cut -d'/' -f2)

    echo "[配置] 检测到 URL 变量，解析为 -> 用户: $GITHUB_USER, 仓库: $GITHUB_REPO"
else
    # --- 逻辑 B: 用户未传入 URL，尝试读取单独变量 ---
    # 这里不再设置默认值，如果变量为空就是空
    GITHUB_USER="${GITHUB_USER}"
    GITHUB_REPO="${GITHUB_REPO}"
fi

# 5. 安全性检查 (必填项验证)
# -z 检查字符串长度是否为 0
if [ -z "$GITHUB_TOKEN" ]; then
    echo "[错误] 未检测到 GITHUB_TOKEN，请在环境变量中设置！"
    exit 1
fi

if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_REPO" ]; then
    echo "[错误] 无法获取仓库信息！请设置 BACKUP_REPO_URL 或 (GITHUB_USER 和 GITHUB_REPO)。"
    exit 1
fi

# 6. 组合带 Token 的最终推送地址
# 格式: https://用户名:Token@github.com/用户名/仓库名.git
GIT_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"

# 7. 检查频率 (秒)
CHECK_INTERVAL="${BACKUP_INTERVAL:-10}"

# =============================================================

# --- 初始化环境 ---
init_repo() {
    # 确保 Git 不过分提示安全目录问题
    git config --global --add safe.directory "$BACKUP_DIR"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "[备份服务] 初始化：正在克隆仓库 $GITHUB_USER/$GITHUB_REPO ..."
        
        # 使用带 Token 的 URL 进行克隆
        git clone "$GIT_URL" "$BACKUP_DIR"
        
        if [ $? -ne 0 ]; then
            echo "[备份服务-错误] 无法克隆仓库，请检查 URL 是否正确或 Token 权限！"
            echo "尝试访问的地址格式 (隐藏Token): https://github.com/$GITHUB_USER/$GITHUB_REPO.git"
            exit 1
        fi
        
        # 配置本地 Git 用户信息
        cd "$BACKUP_DIR" || exit
        git config user.email "$GITHUB_EMAIL"
        git config user.name "$GITHUB_NAME"
        cd ..
        echo "[备份服务] 初始化完成。"
    fi
}

# --- 核心监控循环 ---
monitor() {
    echo "[备份服务] 启动监控，频率: ${CHECK_INTERVAL}s"
    echo "[备份服务] 监控目标: $SOURCE_FILE"
    
    # 初始时间戳
    LAST_TIME=$(stat -c %Y "$SOURCE_FILE" 2>/dev/null)

    while true; do
        sleep "$CHECK_INTERVAL"

        if [ ! -f "$SOURCE_FILE" ]; then
            continue
        fi

        CURRENT_TIME=$(stat -c %Y "$SOURCE_FILE")

        if [ "$CURRENT_TIME" != "$LAST_TIME" ]; then
            echo "[备份服务] 检测到数据库变化..."
            
            # 等待写入稳定 (防止数据库正在写入时复制导致文件损坏)
            sleep 2
            FINAL_TIME=$(stat -c %Y "$SOURCE_FILE")
            
            if [ "$FINAL_TIME" != "$CURRENT_TIME" ]; then
                continue
            fi
            
            # 开始备份流程
            cd "$BACKUP_DIR" || exit

            # 1. 拉取最新代码 (防止多端操作导致冲突)
            # --rebase 保持提交记录整洁
            git pull origin main --rebase > /dev/null 2>&1

            # 2. 复制数据库文件过来
            cp -f "$SOURCE_FILE" .

            # 3. 提交并推送
            if [ -n "$(git status --porcelain)" ]; then
                git add .
                git commit -m "自动备份: $(date '+%Y-%m-%d %H:%M:%S')"
                git push origin main
                
                if [ $? -eq 0 ]; then
                    echo "[备份服务] 备份成功！已推送到 GitHub。"
                else
                    echo "[备份服务-错误] 推送失败。可能是网络问题或 Token 过期。"
                fi
            else
                echo "[备份服务] 文件时间戳变了但内容没变 (Git未检测到差异)。"
            fi

            # 更新基准时间
            LAST_TIME=$FINAL_TIME
            cd .. # 回到 /app
        fi
    done
}

# --- 入口 ---
init_repo
monitor
