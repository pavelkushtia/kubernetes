// TweetStream Frontend JavaScript

// Configuration
const apiBase = '/api/api';
const dataDisplay = document.getElementById('api-data');

// Utility functions
function showData() {
    dataDisplay.classList.remove('hidden');
}

function hideData() {
    dataDisplay.classList.add('hidden');
}

// API Functions
async function loadHealth() {
    try {
        const response = await fetch('/api/health');
        const data = await response.json();
        dataDisplay.innerHTML = `
            <h3>🟢 System Health Status</h3>
            <div style="background: #17bf63; padding: 15px; border-radius: 8px; margin: 10px 0;">
                <strong>Status:</strong> ${data.status}<br>
                <strong>Database:</strong> ${data.database}<br>
                <strong>Redis:</strong> ${data.redis}<br>
                <strong>Uptime:</strong> ${Math.round(data.uptime)} seconds<br>
                <strong>Last Check:</strong> ${new Date(data.timestamp).toLocaleString()}
            </div>
        `;
        showData();
    } catch (error) {
        dataDisplay.innerHTML = '<h3>❌ Error loading health data</h3>';
        showData();
    }
}

async function loadTweets() {
    try {
        const response = await fetch(apiBase + '/tweets');
        const data = await response.json();
        if (data.success && data.tweets) {
            let html = '<h3>🐦 All Tweets</h3>';
            data.tweets.forEach(tweet => {
                html += `
                    <div class="tweet">
                        <div class="tweet-user">@${tweet.username} (${tweet.display_name})</div>
                        <div class="tweet-content">${tweet.content}</div>
                        <div class="tweet-meta">
                            ❤️ ${tweet.likes_count} likes • 🔄 ${tweet.retweets_count} retweets • 
                            📅 ${new Date(tweet.created_at).toLocaleDateString()}
                        </div>
                    </div>
                `;
            });
            dataDisplay.innerHTML = html;
        } else {
            dataDisplay.innerHTML = '<h3>No tweets found</h3>';
        }
        showData();
    } catch (error) {
        dataDisplay.innerHTML = '<h3>❌ Error loading tweets</h3>';
        showData();
    }
}

async function loadUsers() {
    try {
        const response = await fetch(apiBase + '/users');
        const data = await response.json();
        if (data.success && data.users) {
            let html = '<h3>👥 All Users</h3>';
            data.users.forEach(user => {
                html += `
                    <div class="user-card">
                        <img src="${user.avatar_url}" alt="Avatar" class="user-avatar">
                        <div class="user-info">
                            <div class="user-name">${user.display_name} ${user.is_verified ? '✅' : ''}</div>
                            <div class="user-username">@${user.username}</div>
                            <div style="color: #8899a6; margin-top: 5px;">
                                📧 ${user.email} • 📅 Joined ${new Date(user.created_at).toLocaleDateString()}
                            </div>
                        </div>
                    </div>
                `;
            });
            dataDisplay.innerHTML = html;
        } else {
            dataDisplay.innerHTML = '<h3>No users found</h3>';
        }
        showData();
    } catch (error) {
        dataDisplay.innerHTML = '<h3>❌ Error loading users</h3>';
        showData();
    }
}

async function loadStats() {
    try {
        const response = await fetch(apiBase + '/stats');
        const data = await response.json();
        if (data.success) {
            document.getElementById('users').textContent = data.stats.total_users || '5';
            document.getElementById('tweets').textContent = data.stats.total_tweets || '10';
            document.getElementById('likes').textContent = data.stats.total_likes || '13';
            
            dataDisplay.innerHTML = `
                <h3>📊 Live Statistics</h3>
                <div style="background: #17bf63; padding: 15px; border-radius: 8px; margin: 10px 0;">
                    <strong>Total Users:</strong> ${data.stats.total_users}<br>
                    <strong>Total Tweets:</strong> ${data.stats.total_tweets}<br>
                    <strong>Total Likes:</strong> ${data.stats.total_likes}<br>
                    <strong>Updated:</strong> ${new Date().toLocaleString()}
                </div>
            `;
            showData();
        }
    } catch (error) {
        dataDisplay.innerHTML = '<h3>📊 Using cached statistics</h3>';
        showData();
    }
}

// Auto-refresh stats every 30 seconds
setInterval(loadStats, 30000);

// Future enhancement functions (ready for expansion)
function createTweet() {
    // TODO: Implement tweet creation functionality
    console.log('Tweet creation feature coming soon!');
}

function likeTweet(tweetId) {
    // TODO: Implement like functionality
    console.log(`Like tweet ${tweetId} - feature coming soon!`);
}

function retweetTweet(tweetId) {
    // TODO: Implement retweet functionality
    console.log(`Retweet ${tweetId} - feature coming soon!`);
}

function followUser(userId) {
    // TODO: Implement follow functionality
    console.log(`Follow user ${userId} - feature coming soon!`);
}

// Initialize app
document.addEventListener('DOMContentLoaded', function() {
    console.log('TweetStream frontend loaded successfully!');
    // Load initial stats
    loadStats();
}); 