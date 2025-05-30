const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const morgan = require('morgan');
const compression = require('compression');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const redis = require('redis');
const { Kafka } = require('kafkajs');
const promClient = require('prom-client');
const { body, validationResult } = require('express-validator');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: process.env.FRONTEND_URL || "*",
    methods: ["GET", "POST"]
  }
});
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'tweetstream-secret-key-change-in-production';

// Kafka setup
const kafka = new Kafka({
  clientId: 'tweetstream-api',
  brokers: [process.env.KAFKA_BROKERS || process.env.KAFKA_BROKER || 'tweetstream-kafka:9092'],
  retry: {
    initialRetryTime: 100,
    retries: 8
  },
  connectionTimeout: 3000,
  requestTimeout: 30000,
  enforceRequestTimeout: true
});

const producer = kafka.producer();
const consumer = kafka.consumer({ groupId: 'tweetstream-api-group' });

// Initialize Kafka
let kafkaConnected = false;
async function initKafka() {
  try {
    console.log('Connecting to Kafka brokers:', process.env.KAFKA_BROKERS || process.env.KAFKA_BROKER || 'tweetstream-kafka:9092');
    await producer.connect();
    await consumer.connect();
    
    // Subscribe to topics
    await consumer.subscribe({ topic: 'tweets', fromBeginning: false });
    await consumer.subscribe({ topic: 'follows', fromBeginning: false });
    await consumer.subscribe({ topic: 'likes', fromBeginning: false });
    await consumer.subscribe({ topic: 'users', fromBeginning: false });
    
    // Start consuming messages
    await consumer.run({
      eachMessage: async ({ topic, partition, message }) => {
        try {
          const data = JSON.parse(message.value.toString());
          console.log(`Received ${topic} event:`, data.type);
          
          // Emit real-time updates via WebSocket
          switch (topic) {
            case 'tweets':
              if (data.type === 'tweet_created') {
                io.emit('new_tweet', data.tweet);
                // Notify followers specifically
                const followers = await getFollowers(data.tweet.user_id);
                followers.forEach(follower => {
                  io.to(`user_${follower.id}`).emit('follower_tweet', data.tweet);
                });
              } else if (data.type === 'tweet_liked' || data.type === 'tweet_unliked') {
                io.emit('tweet_updated', {
                  tweet_id: data.tweet_id,
                  type: data.type,
                  likes_count: data.likes_count
                });
              } else if (data.type === 'tweet_retweeted' || data.type === 'tweet_unretweeted') {
                io.emit('tweet_updated', {
                  tweet_id: data.tweet_id,
                  type: data.type,
                  retweets_count: data.retweets_count
                });
              }
              break;
              
            case 'follows':
              if (data.type === 'user_followed' || data.type === 'user_unfollowed') {
                io.to(`user_${data.following_id}`).emit('follower_update', {
                  type: data.type,
                  follower_id: data.follower_id,
                  followers_count: data.followers_count
                });
                io.to(`user_${data.follower_id}`).emit('following_update', {
                  type: data.type,
                  following_id: data.following_id
                });
              }
              break;
              
            case 'likes':
              io.emit('like_update', {
                tweet_id: data.tweet_id,
                user_id: data.user_id,
                type: data.type
              });
              break;
              
            case 'users':
              if (data.type === 'user_registered') {
                io.emit('new_user', data.user);
              }
              break;
          }
        } catch (error) {
          console.error('Error processing Kafka message:', error);
        }
      },
    });
    
    kafkaConnected = true;
    console.log('Kafka connected successfully with consumer running');
  } catch (error) {
    console.log('Kafka connection failed:', error.message);
    kafkaConnected = false;
  }
}

// Helper function to get followers
async function getFollowers(userId) {
  try {
    const result = await pool.query(
      'SELECT follower_id as id FROM follows WHERE following_id = $1',
      [userId]
    );
    return result.rows;
  } catch (error) {
    console.error('Error getting followers:', error);
    return [];
  }
}

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

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // Limit auth attempts
  message: 'Too many authentication attempts, please try again later.',
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

