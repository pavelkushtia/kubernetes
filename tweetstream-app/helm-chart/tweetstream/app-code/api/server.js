const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const { Pool } = require('pg');
const redis = require('redis');
const promClient = require('prom-client');

const app = express();
const PORT = process.env.PORT || 3000;

// Prometheus metrics
const register = new promClient.Registry();
promClient.collectDefaultMetrics({ register });

const httpRequestDuration = new promClient.Histogram({
  name: 'http_request_duration_seconds',
  help: 'Duration of HTTP requests in seconds',
  labelNames: ['method', 'route', 'status_code'],
  buckets: [0.1, 0.3, 0.5, 0.7, 1, 3, 5, 7, 10]
});

const httpRequestsTotal = new promClient.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'route', 'status_code']
});

const activeUsers = new promClient.Gauge({
  name: 'tweetstream_active_users_total',
  help: 'Number of currently active users'
});

const totalTweets = new promClient.Gauge({
  name: 'tweetstream_tweets_total',
  help: 'Total number of tweets'
});

const totalLikes = new promClient.Gauge({
  name: 'tweetstream_likes_total',
  help: 'Total number of likes'
});

register.registerMetric(httpRequestDuration);
register.registerMetric(httpRequestsTotal);
register.registerMetric(activeUsers);
register.registerMetric(totalTweets);
register.registerMetric(totalLikes);

// Database connection
const pool = new Pool({
  connectionString: process.env.DATABASE_URL || 'postgresql://tweetuser:tweetpass123@postgres-primary:5432/tweetstream',
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});

// Redis connection
let redisClient;
try {
  redisClient = redis.createClient({
    url: process.env.REDIS_URL || 'redis://redis:6379'
  });
  redisClient.connect();
} catch (error) {
  console.log('Redis connection failed:', error.message);
}

// Rate limiting
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 100,
  message: 'Too many requests from this IP, please try again later.',
  standardHeaders: true,
  legacyHeaders: false,
});

// Middleware
app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", "data:", "https:"],
    },
  },
}));

app.use(cors({
  origin: process.env.FRONTEND_URL || '*',
  credentials: true,
}));

app.use(compression());
app.use(morgan('combined'));
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));
app.use(limiter);

// Metrics middleware
app.use((req, res, next) => {
  const start = Date.now();
  
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    httpRequestDuration
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .observe(duration);
    
    httpRequestsTotal
      .labels(req.method, req.route?.path || req.path, res.statusCode)
      .inc();
  });
  
  next();
});

// Health check endpoints
app.get('/health', async (req, res) => {
  try {
    // Check database connection
    await pool.query('SELECT 1');
    
    // Check Redis connection
    let redisStatus = 'disconnected';
    if (redisClient && redisClient.isOpen) {
      await redisClient.ping();
      redisStatus = 'connected';
    }
    
    res.json({
      status: 'healthy',
      timestamp: new Date().toISOString(),
      database: 'connected',
      redis: redisStatus,
      uptime: process.uptime()
    });
  } catch (error) {
    res.status(503).json({
      status: 'unhealthy',
      error: error.message,
      timestamp: new Date().toISOString()
    });
  }
});

app.get('/ready', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ready' });
  } catch (error) {
    res.status(503).json({ status: 'not ready', error: error.message });
  }
});

// Metrics endpoint
app.get('/metrics', async (req, res) => {
  try {
    // Update custom metrics
    const tweetsResult = await pool.query('SELECT COUNT(*) FROM tweets');
    const likesResult = await pool.query('SELECT COUNT(*) FROM likes');
    const usersResult = await pool.query('SELECT COUNT(*) FROM users WHERE created_at > NOW() - INTERVAL \'1 hour\'');
    
    totalTweets.set(parseInt(tweetsResult.rows[0].count));
    totalLikes.set(parseInt(likesResult.rows[0].count));
    activeUsers.set(parseInt(usersResult.rows[0].count));
    
    res.set('Content-Type', register.contentType);
    res.end(await register.metrics());
  } catch (error) {
    res.status(500).end(error.message);
  }
});

