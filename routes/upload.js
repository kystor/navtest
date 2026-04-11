const express = require('express');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const http = require('http');
const https = require('https');
const crypto = require('crypto');
const config = require('../config');
const r2 = require('./r2sync');
const db = require('../db');
const router = express.Router();

const UPLOAD_DIR = config.storage.uploadDir;
if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });

// =================================================================
// multer 配置: 支持大文件 (200MB)
// 壁纸文件名: bg_admin_wallpaper_<hash8>.ext (唯一命名)
// =================================================================
const storage = multer.diskStorage({
  destination: (req, file, cb) => cb(null, UPLOAD_DIR),
  filename: (req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.bin';
    if (req.query.type === 'wallpaper') {
      // 唯一命名: 时间戳 + 随机数生成 8 位 hash
      // 每次上传不同内容都会生成新文件名，避免缓存问题
      const hash = crypto.createHash('md5').update(`${Date.now()}_${Math.random()}`).digest('hex').substring(0, 8);
      cb(null, `bg_admin_wallpaper_${hash}${ext}`);
    } else {
      cb(null, `upload_${Date.now()}_${Math.floor(Math.random()*1000)}${ext}`);
    }
  }
});
const upload = multer({
  storage,
  limits: { fileSize: 200 * 1024 * 1024 } // 200MB
});

function upsertSetting(key, value) {
  return new Promise((resolve) => {
    db.get("SELECT * FROM settings WHERE key=?", [key], (err, row) => {
      if (row) db.run("UPDATE settings SET value=? WHERE key=?", [value, key], () => resolve());
      else db.run("INSERT INTO settings (key, value) VALUES (?, ?)", [key, value], () => resolve());
    });
  });
}

function isVideoFile(file) {
  if (file.mimetype && file.mimetype.includes('video')) return true;
  if (/\.(mp4|webm|ogg|mov|m4v|avi|mkv)$/i.test(file.originalname)) return true;
  return false;
}

/**
 * 清理本地旧壁纸文件 (保留最近 keepCount 个)
 */
function cleanupLocalWallpapers(currentFileName, keepCount = 5) {
  try {
    const files = fs.readdirSync(UPLOAD_DIR)
      .filter(f => f.startsWith('bg_admin_wallpaper_'))
      .map(f => ({ name: f, time: fs.statSync(path.join(UPLOAD_DIR, f)).mtimeMs }))
      .sort((a, b) => b.time - a.time);
    if (files.length <= keepCount) return;
    const toDelete = files.slice(keepCount);
    toDelete.forEach(f => {
      try { fs.unlinkSync(path.join(UPLOAD_DIR, f.name)); console.log(`[清理] 已删除本地旧壁纸: ${f.name}`); }
      catch(e) {}
    });
  } catch(e) {}
}

// =================================================================
// 接口 1: 手动上传本地文件
// 流程: 本地存储 -> R2 上传 -> 更新数据库 -> 清理历史 -> 返回
// =================================================================
router.post('/', upload.any(), async (req, res) => {
  try {
    const file = req.files && req.files.length > 0 ? req.files[0] : null;
    if (!file) return res.status(400).json({ error: '没有获取到文件' });

    const localPath = path.join(UPLOAD_DIR, file.filename);
    const r2Key = `uploads/${file.filename}`;
    const type = isVideoFile(file) ? 'video' : 'image';
    const sizeMB = (file.size / 1024 / 1024).toFixed(1);

    console.log(`[上传] 收到文件: ${file.filename} (${sizeMB}MB, ${type})`);

    // 上传到 R2 (流式，支持大文件)
    const r2Url = await r2.uploadToR2(localPath, r2Key, file.mimetype);
    const finalUrl = r2Url || `/uploads/${file.filename}`;

    // 壁纸上传: 同步更新数据库
    if (req.query.type === 'wallpaper') {
      await upsertSetting('background', finalUrl);
      await upsertSetting('bg_type', type);
      console.log(`[上传] 壁纸已更新: ${file.filename} -> ${finalUrl}`);

      // 清理 R2 历史壁纸 (保留最近 5 张)
      r2.cleanupOldWallpapers('uploads/bg_admin_wallpaper_', 5).catch(() => {});
      // 清理本地历史壁纸
      cleanupLocalWallpapers(file.filename, 5);
    }

    res.json({
      filename: file.originalname,
      url: finalUrl,
      r2_url: r2Url || null,
      r2_synced: !!r2Url,
      type
    });
  } catch (error) {
    console.error('[上传] 失败:', error.message);
    // 区分文件大小限制错误
    if (error.code === 'LIMIT_FILE_SIZE') {
      return res.status(413).json({ error: '文件超过 200MB 限制' });
    }
    res.status(500).json({ error: '上传失败: ' + error.message });
  }
});

// =================================================================
// 接口 2: 下载网络资源并缓存
// =================================================================
router.post('/fetch-and-cache', async (req, res) => {
  const { url } = req.body;
  if (!url) return res.status(400).json({ error: '缺少链接参数' });
  try {
    const response = await new Promise((resolve, reject) => {
      const client = url.startsWith('https') ? https : http;
      client.get(url, { timeout: 30000 }, (resp) => {
        if (resp.statusCode !== 200) { reject(new Error(`HTTP ${resp.statusCode}`)); return; }
        const chunks = [];
        resp.on('data', chunk => chunks.push(chunk));
        resp.on('end', () => resolve({ buffer: Buffer.concat(chunks), contentType: resp.headers['content-type']||'application/octet-stream' }));
        resp.on('error', reject);
      }).on('error', reject);
    });
    const contentType = response.contentType;
    const isVideo = contentType.includes('video') || /\.(mp4|webm|ogg|mov|m4v|avi|mkv)(\?|$)/i.test(url);
    const type = isVideo ? 'video' : 'image';
    const urlHash = crypto.createHash('md5').update(url).digest('hex');
    let ext = '.bin';
    try { const e = path.extname(new URL(url).pathname); if(e&&e.length<=6)ext=e; }
    catch(e) {
      const m = {'image/jpeg':'.jpg','image/png':'.png','image/webp':'.webp','image/gif':'.gif',
        'video/mp4':'.mp4','video/webm':'.webm','video/quicktime':'.mov','video/x-m4v':'.m4v'};
      ext = m[contentType] || '.bin';
    }
    const fileName = `bg_cached_${urlHash}${ext}`;
    const filePath = path.join(UPLOAD_DIR, fileName);
    fs.writeFileSync(filePath, response.buffer);

    const r2Key = `uploads/${fileName}`;
    const r2Url = await r2.uploadToR2(filePath, r2Key, contentType);
    const finalUrl = r2Url || `/uploads/${fileName}`;

    console.log(`[缓存] 网络资源已缓存: ${fileName} (${type})`);
    res.json({ success: true, url: finalUrl, r2_url: r2Url||null, r2_synced: !!r2Url, type, recommended_type: type });
  } catch (error) {
    console.error('[缓存] 网络资源失败:', error.message);
    res.status(500).json({ error: '缓存失败: ' + error.message });
  }
});

module.exports = router;
