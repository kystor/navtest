#!/bin/bash
# -----------------------------------------------------------------------------
# auto_backup.sh - 自动同步脚本 (SQL 文本版 + 热重载触发)
# -----------------------------------------------------------------------------

# ================= 时区设置 =================
export TZ='Asia/Shanghai'

# ================= 配置区域 =================

# 1. 监控源文件
SOURCE_FILE="/home/container/nav-Item/database/nav.db"
SOURCE_DIR=$(dirname "$SOURCE_FILE")
# 自动推导应用根目录 (假设 database 的上一级就是项目根目录)
APP_ROOT=$(dirname "$SOURCE_DIR")

# 2. 备份配置
BACKUP_DIR="/home/container/nav-backup-local"
SQL_FILE="nav_data.sql"          # 🟢 [特征1] 同步 SQL 文本
TRIGGER_FILE="$APP_ROOT/.restart_trigger" # 🟢 [特征2] 定义重启信号文件

# 3. GitHub 仓库信息
GITHUB_USER="GitHub用户名"
GITHUB_REPO="GitHub仓库名"
GITHUB_EMAIL="bot@nav.backup"
GITHUB_NAME="NavBackupBot"

# ★★★ 请在此处填入你的 Token ★★★
GITHUB_TOKEN=""

# 4. 组合仓库地址
GIT_URL="https://${GITHUB_USER}:${GITHUB_TOKEN}@github.com/${GITHUB_USER}/${GITHUB_REPO}.git"

# 5. 检查频率 (秒)
CHECK_INTERVAL=10

# =========================================================

# --- 辅助函数：权限修复 ---
fix_permissions() {
    if [ -d "$SOURCE_DIR" ]; then chmod 777 "$SOURCE_DIR"; fi
    if [ -f "$SOURCE_FILE" ]; then chmod 666 "$SOURCE_FILE"; fi
    if [ -f "$TRIGGER_FILE" ]; then chmod 666 "$TRIGGER_FILE"; fi
}

# 🟢 核心功能 1: 导出 (DB -> SQL)
export_db_to_sql() {
    if ! command -v sqlite3 &> /dev/null; then
        echo "[错误] 未找到 sqlite3 命令！请先安装: apt install sqlite3"
        return 1
    fi
    sqlite3 "$SOURCE_FILE" .dump > "$BACKUP_DIR/$SQL_FILE"
}

# 🟢 核心功能 2: 还原 (SQL -> Temp DB -> Cat -> Live DB)
restore_db_from_sql() {
    echo "[$(date '+%H:%M:%S')] [还原] 正在从 SQL 重建数据库..."
    TEMP_DB="/tmp/nav_restore_$(date +%s).db"
    
    if [ -f "$TEMP_DB" ]; then rm "$TEMP_DB"; fi
    
    if ! command -v sqlite3 &> /dev/null; then
        echo "[错误] 未找到 sqlite3 命令！无法执行还原。"
        return 1
    fi
    
    sqlite3 "$TEMP_DB" < "$BACKUP_DIR/$SQL_FILE"
    
    if [ -f "$TEMP_DB" ] && [ -s "$TEMP_DB" ]; then
        echo "[$(date '+%H:%M:%S')] [还原] 临时库构建成功，正在安全写入..."
        cat "$TEMP_DB" > "$SOURCE_FILE"
        rm "$TEMP_DB"
        fix_permissions
        echo "[$(date '+%H:%M:%S')] [成功] 数据库已还原。"
        
        # 🟢 [特征3] 关键: 摸一下触发文件，通知 Node.js 重启
        echo "[$(date '+%H:%M:%S')] [触发] 更新重启信号: $TRIGGER_FILE"
        touch "$TRIGGER_FILE"
    else
        echo "[错误] SQL 转换失败或文件为空，跳过还原。"
    fi
}

# --- 初始化环境 ---
init_repo() {
    git config --global --add safe.directory "$BACKUP_DIR"

    if [ ! -d "$BACKUP_DIR" ]; then
        echo "[$(date '+%H:%M:%S')] [初始化] 正在克隆仓库..."
        git clone "$GIT_URL" "$BACKUP_DIR"
        
        if [ $? -ne 0 ]; then
            echo "[错误] 无法克隆仓库，请检查 Token！"
            exit 1
        fi
        
        cd "$BACKUP_DIR" || exit
        git config user.email "$GITHUB_EMAIL"
        git config user.name "$GITHUB_NAME"

        if [ -f "$SQL_FILE" ]; then
             echo "[$(date '+%H:%M:%S')] [初始化] 检测到云端 SQL 备份，准备恢复..."
             cd ..
             restore_db_from_sql
             cd "$BACKUP_DIR" || exit
        else
            echo "[$(date '+%H:%M:%S')] [初始化] 云端无备份，使用本地数据初始化。"
        fi
        cd ..
    fi
    
    if [ ! -f "$TRIGGER_FILE" ]; then touch "$TRIGGER_FILE"; fi
    fix_permissions
    echo "[$(date '+%H:%M:%S')] [启动] 服务就绪，监控中..."
}

# --- 核心监控循环 ---
monitor() {
    if [ -f "$SOURCE_FILE" ]; then
        LAST_TIME=$(stat -c %Y "$SOURCE_FILE")
    else
        LAST_TIME=0
    fi

    while true; do
        sleep "$CHECK_INTERVAL"
        
        # === 下行同步 ===
        cd "$BACKUP_DIR" || exit
        git fetch origin main > /dev/null 2>&1
        BEHIND_COUNT=$(git rev-list HEAD..origin/main --count 2>/dev/null)
        
        if [ "$BEHIND_COUNT" -gt 0 ] 2>/dev/null; then
            echo "[$(date '+%H:%M:%S')] [同步] 云端有更新，正在拉取..."
            git pull origin main --rebase
            
            if git diff HEAD@{1} HEAD --name-only | grep -q "$SQL_FILE"; then
                cd ..
                restore_db_from_sql
                cd "$BACKUP_DIR" || exit
                if [ -f "$SOURCE_FILE" ]; then LAST_TIME=$(stat -c %Y "$SOURCE_FILE"); fi
            fi
        fi
        cd .. 

        # === 上行同步 ===
        if [ ! -f "$SOURCE_FILE" ]; then continue; fi
        CURRENT_TIME=$(stat -c %Y "$SOURCE_FILE")

        if [ "$CURRENT_TIME" != "$LAST_TIME" ]; then
            sleep 2
            FINAL_TIME=$(stat -c %Y "$SOURCE_FILE")
            if [ "$FINAL_TIME" != "$CURRENT_TIME" ]; then continue; fi
            
            echo "[$(date '+%H:%M:%S')] [检测] 本地变化，生成 SQL 快照..."
            export_db_to_sql
            cd "$BACKUP_DIR" || exit
            
            if [ -f "nav.db" ]; then git rm --cached nav.db 2>/dev/null; rm nav.db 2>/dev/null; fi
            git add "$SQL_FILE"
            
            if [ -n "$(git status --porcelain)" ]; then
                git commit -m "自动同步: $(date '+%Y-%m-%d %H:%M:%S')"
                git push origin main
                if [ $? -eq 0 ]; then echo "[$(date '+%H:%M:%S')] [成功] 备份完成。"; fi
            else
                echo "[提示] 内容未变，跳过提交。"
            fi
            LAST_TIME=$FINAL_TIME
            cd ..
        fi
    done
}

init_repo
monitor
