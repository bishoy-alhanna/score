#!/usr/bin/env python3
"""
Simple CORS proxy server for Flutter web app
"""
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import urlparse, parse_qs
from urllib.request import urlopen, Request
from urllib.error import URLError
import ssl

class CORSProxyHandler(BaseHTTPRequestHandler):
    TARGET_URL = 'http://score.al-hanna.com'
    
    def do_OPTIONS(self):
        """Handle preflight CORS requests"""
        self.send_response(200)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization, X-Requested-With')
        self.send_header('Access-Control-Max-Age', '3600')
        self.end_headers()
    
    def do_GET(self):
        self._proxy_request()
    
    def do_POST(self):
        self._proxy_request()
    
    def do_PUT(self):
        self._proxy_request()
    
    def do_DELETE(self):
        self._proxy_request()
    
    def _proxy_request(self):
        try:
            # Get request data for POST/PUT
            content_length = int(self.headers.get('Content-Length', 0))
            post_data = self.rfile.read(content_length) if content_length > 0 else None
            
            # Build target URL
            target_url = self.TARGET_URL + self.path
            print(f"Proxying {self.command} request to: {target_url}")
            
            # Create request
            req = Request(target_url, data=post_data, method=self.command)
            
            # Copy relevant headers
            for header, value in self.headers.items():
                if header.lower() not in ['host', 'content-length']:
                    req.add_header(header, value)
            
            # Make request
            response = urlopen(req, timeout=30)
            
            # Send response
            self.send_response(response.getcode())
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Origin, Content-Type, Accept, Authorization, X-Requested-With')
            
            # Copy response headers
            for header, value in response.headers.items():
                if header.lower() not in ['access-control-allow-origin']:
                    self.send_header(header, value)
            
            self.end_headers()
            
            # Send response body
            self.wfile.write(response.read())
            
        except URLError as e:
            print(f"Proxy error: {e}")
            self.send_response(500)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            error_response = json.dumps({
                'error': 'Proxy error',
                'message': str(e)
            }).encode('utf-8')
            self.wfile.write(error_response)
        except Exception as e:
            print(f"Unexpected error: {e}")
            self.send_response(500)
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            error_response = json.dumps({
                'error': 'Internal server error',
                'message': str(e)
            }).encode('utf-8')
            self.wfile.write(error_response)

def run_proxy_server(port=3001):
    server_address = ('', port)
    httpd = HTTPServer(server_address, CORSProxyHandler)
    print(f"CORS Proxy server running on http://localhost:{port}")
    print(f"Proxying API requests to http://score.al-hanna.com")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down proxy server...")
        httpd.shutdown()

if __name__ == '__main__':
    run_proxy_server()