/**
 * routes/r2sync.js - Cloudflare R2 同步核心模块
 *
 * 日志风格与 backup.sh 保持一致: [R2] 前缀 + 中文描述。
 * uploadToR2 使用流式上传，支持大文件 (100MB+)。
 * 历史壁纸清理: 保留最近 5 张，自动删除旧文件。
 */
const fs = require('fs');
const path = require('path');
const config = require('../config');

let s3 = null, PutCmd = null, GetCmd = null, HeadCmd = null, DeleteCmd = null, ListCmd = null;
const { accountId, accessKeyId, secretAccessKey, bucketName, publicDomain } = config.r2;
const r2Ready = !!(accountId && accessKeyId && secretAccessKey && bucketName);

if (r2Ready) {
  try {
    const sdk = require('@aws-sdk/client-s3');
    s3 = new sdk.S3Client({ region:'auto', endpoint:`https://${accountId}.r2.cloudflarestorage.com`, credentials:{accessKeyId,secretAccessKey} });
    PutCmd = sdk.PutObjectCommand;
    GetCmd = sdk.GetObjectCommand;
    HeadCmd = sdk.HeadObjectCommand;
    DeleteCmd = sdk.DeleteObjectCommand;
    ListCmd = sdk.ListObjectsV2Command;
    console.log('[R2] Cloudflare R2 已连接, Bucket:', bucketName);
  } catch(e) { console.warn('[R2] @aws-sdk/client-s3 未安装，R2 同步已禁用'); }
} else {
  console.log('[R2] 未检测到 R2 环境变量，仅使用本地存储');
}

function isR2Enabled() { return !!(s3 && r2Ready); }

function getR2PublicUrl(r2Key) {
  if (!publicDomain) return null;
  let d = publicDomain; if (d.endsWith('/')) d = d.slice(0,-1);
  return `${d}/${r2Key}`;
}

/**
 * 流式上传本地文件到 R2，支持大文件 (80MB+)
 * 使用 createReadStream 而非 readFileSync，避免内存爆炸
 */
async function uploadToR2(localPath, r2Key, mimeType) {
  if (!isR2Enabled()) return null;
  try {
    const fileStream = fs.createReadStream(localPath);
    const fileSize = fs.statSync(localPath).size;
    await s3.send(new PutCmd({
      Bucket: bucketName,
      Key: r2Key,
      Body: fileStream,
      ContentLength: fileSize,
      ContentType: mimeType || 'application/octet-stream',
    }));
    const sizeMB = (fileSize / 1024 / 1024).toFixed(1);
    console.log(`[R2] 已上传: ${r2Key} (${sizeMB}MB)`);
    return getR2PublicUrl(r2Key);
  } catch(e) {
    console.error(`[R2] 上传失败 ${r2Key}:`, e.message);
    return null;
  }
}

async function downloadFromR2(r2Key, localPath) {
  if (!isR2Enabled()) return false;
  try {
    const resp = await s3.send(new GetCmd({ Bucket:bucketName, Key:r2Key }));
    const chunks = []; for await (const c of resp.Body) chunks.push(c);
    const dir = path.dirname(localPath);
    if (!fs.existsSync(dir)) fs.mkdirSync(dir,{recursive:true});
    fs.writeFileSync(localPath, Buffer.concat(chunks));
    console.log(`[R2] 已拉取: ${r2Key}`);
    return true;
  } catch(e) { if(e.name!=='NoSuchKey') console.error(`[R2] 拉取失败 ${r2Key}:`,e.message); return false; }
}

async function getETag(r2Key) {
  if (!isR2Enabled()) return null;
  try {
    const resp = await s3.send(new HeadCmd({ Bucket:bucketName, Key:r2Key }));
    return resp.ETag || null;
  } catch(e) { return null; }
}

async function existsOnR2(r2Key) {
  if (!isR2Enabled()) return false;
  try { await s3.send(new HeadCmd({Bucket:bucketName,Key:r2Key})); return true; } catch{ return false; }
}

