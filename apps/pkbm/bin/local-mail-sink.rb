# Development-only SMTP receiver. No forwarding, no published port, no mail UI.
require 'socket'
require 'json'
require 'securerandom'
require 'fileutils'
require 'timeout'
raise 'Local mail receiver only' unless ENV['RAILS_ENV'] == 'development'
folder = '/usr/src/pkbm/tmp/identity-mail'
FileUtils.mkdir_p(folder, mode: 0700)
server = TCPServer.new('0.0.0.0', 1025)
loop do
  socket = server.accept
  Thread.new(socket) do |client|
    begin
      Timeout.timeout(30) do
        client.write("220 pkbm.local local mail receiver\r\n")
        sender = nil; recipients = []
        while (line = client.gets)
          case line
          when /\A(?:EHLO|HELO) /i then client.write("250 pkbm.local\r\n")
          when /\AMAIL FROM:(.*)/i then sender = Regexp.last_match(1).strip; recipients = []; client.write("250 OK\r\n")
          when /\ARCPT TO:(.*)/i then recipients << Regexp.last_match(1).strip; client.write("250 OK\r\n")
          when /\ADATA/i
            client.write("354 End with dot\r\n"); body = +''
            while (part = client.gets) && part != ".\r\n"
              body << part.sub(/\A\.\./, '.')
              raise 'Message too large' if body.bytesize > 1_048_576
            end
            raise 'Incomplete message' unless part
            path = File.join(folder, SecureRandom.uuid + '.json')
            File.write(path, JSON.generate(sender: sender, recipients: recipients, body: body)); File.chmod(0600, path)
            client.write("250 Stored locally\r\n")
          when /\ARSET/i then sender = nil; recipients = []; client.write("250 OK\r\n")
          when /\ANOOP/i then client.write("250 OK\r\n")
          when /\AQUIT/i then client.write("221 Bye\r\n"); break
          else client.write("502 Unsupported\r\n")
          end
        end
      end
    rescue StandardError
      # Never log message bodies or reset links.
    ensure
      client.close
    end
  end
end
