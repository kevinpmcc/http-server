#!/usr/bin/env ruby

require 'socket'

def main
  socket = Socket.new(:INET, :STREAM)
  socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
  socket.bind(Addrinfo.tcp("127.0.0.1", 9000))
  socket.listen(0)
  conn_sock, addr_info = socket.accept
  conn = Connection.new(conn_sock)
  request = read_request(conn)
  respond_for_request(conn_sock, request) 
end

class Connection
  def initialize(conn_sock)
    @conn_sock = conn_sock
    @buffer = ""
  end

  def read_line
    read_until("\r\n")
  end

  def read_until(string)
    until @buffer.include?(string)
      @buffer += @conn_sock.recv(7)
    end
    result, @buffer  = @buffer.split(string, 2)
    result
  end
end

def read_request(conn)
  request_line = conn.read_line
  method, path, version = request_line.split(" ", 3)
  headers = {}
  loop do
    line = conn.read_line
    break if line.empty? 
    key, value = line.split(/:\s*/, 2)
    headers[key] = value
  end
  Request.new(method, path, headers)
end

Request = Struct.new(:method, :path, :headers)

STATUS_CODES_VALUES = {
    200 => "OK",
    404 => "NOT FOUND",
  }

def respond(conn_sock, status_code, content)
  conn_sock.send("HTTP/1.1 #{status_code} #{STATUS_CODES_VALUES[status_code]}\r\n", 0)
  conn_sock.send("Content-Length: #{content.length}\r\n", 0)
  conn_sock.send("\r\n", 0)
  conn_sock.send(content, 0)
end

def respond_for_request(conn_sock, request)
  path = Dir.getwd + request.path
  if File.exist?(path) 
    if File.executable?(path)
      content = `#{path}`
      status_code = 200
    else
      content = File.read(path)
      status_code = 200
    end
  else
    content = ''
    status_code = 404
  end
  respond(conn_sock, status_code, content)
end

main
