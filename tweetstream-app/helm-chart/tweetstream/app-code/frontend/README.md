# TweetStream Frontend

A modern, responsive Twitter-like frontend for the TweetStream application, built with vanilla HTML, CSS, and JavaScript.

## 🏗️ Architecture

This frontend uses a **Python HTTP server** approach instead of nginx to avoid Pod Security Standards issues in Kubernetes environments.

### File Structure
```
frontend/
├── index.html          # Main HTML structure
├── styles.css          # All CSS styles and responsive design
├── app.js             # JavaScript functionality and API calls
├── Dockerfile         # Container build configuration
└── README.md          # This documentation
```

## 🎨 Features

### Current Features
- **📊 Real-time Statistics**: Live updates every 30 seconds
- **🔍 Health Monitoring**: System health checks with detailed status
- **🐦 Tweet Display**: Twitter-like cards with user info, content, and metadata
- **👥 User Profiles**: User cards with avatars and profile information
- **📱 Responsive Design**: Works on desktop and mobile devices
- **🌙 Dark Theme**: Twitter-inspired dark mode design

### API Integration
- **Health Check**: `/api/health` - System status monitoring
- **Tweets**: `/api/api/tweets` - Fetch all tweets with user data
- **Users**: `/api/api/users` - Fetch all user profiles
- **Statistics**: `/api/api/stats` - Live platform statistics

## 🚀 Development

### Local Development
```bash
# Serve files locally
python3 -m http.server 8080

# Access at http://localhost:8080
```

### Building Docker Image
```bash
# Build the frontend image
docker build -t tweetstream/frontend:2.0.0 .

# Run locally
docker run -p 8080:8080 tweetstream/frontend:2.0.0
```

## 🔧 Customization

### Adding New Features

#### 1. New API Endpoints
Add new functions to `app.js`:
```javascript
async function newFeature() {
    try {
        const response = await fetch('/api/new-endpoint');
        const data = await response.json();
        // Handle response
    } catch (error) {
        console.error('Error:', error);
    }
}
```

#### 2. New UI Components
Add styles to `styles.css`:
```css
.new-component {
    background: #192734;
    border-radius: 10px;
    padding: 15px;
    margin: 10px 0;
}
```

Add HTML structure to `index.html`:
```html
<div class="section">
    <h2>🆕 New Feature</h2>
    <button class="button" onclick="newFeature()">Try New Feature</button>
</div>
```

#### 3. Interactive Features
The frontend is ready for expansion with these placeholder functions:
- `createTweet()` - Tweet creation form
- `likeTweet(tweetId)` - Like/unlike functionality
- `retweetTweet(tweetId)` - Retweet functionality
- `followUser(userId)` - Follow/unfollow users

### Styling Guidelines
- **Colors**: Use Twitter-inspired color scheme
  - Primary: `#1da1f2` (Twitter blue)
  - Background: `#15202b` (Dark blue)
  - Cards: `#192734` (Lighter dark)
  - Text: `#ffffff` (White) and `#8899a6` (Gray)
- **Typography**: System fonts for better performance
- **Responsive**: Mobile-first design with CSS Grid

## 🐳 Kubernetes Deployment

### Current Approach (Python HTTP Server)
The frontend uses Python HTTP server because:
- ✅ **Security**: Runs as non-root user (1000:1000)
- ✅ **Compatibility**: Works with Pod Security Standards
- ✅ **Simplicity**: No complex nginx configuration
- ✅ **Lightweight**: Minimal resource usage

### Deployment Methods

#### 1. Direct YAML (Current)
Uses `improved-frontend.yaml` with embedded files.

#### 2. Helm Chart (Future)
Update `templates/frontend/deployment.yaml` to use this Docker image:
```yaml
spec:
  containers:
  - name: frontend
    image: tweetstream/frontend:2.0.0
    ports:
    - containerPort: 8080
```

## 📊 Performance

### Resource Usage
- **CPU**: 50m requests, 100m limits
- **Memory**: 32Mi requests, 64Mi limits
- **Image Size**: ~50MB (Python Alpine base)

### Optimization Tips
1. **Minify CSS/JS**: Use build tools for production
2. **Image Optimization**: Compress any future image assets
3. **Caching**: Add service worker for offline functionality
4. **CDN**: Consider external CDN for static assets

## 🔮 Future Enhancements

### Planned Features
- **✍️ Tweet Creation**: Form for posting new tweets
- **❤️ Interactive Likes**: Click to like/unlike tweets
- **🔄 Retweet System**: Share tweets with comments
- **👤 User Profiles**: Detailed user profile pages
- **🔍 Search**: Search tweets and users
- **📱 PWA**: Progressive Web App capabilities
- **🔔 Notifications**: Real-time notifications
- **🌐 Internationalization**: Multi-language support

### Technical Improvements
- **State Management**: Consider lightweight state management
- **Component System**: Modular component architecture
- **Testing**: Unit and integration tests
- **Build System**: Webpack/Vite for optimization
- **TypeScript**: Type safety for larger codebase

## 🚨 Security Considerations

### Current Security Features
- **Non-root User**: Runs as user 1000:1000
- **No Privileged Ports**: Uses port 8080
- **Minimal Capabilities**: Drops all Linux capabilities
- **Read-only Filesystem**: Could be implemented for extra security

### Best Practices
- **Input Sanitization**: Escape user content in JavaScript
- **HTTPS**: Use TLS in production
- **CSP Headers**: Content Security Policy headers
- **CORS**: Proper Cross-Origin Resource Sharing

## 📝 Contributing

### Code Style
- **HTML**: Semantic markup, proper indentation
- **CSS**: BEM methodology, mobile-first
- **JavaScript**: ES6+, async/await, proper error handling

### Testing
```bash
# Lint HTML
npx htmlhint index.html

# Lint CSS
npx stylelint styles.css

# Lint JavaScript
npx eslint app.js
```

---

**Status**: Production Ready | **Version**: 2.0.0 | **Last Updated**: 2025-01-26 