async function deleteFromR2(r2Key) {
  if (!isR2Enabled()) return false;
  try { await s3.send(new DeleteCmd({Bucket:bucketName,Key:r2Key})); console.log(`[R2] 已删除: ${r2Key}`); return true; }
  catch(e) { console.error(`[R2] 删除失败 ${r2Key}:`,e.message); return false; }
}

/**
 * 列出指定前缀的所有对象，按 LastModified 降序排列
 */
async function listByPrefix(prefix) {
  if (!isR2Enabled() || !ListCmd) return [];
  try {
    const resp = await s3.send(new ListCmd({ Bucket:bucketName, Prefix:prefix }));
    const items = (resp.Contents || []).map(obj => ({
      key: obj.Key,
      lastModified: obj.LastModified,
      size: obj.Size,
      etag: obj.ETag
    }));
    items.sort((a, b) => new Date(b.lastModified) - new Date(a.lastModified));
    return items;
  } catch(e) { console.error('[R2] 列出对象失败:', e.message); return []; }
}

/**
 * 清理历史壁纸，保留最近 keepCount 张
 * @param {string} prefix  R2 前缀，如 "uploads/bg_admin_wallpaper_"
 * @param {number} keepCount  保留数量，默认 5
 */
async function cleanupOldWallpapers(prefix, keepCount = 5) {
  if (!isR2Enabled()) return;
  try {
    const items = await listByPrefix(prefix);
    if (items.length <= keepCount) {
      console.log(`[R2] 壁纸清理: 当前 ${items.length} 个文件，未超过上限 ${keepCount}，无需清理`);
      return;
    }
    const toDelete = items.slice(keepCount);
    console.log(`[R2] 壁纸清理: 共 ${items.length} 个文件，保留最新 ${keepCount} 个，删除 ${toDelete.length} 个旧文件...`);
    for (const obj of toDelete) {
      await deleteFromR2(obj.key);
    }
    console.log(`[R2] 壁纸清理完成，已删除 ${toDelete.length} 个历史文件`);
  } catch(e) {
    console.error('[R2] 壁纸清理异常:', e.message);
  }
}

// =================================================================
// 壁纸同步轮询
// =================================================================
const UPLOAD_DIR = config.storage.uploadDir;
const CHECK_INTERVAL = parseInt(process.env.BACKUP_INTERVAL) || 30;
let lastSyncedBgUrl = null;

function startWallpaperSync(db) {
  if (!isR2Enabled()) return;
  console.log(`[R2] 启动壁纸同步监控 (检查频率: ${CHECK_INTERVAL}s, 与数据库同步一致)...`);

  setInterval(async () => {
    try {
      const bgUrl = await new Promise((resolve) => {
        db.get("SELECT value FROM settings WHERE key='background'", (err, row) => {
          resolve(row ? row.value : '');
        });
      });
      if (!bgUrl) return;

      let domain = publicDomain || '';
      if (domain.endsWith('/')) domain = domain.slice(0, -1);
      if (!domain || !bgUrl.startsWith(domain)) return;

      // 数据库中的 URL 未变化，跳过 (幂等性)
      if (bgUrl === lastSyncedBgUrl) return;

      const r2Key = bgUrl.replace(domain + '/', '');
      const fileName = path.basename(r2Key);
      const localPath = path.join(UPLOAD_DIR, fileName);

      // 本地已存在同名文件，跳过下载
      if (fs.existsSync(localPath)) {
        lastSyncedBgUrl = bgUrl;
        return;
      }

      console.log(`[R2] 检测到壁纸更新: ${fileName}, 正在拉取...`);
      const ok = await downloadFromR2(r2Key, localPath);

      if (ok) {
        lastSyncedBgUrl = bgUrl;
        console.log(`[R2] 壁纸同步完成: ${fileName}`);
      } else {
        console.warn(`[R2] 壁纸拉取失败: ${fileName}, 保留旧文件，下次重试`);
      }
    } catch (e) {
      console.error('[R2] 壁纸同步异常:', e.message);
    }
  }, CHECK_INTERVAL * 1000);
}

module.exports = {
  isR2Enabled, getR2PublicUrl, uploadToR2, downloadFromR2,
  getETag, existsOnR2, deleteFromR2,
  listByPrefix, cleanupOldWallpapers, startWallpaperSync
};
