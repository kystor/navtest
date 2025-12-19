// 引入 dotenv 库，用于读取 .env 文件中的环境变量
require('dotenv').config();

// 导出配置对象，供其他文件引用
module.exports = {
  
  // 管理员账户配置
  admin: {
    // 获取环境变量 ADMIN_USERNAME，如果没有设置，默认使用 'admin'
    username: process.env.ADMIN_USERNAME || 'admin',
    // 获取环境变量 ADMIN_PASSWORD，如果没有设置，默认使用 '123456'
    password: process.env.ADMIN_PASSWORD || '123456'
  },

  // 网站界面相关配置
  app: {
    // 🔴 修复点：注意下面这行代码末尾的逗号 ","
    title: process.env.SITE_TITLE || '我的导航', // 默认值为 '我的导航'
    
    // 背景图片配置
    background: process.env.background || process.env.BACKGROUND || ''
  },

  // 服务器系统配置
  server: {
    // 端口号：优先使用环境变量 PORT，否则默认使用 3000
    port: process.env.PORT || 3000,
    // JWT 密钥：用于加密登录凭证，生产环境建议在 .env 中修改得很复杂
    jwtSecret: process.env.JWT_SECRET || 'nav-item-jwt-secret-2024-secure-key'
  }

};