// Authentication middleware
const authenticateToken = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ success: false, error: 'Access token required' });
  }

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    const user = await pool.query('SELECT id, username, email, display_name FROM users WHERE id = $1 AND is_active = true', [decoded.userId]);
    
    if (user.rows.length === 0) {
      return res.status(401).json({ success: false, error: 'Invalid token' });
    }
    
    req.user = user.rows[0];
    next();
  } catch (error) {
    return res.status(403).json({ success: false, error: 'Invalid token' });
  }
};

// Optional authentication middleware
const optionalAuth = async (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (token) {
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      const user = await pool.query('SELECT id, username, email, display_name FROM users WHERE id = $1 AND is_active = true', [decoded.userId]);
      
      if (user.rows.length > 0) {
        req.user = user.rows[0];
      }
    } catch (error) {
      // Continue without authentication
    }
  }
  
  next();
};

// Kafka message publisher
async function publishToKafka(topic, message) {
  if (!kafkaConnected) return;
  
  try {
    await producer.send({
      topic,
      messages: [{
        key: message.id?.toString(),
        value: JSON.stringify(message),
        timestamp: Date.now()
      }]
    });
  } catch (error) {
    console.error('Kafka publish error:', error);
  }
}

// WebSocket connection handling
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);
  
  // Handle user authentication for personalized rooms
  socket.on('authenticate', (token) => {
    try {
      const decoded = jwt.verify(token, JWT_SECRET);
      socket.userId = decoded.userId;
      socket.join(`user_${decoded.userId}`);
      console.log(`User ${decoded.userId} authenticated and joined room`);
      
      socket.emit('authenticated', { success: true, userId: decoded.userId });
    } catch (error) {
      socket.emit('authenticated', { success: false, error: 'Invalid token' });
    }
  });
  
  // Handle real-time feed requests
  socket.on('join_feed', () => {
    socket.join('global_feed');
    console.log('User joined global feed');
  });
  
  socket.on('leave_feed', () => {
    socket.leave('global_feed');
    console.log('User left global feed');
  });
  
  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
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
      kafka: kafkaConnected ? 'connected' : 'disconnected',
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
    version: '2.0.0',
    description: 'Twitter-like social media platform API with authentication, real-time features, and Kafka integration',
    endpoints: {
      health: {
        'GET /health': 'Health check endpoint',
        'GET /ready': 'Readiness check endpoint',
        'GET /metrics': 'Prometheus metrics endpoint',
      },
      auth: {
        'POST /api/auth/register': 'Register new user',
        'POST /api/auth/login': 'Login user',
        'GET /api/auth/me': 'Get current user profile (requires auth)',
        'PUT /api/auth/profile': 'Update user profile (requires auth)',
      },
      tweets: {
        'GET /api/tweets': 'Get tweet feed',
        'POST /api/tweets': 'Create new tweet (requires auth)',
        'GET /api/tweets/:id': 'Get specific tweet',
        'POST /api/tweets/:id/like': 'Like/unlike tweet (requires auth)',
        'POST /api/tweets/:id/retweet': 'Retweet (requires auth)',
        'DELETE /api/tweets/:id': 'Delete tweet (requires auth)',
      },
      users: {
        'GET /api/users': 'Get all users',
        'GET /api/users/:id': 'Get user profile',
        'GET /api/users/:id/tweets': 'Get user tweets',
        'POST /api/users/:id/follow': 'Follow/unfollow user (requires auth)',
        'GET /api/users/:id/followers': 'Get user followers',
        'GET /api/users/:id/following': 'Get users being followed',
      },
      feed: {
        'GET /api/feed': 'Get personalized feed (requires auth)',
      }
    },
    features: {
      authentication: 'JWT-based authentication',
      realtime: 'Kafka-powered real-time updates',
      social: 'Following, likes, retweets',
      security: 'Rate limiting, input validation'
    }
  });
});

// Authentication Routes

