-- TweetStream Sample Data
-- This file contains realistic sample data for development and testing

-- Insert sample users with realistic profiles
INSERT INTO users (username, email, password_hash, display_name, bio, avatar_url, is_verified) VALUES
('john_doe', 'john@example.com', '$2b$10$hash1', 'John Doe', 'Software engineer who loves coding and coffee ☕', 'https://api.dicebear.com/7.x/avataaars/svg?seed=john', false),
('jane_smith', 'jane@example.com', '$2b$10$hash2', 'Jane Smith', 'UX Designer passionate about creating beautiful experiences 🎨', 'https://api.dicebear.com/7.x/avataaars/svg?seed=jane', false),
('tech_guru', 'guru@example.com', '$2b$10$hash3', 'Tech Guru', 'Technology enthusiast and blogger 🚀', 'https://api.dicebear.com/7.x/avataaars/svg?seed=guru', true),
('coffee_lover', 'coffee@example.com', '$2b$10$hash4', 'Coffee Connoisseur', 'Exploring the world one cup at a time ☕🌍', 'https://api.dicebear.com/7.x/avataaars/svg?seed=coffee', false),
('data_scientist', 'data@example.com', '$2b$10$hash5', 'Data Scientist', 'Making sense of data | Python enthusiast 📊🐍', 'https://api.dicebear.com/7.x/avataaars/svg?seed=data', false)
ON CONFLICT (username) DO NOTHING;

-- Create some follow relationships
INSERT INTO follows (follower_id, following_id) VALUES
(1, 2), (1, 3), (1, 4),
(2, 1), (2, 3), (2, 5),
(3, 1), (3, 2), (3, 4), (3, 5),
(4, 1), (4, 2),
(5, 3), (5, 1)
ON CONFLICT (follower_id, following_id) DO NOTHING;

-- Insert sample tweets with realistic content
INSERT INTO tweets (user_id, content, hashtags, mentions) VALUES
(1, 'Just deployed my first Kubernetes application! 🚀 The auto-scaling is working beautifully. #k8s #devops', ARRAY['k8s', 'devops'], ARRAY[]::TEXT[]),
(1, 'Coffee break time! ☕ What''s everyone working on today?', ARRAY['coffee'], ARRAY[]::TEXT[]),
(2, 'Working on some exciting AI research. The future is here! 🤖 #AI #MachineLearning', ARRAY['AI', 'MachineLearning'], ARRAY[]::TEXT[]),
(2, 'Just finished a user interview session. The insights are incredible! 💡 #UserResearch', ARRAY['UserResearch'], ARRAY[]::TEXT[]),
(3, 'New blog post: "10 Kubernetes Best Practices for Production" 📝 #kubernetes #bestpractices', ARRAY['kubernetes', 'bestpractices'], ARRAY[]::TEXT[]),
(3, 'The future of cloud computing is serverless + edge computing 🌐 #serverless', ARRAY['serverless'], ARRAY[]::TEXT[]),
(4, 'Discovered an amazing new coffee shop downtown. The espresso is incredible! ☕✨', ARRAY['coffee'], ARRAY[]::TEXT[]),
(4, 'Morning ritual: Grind beans, brew coffee, contemplate life, code ☕💻 #MorningRitual', ARRAY['MorningRitual'], ARRAY[]::TEXT[]),
(5, 'Just finished training a model that predicts coffee consumption based on code commits 📊 #DataScience', ARRAY['DataScience'], ARRAY[]::TEXT[]),
(5, 'Visualization of the day: Network graph of Twitter interactions 📈 #DataViz', ARRAY['DataViz'], ARRAY[]::TEXT[])
ON CONFLICT DO NOTHING;

-- Add some likes to tweets
INSERT INTO likes (user_id, tweet_id) VALUES
(2, 1), (3, 1), (4, 1),
(1, 3), (3, 3), (5, 3),
(1, 5), (2, 5), (4, 5),
(1, 7), (2, 7),
(3, 9), (1, 9)
ON CONFLICT (user_id, tweet_id) DO NOTHING; 