const express = require('express');
const multer = require('multer');
const path = require('path');
const axios = require('axios');
const { S3Client, PutObjectCommand } = require("@aws-sdk/client-s3");
const router = express.Router();

// 【新手讲解】使用内存存储代替硬盘存储。文件上传后暂存在服务器内存中，直接发给 R2，不占用本地硬盘。
const storage = multer.memoryStorage();
const upload = multer({ storage: storage });

// 初始化 Cloudflare R2 客户端 (它兼容 S3 协议)
// 这些环境变量(process.env.XXX)我们会在最后部署的 Docker 平台上填写
const s3 = new S3Client({
    region: "auto",
    endpoint: `https://${process.env.R2_ACCOUNT_ID}.r2.cloudflarestorage.com`,
    credentials: {
        accessKeyId: process.env.R2_ACCESS_KEY_ID,
        secretAccessKey: process.env.R2_SECRET_ACCESS_KEY,
    },
});

// 辅助函数：将内存中的文件推送到 R2 存储桶
async function uploadToR2(buffer, originalName, mimeType) {
    const ext = path.extname(originalName) || '';
    // 生成随机的唯一文件名，避免重名覆盖
    const key = `uploads/${Date.now()}-${Math.floor(Math.random() * 1000)}${ext.toLowerCase()}`;
    
    // 发送上传指令到 R2
    await s3.send(new PutObjectCommand({
        Bucket: process.env.R2_BUCKET_NAME,
        Key: key,
        Body: buffer,
        ContentType: mimeType
    }));
    
    // 拼接出能在公网访问的图片真实链接
    let domain = process.env.R2_PUBLIC_DOMAIN || '';
    if (domain.endsWith('/')) domain = domain.slice(0, -1);
    return `${domain}/${key}`;
}

// 接口 1：处理手动上传的文件 (包括后台壁纸和原版的 logo)
// 使用 upload.any() 是为了兼容原版的字段名拦截
router.post('/', upload.any(), async (req, res) => {
    try {
        const file = req.files && req.files.length > 0 ? req.files[0] : null;
        if (!file) return res.status(400).json({ error: '没有获取到文件' });

        // 核心逻辑：上传到 R2
        const url = await uploadToR2(file.buffer, file.originalname, file.mimetype);
        
        // 告诉前端上传成功并返回直链
        res.json({ filename: file.originalname, url: url });
    } catch (error) {
        console.error("R2 上传失败:", error);
        res.status(500).json({ error: '上传到云存储失败: ' + error.message });
    }
});

// 接口 2：处理网络壁纸的自动下载和缓存
router.post('/fetch-and-cache', async (req, res) => {
    const { url } = req.body;
    if (!url) return res.status(400).json({ error: '缺少链接参数' });

    try {
        // 第一步：作为“爬虫”去下载目标链接的图片/视频数据
        const response = await axios.get(url, { responseType: 'arraybuffer' });
        const contentType = response.headers['content-type'];
        const ext = contentType.split('/')[1] || 'bin';
        const fileName = `cached_file.${ext}`;

        // 第二步：把刚下载的数据转存到咱们自己的 R2 里
        const cachedUrl = await uploadToR2(Buffer.from(response.data), fileName, contentType);
        
        // 第三步：帮你自动识别一下它到底是视频还是图片
        const type = contentType.includes('video') ? 'video' : 'image';
        
        // 把咱们自己的 R2 链接返给前端保存
        res.json({ success: true, url: cachedUrl, type });
    } catch (error) {
        console.error("缓存网络资源失败:", error);
        res.status(500).json({ error: '缓存网络资源失败，请确认链接可被服务器访问' });
    }
});

module.exports = router;
