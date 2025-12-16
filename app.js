const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
// 引入各个路由模块
const menuRoutes = require('./routes/menu');
const cardRoutes = require('./routes/card');
const uploadRoutes = require('./routes/upload');
const authRoutes = require('./routes/auth');
const adRoutes = require('./routes/ad');
const friendRoutes = require('./routes/friend');
const userRoutes = require('./routes/user');
const compression = require('compression');

const app = express();

// 1. 获取端口：Zeabur 会自动注入 PORT 环境变量，如果没有则使用 3000
const PORT = process.env.PORT || 3000;

app.use(cors());
app.use(express.json());
app.use(compression());

// 静态资源托管
app.use('/uploads', express.static(path.join(__dirname, 'uploads')));
app.use(express.static(path.join(__dirname, 'web/dist')));

// 前端路由兜底逻辑 (SPA应用必备)
// 防止刷新页面时 404，将非 API 请求重定向回 index.html
app.use((req, res, next) => {
  if (
    req.method === 'GET' &&
    !req.path.startsWith('/api') &&
    !req.path.startsWith('/uploads') &&
    !fs.existsSync(path.join(__dirname, 'web/dist', req.path))
  ) {
    res.sendFile(path.join(__dirname, 'web/dist', 'index.html'));
  } else {
    next();
  }
});

// 注册 API 路由
app.use('/api/menus', menuRoutes);
app.use('/api/cards', cardRoutes);
app.use('/api/upload', uploadRoutes);
app.use('/api', authRoutes);
app.use('/api/ads', adRoutes);
app.use('/api/friends', friendRoutes);
app.use('/api/users', userRoutes);

// ---------------------------------------------------------
// 核心修复部分：修改监听方式
// ---------------------------------------------------------

// 参数说明：
// 1. PORT: 端口号
// 2. '0.0.0.0': [重要] 显式指定监听所有网络接口，而不仅仅是 localhost
// 3. callback: 启动成功后的回调
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running at http://0.0.0.0:${PORT}`);
  console.log(`Zeabur Health Check should pass now.`);
});
