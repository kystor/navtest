const express = require('express');
const cors = require('cors');
const path = require('path');
const fs = require('fs');
const config = require('./config'); // [新增] 引入配置文件
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

app.use('/uploads', express.static(path.join(__dirname, 'uploads')));

// [修改] 静态资源托管
// 关键点：添加 { index: false } 参数。
// 原因：如果不加这个，访问首页时 express 会直接返回未经修改的 index.html 文件，
// 只有禁用了默认的 index，请求才会继续往下走，进入我们自定义的替换逻辑。
app.use(express.static(path.join(__dirname, 'web/dist'), { index: false }));

// [新增] 定义处理 HTML 的核心函数
// 这个函数负责读取 index.html 文件，并将占位符替换为真正的标题
const sendIndexHtml = (res) => {
  const indexPath = path.join(__dirname, 'web/dist', 'index.html');
  
  fs.readFile(indexPath, 'utf8', (err, htmlData) => {
    if (err) {
      console.error('Error reading index.html:', err);
      return res.status(500).send('Server Error');
    }
    
    // 获取标题逻辑：
    // 1. 尝试从 config 中获取 (如果你在 config.js 里配置了)
    // 2. 尝试从环境变量直接获取
    // 3. 都没有则使用默认值 '我的导航'
    const siteTitle = (config.app && config.app.title) || process.env.SITE_TITLE || '我的导航';
    
    // 执行替换：将 HTML 中的 __SITE_TITLE__ 替换为变量值
    const renderedHtml = htmlData.replace('__SITE_TITLE__', siteTitle);
    
    // 发送处理后的 HTML 给浏览器
    res.send(renderedHtml);
  });
};

// [新增] 根路径路由
// 当用户访问首页 http://localhost:3000/ 时，执行替换逻辑
app.get('/', (req, res) => {
  sendIndexHtml(res);
});

// 前端路由兜底逻辑 (SPA应用必备)
// 防止刷新页面时 404，将非 API 请求重定向回 index.html
app.use((req, res, next) => {
  if (
    req.method === 'GET' &&
    !req.path.startsWith('/api') &&
    !req.path.startsWith('/uploads') &&
    !fs.existsSync(path.join(__dirname, 'web/dist', req.path))
  ) {
    // [修改] 这里不再直接 sendFile，而是调用 sendIndexHtml 进行替换后再发送
    sendIndexHtml(res);
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

// 获取配置的接口（用于前端 JS 获取标题来修改 document.title 或页脚）
app.get('/api/config', (req, res) => {
  res.json({
    // 优先使用 config 中的配置，如果没有则回退到环境变量
    title: (config.app && config.app.title) || process.env.SITE_TITLE || '我的导航'
  });
});

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
