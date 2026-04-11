const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const config = require('./config');
const db = require('./db');
const authMiddleware = require('./routes/authMiddleware');
const r2 = require('./routes/r2sync');

const menuRoutes = require('./routes/menu');
const cardRoutes = require('./routes/card');
const uploadRoutes = require('./routes/upload');
const authRoutes = require('./routes/auth');
const adRoutes = require('./routes/ad');
const friendRoutes = require('./routes/friend');
const userRoutes = require('./routes/user');
const parseRoutes = require('./routes/parse');
const compression = require('compression');
const http = require('http');
const https = require('https');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT || 3000;
const UPLOAD_DIR = config.storage.uploadDir;

app.use(cors());
app.use(express.json({ limit: '1mb' }));
app.use(express.urlencoded({ extended: true, limit: '1mb' }));
app.use(compression());

// /uploads 静态服务 + R2 回源
app.use('/uploads', async (req, res, next) => {
  const localPath = path.join(UPLOAD_DIR, req.path);
  if (fs.existsSync(localPath)) return next();
  if (r2.isR2Enabled()) {
    const ok = await r2.downloadFromR2('uploads' + req.path, localPath);
    if (ok) return res.sendFile(localPath);
  }
  next();
}, express.static(UPLOAD_DIR));

app.use(express.static(path.join(__dirname, 'web/dist'), { index: false }));

const sendIndexHtml = (res) => {
  const indexPath = path.join(__dirname, 'web/dist', 'index.html');
  fs.readFile(indexPath, 'utf8', (err, htmlData) => {
    if (err) return res.status(500).send('Server Error');
    db.get("SELECT value FROM settings WHERE key='title'", (dbErr, row) => {
      const siteTitle = (row && row.value) ? row.value : ((config.app && config.app.title) || process.env.SITE_TITLE || '我的导航');
      res.send(htmlData.replace('__SITE_TITLE__', siteTitle));
    });
  });
};
app.get('/', (req, res) => sendIndexHtml(res));
app.use((req, res, next) => {
  if (req.method === 'GET' && !req.path.startsWith('/api') && !req.path.startsWith('/uploads') && !fs.existsSync(path.join(__dirname, 'web/dist', req.path))) sendIndexHtml(res);
  else next();
});

app.use('/api/menus', menuRoutes);
app.use('/api/cards', cardRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api', authRoutes);
app.use('/api/ads', adRoutes);
app.use('/api/friends', friendRoutes);
app.use('/api/users', userRoutes);
app.use('/api/parse-link', parseRoutes);

app.get('/api/r2/status', authMiddleware, (req, res) => {
  res.json({ enabled: r2.isR2Enabled(), bucket: config.r2.bucketName||null, publicDomain: config.r2.publicDomain||null });
});

// 网络壁纸代理 + R2 双写
app.get('/api/background', (req, res) => {
  const bgUrl = req.query.url;
  if (!bgUrl || !bgUrl.startsWith('http')) return res.status(404).send('未配置网络壁纸链接');
  if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  const urlHash = crypto.createHash('md5').update(bgUrl).digest('hex');
  let ext = '.jpg'; try { const e = path.extname(new URL(bgUrl).pathname); if(e) ext=e; } catch(e){}
  const fileName = `bg_${urlHash}${ext}`;
  const cachePath = path.join(UPLOAD_DIR, fileName);
  if (fs.existsSync(cachePath)) return res.redirect(`/uploads/${fileName}`);
  const client = bgUrl.startsWith('https') ? https : http;
  client.get(bgUrl, (response) => {
    if (response.statusCode === 200) {
      const file = fs.createWriteStream(cachePath);
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        r2.uploadToR2(cachePath, `uploads/${fileName}`, response.headers['content-type']||'image/jpeg').catch(()=>{});
        res.redirect(`/uploads/${fileName}`);
      });
    } else res.redirect(bgUrl);
  }).on('error', () => res.redirect(bgUrl));
});

