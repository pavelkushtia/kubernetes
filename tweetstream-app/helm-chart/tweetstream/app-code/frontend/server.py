#!/usr/bin/env python3
"""
Simple HTTP server for TweetStream frontend
Serves static files properly including CSS and JS
"""

import http.server
import socketserver
import os
from urllib.parse import urlparse

class TweetStreamHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        # Parse the URL
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        # Handle health check
        if path == '/health':
            self.send_response(200)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'healthy')
            return
        
        # Handle root path - serve index.html
        if path == '/' or path == '/index.html':
            self.serve_file('index.html', 'text/html')
            return
        
        # Handle CSS files
        if path.endswith('.css'):
            self.serve_file(path[1:], 'text/css')  # Remove leading slash
            return
        
        # Handle JS files
        if path.endswith('.js'):
            self.serve_file(path[1:], 'application/javascript')  # Remove leading slash
            return
        
        # Default to index.html for SPA routing
        self.serve_file('index.html', 'text/html')
    
    def serve_file(self, filename, content_type):
        try:
            with open(filename, 'r', encoding='utf-8') as f:
                content = f.read()
            
            self.send_response(200)
            self.send_header('Content-type', content_type + '; charset=utf-8')
            self.send_header('Cache-Control', 'no-cache')
            self.end_headers()
            self.wfile.write(content.encode('utf-8'))
        except FileNotFoundError:
            self.send_response(404)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(b'File not found')
        except Exception as e:
            self.send_response(500)
            self.send_header('Content-type', 'text/plain')
            self.end_headers()
            self.wfile.write(f'Server error: {str(e)}'.encode('utf-8'))

if __name__ == "__main__":
    PORT = 8080
    
    # Change to the directory containing the files
    os.chdir('/app')
    
    with socketserver.TCPServer(("", PORT), TweetStreamHandler) as httpd:
        print(f"TweetStream frontend server running on port {PORT}")
        print(f"Files in directory: {os.listdir('.')}")
        httpd.serve_forever() 