// API documentation endpoint
app.get('/api', (req, res) => {
  res.json({
    name: 'TweetStream API',
    version: '1.0.0',
    description: 'Twitter-like social media platform API',
    endpoints: {
      health: {
        'GET /health': 'Health check endpoint',
        'GET /ready': 'Readiness check endpoint',
        'GET /metrics': 'Prometheus metrics endpoint',
      },
      tweets: {
        'GET /api/tweets': 'Get tweet feed',
        'POST /api/tweets': 'Create new tweet',
        'GET /api/tweets/:id': 'Get specific tweet',
      },
      users: {
        'GET /api/users': 'Get all users',
        'GET /api/users/:id': 'Get user profile',
      },
    },
    database: {
      status: 'connected',
      tables: ['users', 'tweets', 'follows', 'likes']
    }
  });
});

// Get all tweets
app.get('/api/tweets', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT t.*, u.username, u.display_name, u.avatar_url, u.is_verified
      FROM tweets t
      JOIN users u ON t.user_id = u.id
      ORDER BY t.created_at DESC
      LIMIT 50
    `);
    
    res.json({
      success: true,
      tweets: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get specific tweet
app.get('/api/tweets/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(`
      SELECT t.*, u.username, u.display_name, u.avatar_url, u.is_verified
      FROM tweets t
      JOIN users u ON t.user_id = u.id
      WHERE t.id = $1
    `, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'Tweet not found'
      });
    }
    
    res.json({
      success: true,
      tweet: result.rows[0]
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Create new tweet
app.post('/api/tweets', async (req, res) => {
  try {
    const { content, user_id = 1 } = req.body; // Default to user 1 for demo
    
    if (!content || content.length > 280) {
      return res.status(400).json({
        success: false,
        error: 'Tweet content is required and must be 280 characters or less'
      });
    }
    
    const result = await pool.query(`
      INSERT INTO tweets (user_id, content, created_at)
      VALUES ($1, $2, NOW())
      RETURNING *
    `, [user_id, content]);
    
    res.status(201).json({
      success: true,
      tweet: result.rows[0]
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get all users
app.get('/api/users', async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT id, username, display_name, bio, avatar_url, is_verified,
             followers_count, following_count, tweets_count, created_at
      FROM users
      ORDER BY created_at DESC
    `);
    
    res.json({
      success: true,
      users: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get user profile
app.get('/api/users/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(`
      SELECT id, username, display_name, bio, avatar_url, is_verified,
             followers_count, following_count, tweets_count, created_at
      FROM users
      WHERE id = $1
    `, [id]);
    
    if (result.rows.length === 0) {
      return res.status(404).json({
        success: false,
        error: 'User not found'
      });
    }
    
    res.json({
      success: true,
      user: result.rows[0]
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// Get user's tweets
app.get('/api/users/:id/tweets', async (req, res) => {
  try {
    const { id } = req.params;
    const result = await pool.query(`
      SELECT t.*, u.username, u.display_name, u.avatar_url, u.is_verified
      FROM tweets t
      JOIN users u ON t.user_id = u.id
      WHERE t.user_id = $1
      ORDER BY t.created_at DESC
      LIMIT 50
    `, [id]);
    
    res.json({
      success: true,
      tweets: result.rows,
      count: result.rows.length
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      error: error.message
    });
  }
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({
    error: 'Not Found',
    message: `Route ${req.originalUrl} not found`,
    availableEndpoints: '/api',
  });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Error:', error);
  res.status(500).json({
    error: 'Internal Server Error',
    message: error.message
  });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await pool.end();
  if (redisClient) {
    await redisClient.quit();
  }
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  await pool.end();
  if (redisClient) {
    await redisClient.quit();
  }
  process.exit(0);
});

// Start server
app.listen(PORT, '0.0.0.0', () => {
  console.log(`TweetStream API server running on port ${PORT}`);
  console.log(`Health check: http://localhost:${PORT}/health`);
  console.log(`API documentation: http://localhost:${PORT}/api`);
  console.log(`Metrics: http://localhost:${PORT}/metrics`);
});

module.exports = app; 