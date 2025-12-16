#!/bin/bash
# -----------------------------------------------------------------------------
# backup.sh - 自动备份脚本 (双向同步 + 时区优化版)
# -----------------------------------------------------------------------------

# ================= 配置区域 =================

# 1. 监控源文件 (容器内正在运行的数据库路径)
SOURCE_FILE="${DB_PATH:-/app/database/nav.db}"

# 2. 备份目录 (Git 仓库的存储位置)
BACKUP_DIR="/app/nav-backup-repo"

# 3. GitHub 身份信息
GITHUB_EMAIL="${GITHUB_EMAIL:-bot@nav.backup}"
GITHUB_NAME="${GITHUB_NAME:-NavBackupBot}"
# GITHUB_TOKEN 由环境变量传入

# 4. 仓库地址解析逻辑 (支持完整 URL 输入)
if [ -n "$BACKUP_REPO_URL" ]; then
    # 去除 https://github.com/ 前缀
    TEMP_URL="${BACKUP_REPO_URL#https://github.com/}"
    TEMP_URL="${TEMP_URL#http://github.com/}"
    # 去除结尾的 .git 和 /
    TEMP_URL="${TEMP_URL%.git}"
    TEMP_URL="${TEMP_URL%/}"
    
    # 提取用户名和仓库名
    GITHUB_USER=$(echo "$TEMP_URL" | cut -d'/' -f1)
    GITHUB_REPO=$(echo "$TEMP_URL" | cut -d'/' -f2)
    echo "[配置] 解析 URL -> 用户: $GITHUB_USER, 仓库: $GITHUB_REPO"
else
    # 兼容旧配置方式
    GITHUB_USER="${GITHUB_USER}"
    GITHUB_REPO="${GITHUB_REPO}"
fi

# 5. 安全性检查
if [ -z "$GITHUB_TOKEN" ]; then
    echo "[错误] 未检测到 GITHUB_TOKEN，脚本无法运行！"
    exit 1
fi

if [ -z "$GITHUB_USER" ] || [ -z "$GITHUB_REPO" ]; then
    echo "[错误] 无法获取仓库信息！请检查环境变量。"
    exit 1
fi

# 6. 组合带 Token 的 URL
GIT_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"

# 7. 检查频率 (秒)
CHECK_INTERVAL="${BACKUP_INTERVAL:-10}"

# =============================================================

# --- 初始化环境 ---
init_repo() {
    # 解决 Git 安全目录报错
    git config --global --add safe.directory "$BACKUP_DIR"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "[同步服务] 初始化：正在克隆仓库..."
        git clone "$GIT_URL" "$BACKUP_DIR"
        
        if [ $? -ne 0 ]; then
            echo "[同步服务-错误] 克隆失败，请检查 Token 或 URL。"
            exit 1
        fi
        
        cd "$BACKUP_DIR" || exit
        git config user.email "$GITHUB_EMAIL"
        git config user.name "$GITHUB_NAME"
        
        # 第一次启动：如果云端有数据，强制覆盖本地空数据（云端优先）
        if [ -f "nav.db" ]; then
             echo "[同步服务] 初始加载：检测到云端有 nav.db，覆盖本地..."
             cp -f nav.db "$SOURCE_FILE"
        fi
        
        cd ..
    fi
}

# --- 核心监控循环 ---
monitor() {
    echo "[同步服务] 启动双向监控，频率: ${CHECK_INTERVAL}s"
    
    # 初始化时间戳记录
    if [ -f "$SOURCE_FILE" ]; then
        LAST_TIME=$(stat -c %Y "$SOURCE_FILE")
    else
        LAST_TIME=0
    fi

    while true; do
        sleep "$CHECK_INTERVAL"
        
        # =======================================================
        # 阶段一：下行同步 (Cloud -> Local)
        # 目的：检查你在别的地方（比如公司电脑）是不是改了数据
        # =======================================================
        cd "$BACKUP_DIR" || exit
        
        # 获取远程最新状态 (但不合并)
        git fetch origin main > /dev/null 2>&1
        
        # 检查本地分支是否落后于远程 (通过 Hash 链计算)
        BEHIND_COUNT=$(git rev-list HEAD..origin/main --count)
        
        if [ "$BEHIND_COUNT" -gt 0 ]; then
            echo "[同步服务] 检测到云端有 $BEHIND_COUNT 个新提交，正在拉取..."
            
            # 拉取代码
            git pull origin main --rebase
            
            # 检查是否有数据库文件
            if [ -f "nav.db" ]; then
                echo "[同步服务] 云端更新 -> 覆盖本地数据库"
                
                # 【关键操作】覆盖正在运行的数据库
                cp -f nav.db "$SOURCE_FILE"
                
                # 【关键逻辑】覆盖后，更新 LAST_TIME，防止脚本误判为“本地修改”
                LAST_TIME=$(stat -c %Y "$SOURCE_FILE")
            fi
        fi
        
        cd .. # 回到 /app

        # =======================================================
        # 阶段二：上行同步 (Local -> Cloud)
        # 目的：检查你是不是在当前网页里加了新卡片
        # =======================================================
        
        if [ ! -f "$SOURCE_FILE" ]; then
            continue
        fi

        CURRENT_TIME=$(stat -c %Y "$SOURCE_FILE")

        # 只有当时间戳发生变化，且不是刚才云端覆盖导致的
        if [ "$CURRENT_TIME" != "$LAST_TIME" ]; then
            echo "[同步服务] 检测到本地数据库变化..."
            
            # 等待写入稳定 (防止数据库正在写入时复制)
            sleep 2
            FINAL_TIME=$(stat -c %Y "$SOURCE_FILE")
            
            # 如果还在变，跳过本次，等下次稳定了再备
            if [ "$FINAL_TIME" != "$CURRENT_TIME" ]; then continue; fi
            
            # 开始备份
            cd "$BACKUP_DIR" || exit
            
            # 再次拉取防止冲突
            git pull origin main --rebase > /dev/null 2>&1
            
            # 复制本地 -> 仓库
            cp -f "$SOURCE_FILE" .
            
            # 提交检查：Git 会通过 Hash 对比内容，如果内容没变，不会产生提交
            if [ -n "$(git status --porcelain)" ]; then
                git add .
                
                # 这里会使用 Docker 设置好的上海时间
                CURRENT_DATE_LOG=$(date '+%Y-%m-%d %H:%M:%S')
                
                git commit -m "自动同步: $CURRENT_DATE_LOG"
                git push origin main
                
                if [ $? -eq 0 ]; then
                    echo "[同步服务] 本地更改 -> 已推送到云端 (时间: $CURRENT_DATE_LOG)"
                else
                    echo "[同步服务-错误] 推送失败。"
                fi
            else
                echo "[同步服务] 文件时间变了但内容没变 (Hash一致)，跳过提交。"
            fi
            
            # 更新基准时间
            LAST_TIME=$FINAL_TIME
            cd ..
        fi
    done
}

# --- 入口 ---
init_repo
monitor