// 图标代理 + R2 双写
app.get('/api/icon-proxy', async (req, res) => {
  const iconUrl = req.query.url;
  if (!iconUrl || !iconUrl.startsWith('http')) return res.status(400).send('无效图标链接');
  if (!fs.existsSync(UPLOAD_DIR)) fs.mkdirSync(UPLOAD_DIR, { recursive: true });
  const urlHash = crypto.createHash('md5').update(iconUrl).digest('hex');
  let ext = '.png'; try { const e = path.extname(new URL(iconUrl).pathname); if(e&&e.length<=5) ext=e; } catch(e){}
  const fileName = `icon_${urlHash}${ext}`;
  const cachePath = path.join(UPLOAD_DIR, fileName);
  const r2Key = `uploads/${fileName}`;
  if (fs.existsSync(cachePath)) return res.redirect(`/uploads/${fileName}`);
  if (r2.isR2Enabled()) { const ok = await r2.downloadFromR2(r2Key, cachePath); if(ok) return res.redirect(`/uploads/${fileName}`); }
  const client = iconUrl.startsWith('https') ? https : http;
  client.get(iconUrl, { timeout: 5000 }, (response) => {
    if (response.statusCode === 200) {
      const file = fs.createWriteStream(cachePath);
      response.pipe(file);
      file.on('finish', () => { file.close(); r2.uploadToR2(cachePath,r2Key,response.headers['content-type']||'image/png').catch(()=>{}); res.redirect(`/uploads/${fileName}`); });
    } else res.redirect(iconUrl);
  }).on('error', () => res.redirect(iconUrl));
});

// 配置接口
app.get('/api/config', (req, res) => {
  db.all("SELECT key, value FROM settings WHERE key IN ('background', 'title', 'bg_type')", (err, rows) => {
    let bgUrl='', titleStr='', bgType='auto';
    if(rows) rows.forEach(r => { if(r.key==='background')bgUrl=r.value; if(r.key==='title')titleStr=r.value; if(r.key==='bg_type')bgType=r.value; });
    if(!bgUrl) bgUrl=(config.app&&config.app.background)||process.env.BACKGROUND||'';
    if(!titleStr) titleStr=(config.app&&config.app.title)||process.env.SITE_TITLE||'我的导航';

    const isR2Url = config.r2.publicDomain && bgUrl.startsWith(config.r2.publicDomain);
    const isLocalPath = bgUrl.startsWith('/uploads/');
    const isVideo = bgUrl.toLowerCase().match(/\.(mp4|webm|ogg|mov|m4v|avi|mkv)(\?|$)/);

    if (!isR2Url && !isLocalPath && !isVideo && bgUrl && bgUrl.startsWith('http')) {
      bgUrl = '/api/background?url=' + encodeURIComponent(bgUrl);
    }

    res.json({ title:titleStr, background:bgUrl, bg_type:bgType, r2_enabled:r2.isR2Enabled() });
  });
});

// 配置保存
app.post('/api/config/settings', authMiddleware, (req, res) => {
  const { title, background, bg_type } = req.body;
  const updates = [];
  if(title!==undefined) updates.push({key:'title',value:title});
  if(background!==undefined) updates.push({key:'background',value:background});
  if(bg_type!==undefined) updates.push({key:'bg_type',value:bg_type});
  if(updates.length===0) return res.json({success:true});
  let completed=0, hasError=false;
  updates.forEach(item => {
    db.get("SELECT * FROM settings WHERE key=?", [item.key], (err, row) => {
      if(row) db.run("UPDATE settings SET value=? WHERE key=?", [item.value||'',item.key], done);
      else db.run("INSERT INTO settings (key, value) VALUES (?, ?)", [item.key,item.value||''], done);
    });
  });
  function done(err) { if(err)hasError=true; completed++; if(completed===updates.length){if(hasError)return res.status(500).json({error:'部分设置保存失败'});res.json({success:true});} }
});

// 启动服务器，设置超时适应大文件上传
const server = app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running at http://0.0.0.0:${PORT}`);
  console.log(`[R2] 同步状态: ${r2.isR2Enabled() ? '已启用' : '未启用 (配置 R2 环境变量即可开启)'}`);
  r2.startWallpaperSync(db);
});
// 10 分钟超时，避免大文件上传时 Bad Gateway
server.timeout = 600000;
server.keepAliveTimeout = 620000;
server.headersTimeout = 630000;