// Register
app.post('/api/auth/register', authLimiter, [
  body('username').isLength({ min: 3, max: 50 }).matches(/^[a-zA-Z0-9_]+$/),
  body('email').isEmail(),
  body('password').isLength({ min: 6 }),
  body('display_name').optional().isLength({ max: 100 })
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { username, email, password, display_name } = req.body;

    // Check if user exists
    const existingUser = await pool.query(
      'SELECT id FROM users WHERE username = $1 OR email = $2',
      [username, email]
    );

    if (existingUser.rows.length > 0) {
      return res.status(400).json({
        success: false,
        error: 'Username or email already exists'
      });
    }

    // Hash password
    const saltRounds = 12;
    const password_hash = await bcrypt.hash(password, saltRounds);

    // Create user
    const result = await pool.query(`
      INSERT INTO users (username, email, password_hash, display_name)
      VALUES ($1, $2, $3, $4)
      RETURNING id, username, email, display_name, created_at
    `, [username, email, password_hash, display_name || username]);

    const user = result.rows[0];

    // Generate JWT
    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '7d' });

    // Publish to Kafka
    await publishToKafka('users', {
      type: 'user_registered',
      user: { id: user.id, username: user.username },
      timestamp: new Date().toISOString()
    });

    res.status(201).json({
      success: true,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        display_name: user.display_name
      },
      token
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Login
app.post('/api/auth/login', authLimiter, [
  body('username').notEmpty(),
  body('password').notEmpty()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { username, password } = req.body;

    // Find user
    const result = await pool.query(
      'SELECT id, username, email, password_hash, display_name, is_active FROM users WHERE username = $1 OR email = $1',
      [username]
    );

    if (result.rows.length === 0) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    const user = result.rows[0];

    if (!user.is_active) {
      return res.status(401).json({ success: false, error: 'Account is deactivated' });
    }

    // Check password
    const isValidPassword = await bcrypt.compare(password, user.password_hash);
    if (!isValidPassword) {
      return res.status(401).json({ success: false, error: 'Invalid credentials' });
    }

    // Generate JWT
    const token = jwt.sign({ userId: user.id }, JWT_SECRET, { expiresIn: '7d' });

    // Publish to Kafka
    await publishToKafka('users', {
      type: 'user_login',
      user: { id: user.id, username: user.username },
      timestamp: new Date().toISOString()
    });

    res.json({
      success: true,
      user: {
        id: user.id,
        username: user.username,
        email: user.email,
        display_name: user.display_name
      },
      token
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get current user
app.get('/api/auth/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(`
      SELECT id, username, email, display_name, bio, avatar_url, 
             followers_count, following_count, tweets_count, is_verified, created_at
      FROM users WHERE id = $1
    `, [req.user.id]);

    res.json({
      success: true,
      user: result.rows[0]
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Update profile
app.put('/api/auth/profile', authenticateToken, [
  body('display_name').optional().isLength({ max: 100 }),
  body('bio').optional().isLength({ max: 500 }),
  body('avatar_url').optional().isURL()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { display_name, bio, avatar_url } = req.body;
    
    const result = await pool.query(`
      UPDATE users 
      SET display_name = COALESCE($1, display_name),
          bio = COALESCE($2, bio),
          avatar_url = COALESCE($3, avatar_url),
          updated_at = NOW()
      WHERE id = $4
      RETURNING id, username, email, display_name, bio, avatar_url
    `, [display_name, bio, avatar_url, req.user.id]);

    res.json({
      success: true,
      user: result.rows[0]
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Tweet Routes

// Get tweet feed (with optional authentication for personalized feed)
app.get('/api/tweets', optionalAuth, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = parseInt(req.query.offset) || 0;

    let query;
    let params;

    if (req.user) {
      // Personalized feed: tweets from followed users + own tweets
      query = `
        SELECT DISTINCT t.*, u.username, u.display_name, u.avatar_url, u.is_verified,
               EXISTS(SELECT 1 FROM likes l WHERE l.tweet_id = t.id AND l.user_id = $1) as is_liked,
               EXISTS(SELECT 1 FROM tweets rt WHERE rt.original_tweet_id = t.id AND rt.user_id = $1 AND rt.is_retweet = true) as is_retweeted
        FROM tweets t
        JOIN users u ON t.user_id = u.id
        LEFT JOIN follows f ON f.following_id = t.user_id
        WHERE (f.follower_id = $1 OR t.user_id = $1) AND t.is_retweet = false
        ORDER BY t.created_at DESC
        LIMIT $2 OFFSET $3
      `;
      params = [req.user.id, limit, offset];
    } else {
      // Public feed: all tweets
      query = `
        SELECT t.*, u.username, u.display_name, u.avatar_url, u.is_verified,
               false as is_liked, false as is_retweeted
        FROM tweets t
        JOIN users u ON t.user_id = u.id
        WHERE t.is_retweet = false
        ORDER BY t.created_at DESC
        LIMIT $1 OFFSET $2
      `;
      params = [limit, offset];
    }

    const result = await pool.query(query, params);
    
    res.json({
      success: true,
      tweets: result.rows,
      count: result.rows.length,
      pagination: {
        limit,
        offset,
        hasMore: result.rows.length === limit
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Create new tweet
app.post('/api/tweets', authenticateToken, [
  body('content').isLength({ min: 1, max: 280 }).trim()
], async (req, res) => {
  try {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ success: false, errors: errors.array() });
    }

    const { content } = req.body;

    const result = await pool.query(`
      INSERT INTO tweets (user_id, content, created_at)
      VALUES ($1, $2, NOW())
      RETURNING *
    `, [req.user.id, content]);

    const tweet = result.rows[0];

    // Update user tweet count
    await pool.query(
      'UPDATE users SET tweets_count = tweets_count + 1 WHERE id = $1',
      [req.user.id]
    );

    // Get tweet with user info
    const tweetWithUser = await pool.query(`
      SELECT t.*, u.username, u.display_name, u.avatar_url, u.is_verified
      FROM tweets t
      JOIN users u ON t.user_id = u.id
      WHERE t.id = $1
    `, [tweet.id]);

    // Publish to Kafka
    await publishToKafka('tweets', {
      type: 'tweet_created',
      tweet: tweetWithUser.rows[0],
      timestamp: new Date().toISOString()
    });

    res.status(201).json({
      success: true,
      tweet: tweetWithUser.rows[0]
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get specific tweet
app.get('/api/tweets/:id', optionalAuth, async (req, res) => {
  try {
    const { id } = req.params;
    
    let query;
    let params;

    if (req.user) {
      query = `
        SELECT t.*, u.username, u.display_name, u.avatar_url, u.is_verified,
               EXISTS(SELECT 1 FROM likes l WHERE l.tweet_id = t.id AND l.user_id = $2) as is_liked,
               EXISTS(SELECT 1 FROM tweets rt WHERE rt.original_tweet_id = t.id AND rt.user_id = $2 AND rt.is_retweet = true) as is_retweeted
        FROM tweets t
        JOIN users u ON t.user_id = u.id
        WHERE t.id = $1
      `;
      params = [id, req.user.id];
    } else {
      query = `
        SELECT t.*, u.username, u.display_name, u.avatar_url, u.is_verified,
               false as is_liked, false as is_retweeted
        FROM tweets t
        JOIN users u ON t.user_id = u.id
        WHERE t.id = $1
      `;
      params = [id];
    }

    const result = await pool.query(query, params);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Tweet not found' });
    }
    
    res.json({
      success: true,
      tweet: result.rows[0]
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Like/unlike tweet
app.post('/api/tweets/:id/like', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const tweetId = parseInt(id);

    // Check if tweet exists
    const tweetCheck = await pool.query('SELECT id, user_id FROM tweets WHERE id = $1', [tweetId]);
    if (tweetCheck.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Tweet not found' });
    }

    // Check if already liked
    const existingLike = await pool.query(
      'SELECT id FROM likes WHERE user_id = $1 AND tweet_id = $2',
      [req.user.id, tweetId]
    );

    let isLiked;
    if (existingLike.rows.length > 0) {
      // Unlike
      await pool.query('DELETE FROM likes WHERE user_id = $1 AND tweet_id = $2', [req.user.id, tweetId]);
      await pool.query('UPDATE tweets SET likes_count = likes_count - 1 WHERE id = $1', [tweetId]);
      isLiked = false;
    } else {
      // Like
      await pool.query('INSERT INTO likes (user_id, tweet_id) VALUES ($1, $2)', [req.user.id, tweetId]);
      await pool.query('UPDATE tweets SET likes_count = likes_count + 1 WHERE id = $1', [tweetId]);
      isLiked = true;
    }

    // Get updated tweet
    const result = await pool.query('SELECT likes_count FROM tweets WHERE id = $1', [tweetId]);

    // Publish to Kafka
    await publishToKafka('likes', {
      type: isLiked ? 'tweet_liked' : 'tweet_unliked',
      user_id: req.user.id,
      tweet_id: tweetId,
      tweet_user_id: tweetCheck.rows[0].user_id,
      timestamp: new Date().toISOString()
    });

    res.json({
      success: true,
      is_liked: isLiked,
      likes_count: result.rows[0].likes_count
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Retweet
app.post('/api/tweets/:id/retweet', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const originalTweetId = parseInt(id);

    // Check if tweet exists
    const tweetCheck = await pool.query('SELECT id, user_id FROM tweets WHERE id = $1', [originalTweetId]);
    if (tweetCheck.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Tweet not found' });
    }

    // Check if already retweeted
    const existingRetweet = await pool.query(
      'SELECT id FROM tweets WHERE user_id = $1 AND original_tweet_id = $2 AND is_retweet = true',
      [req.user.id, originalTweetId]
    );

    let isRetweeted;
    if (existingRetweet.rows.length > 0) {
      // Un-retweet
      await pool.query('DELETE FROM tweets WHERE user_id = $1 AND original_tweet_id = $2 AND is_retweet = true', [req.user.id, originalTweetId]);
      await pool.query('UPDATE tweets SET retweets_count = retweets_count - 1 WHERE id = $1', [originalTweetId]);
      await pool.query('UPDATE users SET tweets_count = tweets_count - 1 WHERE id = $1', [req.user.id]);
      isRetweeted = false;
    } else {
      // Retweet
      await pool.query(`
        INSERT INTO tweets (user_id, content, is_retweet, original_tweet_id, created_at)
        VALUES ($1, '', true, $2, NOW())
      `, [req.user.id, originalTweetId]);
      await pool.query('UPDATE tweets SET retweets_count = retweets_count + 1 WHERE id = $1', [originalTweetId]);
      await pool.query('UPDATE users SET tweets_count = tweets_count + 1 WHERE id = $1', [req.user.id]);
      isRetweeted = true;
    }

    // Get updated tweet
    const result = await pool.query('SELECT retweets_count FROM tweets WHERE id = $1', [originalTweetId]);

    // Publish to Kafka
    await publishToKafka('tweets', {
      type: isRetweeted ? 'tweet_retweeted' : 'tweet_unretweeted',
      user_id: req.user.id,
      tweet_id: originalTweetId,
      tweet_user_id: tweetCheck.rows[0].user_id,
      timestamp: new Date().toISOString()
    });

    res.json({
      success: true,
      is_retweeted: isRetweeted,
      retweets_count: result.rows[0].retweets_count
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Delete tweet
app.delete('/api/tweets/:id', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;

    // Check if tweet exists and belongs to user
    const tweetCheck = await pool.query('SELECT id FROM tweets WHERE id = $1 AND user_id = $2', [id, req.user.id]);
    if (tweetCheck.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'Tweet not found or not authorized' });
    }

    // Delete tweet (cascades to likes and retweets)
    await pool.query('DELETE FROM tweets WHERE id = $1', [id]);
    await pool.query('UPDATE users SET tweets_count = tweets_count - 1 WHERE id = $1', [req.user.id]);

    // Publish to Kafka
    await publishToKafka('tweets', {
      type: 'tweet_deleted',
      user_id: req.user.id,
      tweet_id: parseInt(id),
      timestamp: new Date().toISOString()
    });

    res.json({ success: true, message: 'Tweet deleted successfully' });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// User Routes

// Get all users
app.get('/api/users', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = parseInt(req.query.offset) || 0;

    const result = await pool.query(`
      SELECT id, username, display_name, bio, avatar_url, is_verified,
             followers_count, following_count, tweets_count, created_at
      FROM users
      WHERE is_active = true
      ORDER BY created_at DESC
      LIMIT $1 OFFSET $2
    `, [limit, offset]);
    
    res.json({
      success: true,
      users: result.rows,
      count: result.rows.length,
      pagination: {
        limit,
        offset,
        hasMore: result.rows.length === limit
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get user profile
app.get('/api/users/:id', optionalAuth, async (req, res) => {
  try {
    const { id } = req.params;
    
    let query;
    let params;

    if (req.user) {
      query = `
        SELECT u.id, u.username, u.display_name, u.bio, u.avatar_url, u.is_verified,
               u.followers_count, u.following_count, u.tweets_count, u.created_at,
               EXISTS(SELECT 1 FROM follows f WHERE f.follower_id = $2 AND f.following_id = u.id) as is_following
        FROM users u
        WHERE u.id = $1 AND u.is_active = true
      `;
      params = [id, req.user.id];
    } else {
      query = `
        SELECT id, username, display_name, bio, avatar_url, is_verified,
               followers_count, following_count, tweets_count, created_at,
               false as is_following
        FROM users
        WHERE id = $1 AND is_active = true
      `;
      params = [id];
    }

    const result = await pool.query(query, params);
    
    if (result.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }
    
    res.json({
      success: true,
      user: result.rows[0]
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get user's tweets
app.get('/api/users/:id/tweets', optionalAuth, async (req, res) => {
  try {
    const { id } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = parseInt(req.query.offset) || 0;

    let query;
    let params;

    if (req.user) {
      query = `
        SELECT t.*, u.username, u.display_name, u.avatar_url, u.is_verified,
               EXISTS(SELECT 1 FROM likes l WHERE l.tweet_id = t.id AND l.user_id = $2) as is_liked,
               EXISTS(SELECT 1 FROM tweets rt WHERE rt.original_tweet_id = t.id AND rt.user_id = $2 AND rt.is_retweet = true) as is_retweeted
        FROM tweets t
        JOIN users u ON t.user_id = u.id
        WHERE t.user_id = $1 AND t.is_retweet = false
        ORDER BY t.created_at DESC
        LIMIT $3 OFFSET $4
      `;
      params = [id, req.user.id, limit, offset];
    } else {
      query = `
        SELECT t.*, u.username, u.display_name, u.avatar_url, u.is_verified,
               false as is_liked, false as is_retweeted
        FROM tweets t
        JOIN users u ON t.user_id = u.id
        WHERE t.user_id = $1 AND t.is_retweet = false
        ORDER BY t.created_at DESC
        LIMIT $2 OFFSET $3
      `;
      params = [id, limit, offset];
    }

    const result = await pool.query(query, params);
    
    res.json({
      success: true,
      tweets: result.rows,
      count: result.rows.length,
      pagination: {
        limit,
        offset,
        hasMore: result.rows.length === limit
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Follow/unfollow user
app.post('/api/users/:id/follow', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const followingId = parseInt(id);

    if (followingId === req.user.id) {
      return res.status(400).json({ success: false, error: 'Cannot follow yourself' });
    }

    // Check if user exists
    const userCheck = await pool.query('SELECT id FROM users WHERE id = $1 AND is_active = true', [followingId]);
    if (userCheck.rows.length === 0) {
      return res.status(404).json({ success: false, error: 'User not found' });
    }

    // Check if already following
    const existingFollow = await pool.query(
      'SELECT id FROM follows WHERE follower_id = $1 AND following_id = $2',
      [req.user.id, followingId]
    );

    let isFollowing;
    if (existingFollow.rows.length > 0) {
      // Unfollow
      await pool.query('DELETE FROM follows WHERE follower_id = $1 AND following_id = $2', [req.user.id, followingId]);
      await pool.query('UPDATE users SET followers_count = followers_count - 1 WHERE id = $1', [followingId]);
      await pool.query('UPDATE users SET following_count = following_count - 1 WHERE id = $1', [req.user.id]);
      isFollowing = false;
    } else {
      // Follow
      await pool.query('INSERT INTO follows (follower_id, following_id) VALUES ($1, $2)', [req.user.id, followingId]);
      await pool.query('UPDATE users SET followers_count = followers_count + 1 WHERE id = $1', [followingId]);
      await pool.query('UPDATE users SET following_count = following_count + 1 WHERE id = $1', [req.user.id]);
      isFollowing = true;
    }

    // Get updated counts
    const result = await pool.query('SELECT followers_count FROM users WHERE id = $1', [followingId]);

    // Publish to Kafka
    await publishToKafka('follows', {
      type: isFollowing ? 'user_followed' : 'user_unfollowed',
      follower_id: req.user.id,
      following_id: followingId,
      timestamp: new Date().toISOString()
    });

    res.json({
      success: true,
      is_following: isFollowing,
      followers_count: result.rows[0].followers_count
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get user followers
app.get('/api/users/:id/followers', async (req, res) => {
  try {
    const { id } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = parseInt(req.query.offset) || 0;

    const result = await pool.query(`
      SELECT u.id, u.username, u.display_name, u.avatar_url, u.is_verified, f.created_at as followed_at
      FROM follows f
      JOIN users u ON f.follower_id = u.id
      WHERE f.following_id = $1 AND u.is_active = true
      ORDER BY f.created_at DESC
      LIMIT $2 OFFSET $3
    `, [id, limit, offset]);
    
    res.json({
      success: true,
      followers: result.rows,
      count: result.rows.length,
      pagination: {
        limit,
        offset,
        hasMore: result.rows.length === limit
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Get users being followed
app.get('/api/users/:id/following', async (req, res) => {
  try {
    const { id } = req.params;
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = parseInt(req.query.offset) || 0;

    const result = await pool.query(`
      SELECT u.id, u.username, u.display_name, u.avatar_url, u.is_verified, f.created_at as followed_at
      FROM follows f
      JOIN users u ON f.following_id = u.id
      WHERE f.follower_id = $1 AND u.is_active = true
      ORDER BY f.created_at DESC
      LIMIT $2 OFFSET $3
    `, [id, limit, offset]);
    
    res.json({
      success: true,
      following: result.rows,
      count: result.rows.length,
      pagination: {
        limit,
        offset,
        hasMore: result.rows.length === limit
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Personalized feed
app.get('/api/feed', authenticateToken, async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit) || 20, 100);
    const offset = parseInt(req.query.offset) || 0;

    const result = await pool.query(`
      SELECT DISTINCT t.*, u.username, u.display_name, u.avatar_url, u.is_verified,
             EXISTS(SELECT 1 FROM likes l WHERE l.tweet_id = t.id AND l.user_id = $1) as is_liked,
             EXISTS(SELECT 1 FROM tweets rt WHERE rt.original_tweet_id = t.id AND rt.user_id = $1 AND rt.is_retweet = true) as is_retweeted
      FROM tweets t
      JOIN users u ON t.user_id = u.id
      JOIN follows f ON f.following_id = t.user_id
      WHERE f.follower_id = $1 AND t.is_retweet = false
      ORDER BY t.created_at DESC
      LIMIT $2 OFFSET $3
    `, [req.user.id, limit, offset]);
    
    res.json({
      success: true,
      tweets: result.rows,
      count: result.rows.length,
      pagination: {
        limit,
        offset,
        hasMore: result.rows.length === limit
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
  }
});

// Statistics endpoint
app.get('/api/stats', async (req, res) => {
  try {
    const [usersResult, tweetsResult, likesResult, followsResult] = await Promise.all([
      pool.query('SELECT COUNT(*) FROM users WHERE is_active = true'),
      pool.query('SELECT COUNT(*) FROM tweets WHERE is_retweet = false'),
      pool.query('SELECT COUNT(*) FROM likes'),
      pool.query('SELECT COUNT(*) FROM follows')
    ]);

    res.json({
      success: true,
      stats: {
        total_users: parseInt(usersResult.rows[0].count),
        total_tweets: parseInt(tweetsResult.rows[0].count),
        total_likes: parseInt(likesResult.rows[0].count),
        total_follows: parseInt(followsResult.rows[0].count)
      }
    });
  } catch (error) {
    res.status(500).json({ success: false, error: error.message });
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

// Initialize Kafka on startup
initKafka();

// Start server
server.listen(PORT, () => {
  console.log(`TweetStream API server with WebSocket running on port ${PORT}`);
  console.log(`Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`Database: ${process.env.DATABASE_URL ? 'Connected' : 'Using default'}`);
  console.log(`Redis: ${process.env.REDIS_URL ? 'Connected' : 'Using default'}`);
  console.log(`Kafka: ${process.env.KAFKA_BROKERS ? 'Connected' : 'Using default'}`);
  console.log(`WebSocket: Enabled for real-time updates`);
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await pool.end();
  if (redisClient) {
    await redisClient.quit();
  }
  if (kafkaConnected) {
    await producer.disconnect();
    await consumer.disconnect();
  }
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  await pool.end();
  if (redisClient) {
    await redisClient.quit();
  }
  if (kafkaConnected) {
    await producer.disconnect();
    await consumer.disconnect();
  }
  process.exit(0);
}); 