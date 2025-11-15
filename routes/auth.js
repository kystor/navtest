const express = require('express');
const db = require('../db');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const router = express.Router();

const JWT_SECRET = 'your_jwt_secret_key';

/**
 * 获取用户真实 IP
 */
function getClientIp(req) {
  let ip = req.headers['x-forwarded-for'] || req.connection.remoteAddress || '';
  if (typeof ip === 'string' && ip.includes(',')) ip = ip.split(',')[0].trim();
  if (typeof ip === 'string' && ip.startsWith('::ffff:')) ip = ip.replace('::ffff:', '');
  return ip;
}

/**
 * 返回上海时间 YYYY-MM-DD HH:mm:ss
 */
function getShanghaiTime() {
  const date = new Date();
  const shanghaiTime = new Date(date.toLocaleString("en-US", { timeZone: "Asia/Shanghai" }));

  const year = shanghaiTime.getFullYear();
  const month = String(shanghaiTime.getMonth() + 1).padStart(2, '0');
  const day = String(shanghaiTime.getDate()).padStart(2, '0');
  const hours = String(shanghaiTime.getHours()).padStart(2, '0');
  const minutes = String(shanghaiTime.getMinutes()).padStart(2, '0');
  const seconds = String(shanghaiTime.getSeconds()).padStart(2, '0');

  return `${year}-${month}-${day} ${hours}:${minutes}:${seconds}`;
}

/**
 * 🔐 登录接口
 */
router.post('/login', (req, res) => {
  const { username, password } = req.body;

  // 查询用户
  db.get('SELECT * FROM users WHERE username=?', [username], (err, user) => {
    if (err || !user) return res.status(401).json({ error: '用户名或密码错误' });

    // 比对密码
    bcrypt.compare(password, user.password, (err, result) => {
      if (result) {

        // 读取上次登录信息
        const lastLoginTime = user.last_login_time;
        const lastLoginIp = user.last_login_ip;

        // 更新为本次登录
        const now = getShanghaiTime();
        const ip = getClientIp(req);
        db.run(
          'UPDATE users SET last_login_time=?, last_login_ip=? WHERE id=?',
          [now, ip, user.id]
        );

        // 生成 Token（有效期 2 小时）
        const token = jwt.sign(
          { id: user.id, username: user.username },
          JWT_SECRET,
          { expiresIn: '2h' }
        );

        // 返回 token 与上次登录记录
        res.json({ token, lastLoginTime, lastLoginIp });
      } else {
        res.status(401).json({ error: '用户名或密码错误' });
      }
    });
  });
});

/**
 * 🔐 新增：Token 验证中间件（前端请求需要带 Authorization: Bearer token）
 * token 过期 → 返回 401 → 前端自动跳转回登录页
 */
router.use((req, res, next) => {
  const auth = req.headers.authorization;

  // 没带 token
  if (!auth || !auth.startsWith('Bearer ')) {
    return res.status(401).json({ error: '登录已失效，请重新登录' });
  }

  const token = auth.slice(7);

  // 检查 token 是否有效
  jwt.verify(token, JWT_SECRET, (err, decoded) => {
    if (err) {
      // token 无效/过期
      return res.status(401).json({ error: '登录已失效，请重新登录' });
    }

    // 继续执行后续 API
    req.user = decoded;
    next();
  });
});

module.exports = router;
