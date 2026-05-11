// 文件路径：routes/parse.js
const express = require('express');
const router = express.Router();
const http = require('http');
const https = require('https');
const zlib = require('zlib'); // [!] 引入 Node.js 核心模块 zlib，用来给网页数据解压缩

// 封装一个极其强壮的“网页爬取工具函数”
function fetchHtml(targetUrl) {
  return new Promise((resolve, reject) => {
    const parsed = new URL(targetUrl);
    const protocol = parsed.protocol === 'https:' ? https : http;
    
    // 设置请求参数
    const options = {
      headers: {
        // 伪装成真实的 Windows 电脑 Chrome 浏览器
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9',
        // 告诉服务器：请给我发送压缩过的数据，这样下载更快
        'Accept-Encoding': 'gzip, deflate' 
      },
      timeout: 8000 // 超时时间 8 秒
    };

    const req = protocol.get(targetUrl, options, (res) => {
      // 1. 处理网站重定向 (比如 301/302 状态码，旧网址跳转新网址)
      if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
        try {
          const redirectUrl = new URL(res.headers.location, targetUrl).href;
          // 遇到跳转，直接递归调用自己，去抓取新网址的代码
          return resolve(fetchHtml(redirectUrl)); 
        } catch (e) {
          return resolve('');
        }
      }

      // 如果不是 200 正常返回，说明网页打不开
      if (res.statusCode !== 200) {
        return resolve('');
      }

      // 2. 接收数据块 (此时收到的可能是被压缩的二进制数据)
      let chunks = [];
      res.on('data', chunk => chunks.push(chunk));
      
      res.on('end', () => {
        // 把所有数据块拼接成一个完整的 Buffer (二进制流)
        let buffer = Buffer.concat(chunks);
        // 查看服务器是通过什么方式压缩的
        let encoding = res.headers['content-encoding'];
        let html = '';
        
        try {
          // 3. 核心步骤：像浏览器一样智能解压！
          if (encoding === 'gzip') {
            html = zlib.gunzipSync(buffer).toString(); // 解压 Gzip 格式
          } else if (encoding === 'deflate') {
            html = zlib.inflateSync(buffer).toString(); // 解压 Deflate 格式
          } else {
            html = buffer.toString(); // 如果没压缩，直接转成普通文本
          }
        } catch (e) {
          // 万一解压失败，强行作为普通文本读取
          html = buffer.toString(); 
        }
        
        resolve(html); // 将健康的、人类可读的 HTML 源代码交出去
      });
    });
    
    // 遇到请求错误或超时，直接返回空内容，防止程序崩溃
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); resolve(''); });
  });
}

// 智能链接解析路由：抓取目标网站标题和 favicon
router.get('/', async (req, res) => {
  const { url } = req.query;
  
  if (!url || !url.trim()) {
    return res.status(400).json({ error: '请提供网址' });
  }

  let targetUrl = url.trim();
  if (!targetUrl.startsWith('http')) {
    targetUrl = 'https://' + targetUrl;
  }

  try {
    const parsed = new URL(targetUrl);
    
    // 调用我们上面写好的智能爬取函数获取源代码
    const html = await fetchHtml(targetUrl);

    if (!html) {
      return res.json({ 
        success: false, 
        title: '', 
        icon: parsed.origin + '/favicon.ico',
        message: '无法获取页面内容，使用默认图标' 
      });
    }

    // ============================================
    // 1. 提取网页标题
    // ============================================
    let title = '';
    const titleMatch = html.match(/<title[^>]*>([\s\S]*?)<\/title>/i);
    if (titleMatch) {
      title = titleMatch[1].replace(/[\r\n]+/g, '').trim().replace(/\s+/g, ' ').substring(0, 100);
    }

    // ============================================
    // 2. 提取网站图标
    // ============================================
    let icon = '';
    // 把 HTML 里面所有的 <link> 标签找出来
    const linkTags = html.match(/<link[^>]+>/gi) || [];
    
    for (const tag of linkTags) {
      // 兼容匹配 rel="icon", rel="shortcut icon", rel="apple-touch-icon" 甚至是单引号的情况
      if (/rel=(?:["']?(?:shortcut\s+)?icon["']?|["']?apple-touch-icon["']?)/i.test(tag)) {
        const hrefMatch = tag.match(/href=["']([^"']+)["']/i);
        if (hrefMatch) {
          icon = hrefMatch[1]; 
          break;
        }
      }
    }

    // ============================================
    // 3. 规范化图标的链接路径
    // ============================================
    if (icon) {
      try {
        icon = new URL(icon, targetUrl).href;
      } catch (e) {}
    } else {
      icon = parsed.origin + '/favicon.ico';
    }

    res.json({
      success: true,
      title: title || '',
      icon: icon,
      message: title ? '已自动获取标题和图标' : '已获取图标，标题需手动填写'
    });

  } catch (err) {
    // 解析过程出错的后备方案
    let defaultIcon = '';
    try {
      const p = new URL(targetUrl.startsWith('http') ? targetUrl : 'https://' + targetUrl);
      defaultIcon = p.origin + '/favicon.ico';
    } catch {
      defaultIcon = '';
    }
    res.json({
      success: false,
      title: '',
      icon: defaultIcon,
      message: '自动解析失败，请手动填写标题和图标链接'
    });
  }
});

module.exports = router;
