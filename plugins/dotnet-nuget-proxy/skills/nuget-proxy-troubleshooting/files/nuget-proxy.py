#!/usr/bin/env python3
"""
HTTP/HTTPS proxy for NuGet that forwards requests through the authenticated Claude Code proxy.
This allows NuGet to work with the environment's authentication requirements.
Supports both regular HTTP requests and HTTPS CONNECT tunneling.
"""

import http.server
import urllib.request
import urllib.error
import urllib.parse
import socket
import select
import os
import sys
from socketserver import ThreadingMixIn

# Get the authenticated proxy from environment
UPSTREAM_PROXY = os.environ.get('https_proxy') or os.environ.get('HTTPS_PROXY')

if not UPSTREAM_PROXY:
    print("ERROR: No https_proxy environment variable found!")
    sys.exit(1)

print(f"Using upstream proxy: {UPSTREAM_PROXY[:50]}...")  # Print first 50 chars

# Parse upstream proxy URL
parsed_proxy = urllib.parse.urlparse(UPSTREAM_PROXY)
PROXY_HOST = parsed_proxy.hostname
PROXY_PORT = parsed_proxy.port or 8080
PROXY_AUTH = None

# Extract authentication from proxy URL if present
if parsed_proxy.username:
    import base64
    auth_string = f"{parsed_proxy.username}:{parsed_proxy.password or ''}"
    PROXY_AUTH = base64.b64encode(auth_string.encode()).decode()

class ProxyHandler(http.server.BaseHTTPRequestHandler):
    timeout = 60

    def do_CONNECT(self):
        """Handle HTTPS CONNECT tunneling"""
        try:
            # Parse the target host and port
            host, port = self.path.split(':')
            port = int(port)

            # Connect to upstream proxy
            proxy_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            proxy_sock.settimeout(30)

            print(f"Connecting to upstream proxy {PROXY_HOST}:{PROXY_PORT} for {host}:{port}")
            proxy_sock.connect((PROXY_HOST, PROXY_PORT))

            # Send CONNECT request to upstream proxy with authentication
            connect_req = f"CONNECT {host}:{port} HTTP/1.1\r\n"
            connect_req += f"Host: {host}:{port}\r\n"

            # Add proxy authentication if available
            if PROXY_AUTH:
                connect_req += f"Proxy-Authorization: Basic {PROXY_AUTH}\r\n"

            connect_req += "\r\n"

            proxy_sock.sendall(connect_req.encode())

            # Read response from upstream proxy
            response = b""
            while b"\r\n\r\n" not in response:
                chunk = proxy_sock.recv(4096)
                if not chunk:
                    break
                response += chunk

            # Check if upstream proxy accepted the CONNECT
            if b"200" in response.split(b"\r\n")[0]:
                # Send success to client
                self.send_response(200, "Connection Established")
                self.send_header("Proxy-agent", "NuGet-Proxy")
                self.end_headers()

                # Start tunneling
                self._tunnel_traffic(self.connection, proxy_sock)
            else:
                print(f"Upstream proxy refused CONNECT: {response.decode('utf-8', errors='ignore')}")
                self.send_error(502, "Bad Gateway - Upstream proxy refused connection")

        except Exception as e:
            print(f"Error in CONNECT: {e}")
            import traceback
            traceback.print_exc()
            self.send_error(502, f"Bad Gateway: {str(e)}")

    def _tunnel_traffic(self, client_sock, proxy_sock):
        """Tunnel traffic between client and upstream proxy"""
        try:
            sockets = [client_sock, proxy_sock]
            timeout = 60

            while True:
                readable, _, exceptional = select.select(sockets, [], sockets, timeout)

                if exceptional:
                    break

                if not readable:
                    break

                for sock in readable:
                    try:
                        data = sock.recv(8192)
                        if not data:
                            return

                        # Forward data to the other socket
                        if sock is client_sock:
                            proxy_sock.sendall(data)
                        else:
                            client_sock.sendall(data)
                    except:
                        return
        except:
            pass
        finally:
            try:
                proxy_sock.close()
            except:
                pass

    def do_GET(self):
        self.proxy_request()

    def do_POST(self):
        self.proxy_request()

    def do_HEAD(self):
        self.proxy_request()

    def do_PUT(self):
        self.proxy_request()

    def proxy_request(self):
        try:
            # Build the full URL
            url = self.path if self.path.startswith('http') else f"http://{self.headers['Host']}{self.path}"

            # Read request body if present
            content_length = int(self.headers.get('Content-Length', 0))
            body = self.rfile.read(content_length) if content_length > 0 else None

            # Create request with authenticated proxy
            req = urllib.request.Request(url, data=body, method=self.command)

            # Copy headers
            for key, value in self.headers.items():
                if key.lower() not in ['host', 'connection', 'proxy-connection']:
                    req.add_header(key, value)

            # Setup proxy handler
            proxy_handler = urllib.request.ProxyHandler({
                'http': UPSTREAM_PROXY,
                'https': UPSTREAM_PROXY
            })
            opener = urllib.request.build_opener(proxy_handler)

            # Make the request
            response = opener.open(req, timeout=30)

            # Send response
            self.send_response(response.status)
            for key, value in response.headers.items():
                self.send_header(key, value)
            self.end_headers()

            # Send body
            self.wfile.write(response.read())

        except urllib.error.HTTPError as e:
            self.send_response(e.code)
            self.end_headers()
            if e.fp:
                self.wfile.write(e.fp.read())
        except Exception as e:
            print(f"Error proxying request: {e}")
            self.send_response(502)
            self.end_headers()
            self.wfile.write(f"Proxy Error: {str(e)}".encode())

    def log_message(self, format, *args):
        # Simplified logging
        print(f"{self.command} {args[0]}")

class ThreadedHTTPServer(ThreadingMixIn, http.server.HTTPServer):
    """Handle requests in a separate thread."""
    daemon_threads = True

if __name__ == '__main__':
    PORT = 8888
    server = ThreadedHTTPServer(('127.0.0.1', PORT), ProxyHandler)
    print(f"NuGet Proxy Server running on http://127.0.0.1:{PORT}")
    print("Configure NuGet to use this proxy and run dotnet build")
    print("")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down proxy server...")
        server.shutdown()
