require "net/http"
require "uri"
require "json"
class CanvasApi
  class Error < StandardError
    attr_reader :status
    def initialize(status, message)
      @status = status
      super(message)
    end
  end
  def initialize(instance)
    @instance = instance
    @base = URI(instance.api_base_url)
    raise Error.new(0, "Canvas API origin tidak diizinkan") unless instance.api_base_url == ENV.fetch("CANVAS_API_BASE_URL", "http://web:3000")
    @token = instance.credentials.fetch("access_token")
  end

  def request(method, path, data = nil, allow_missing: false, redirects: 0)
    raise Error.new(0, "Path API tidak diizinkan") unless path.start_with?("/api/v1/")
    uri = URI.join(@base.to_s, path)
    raise Error.new(0, "API origin berubah") unless uri.host == @base.host && uri.port == @base.port && uri.scheme == @base.scheme
    klass = { "GET" => Net::HTTP::Get, "POST" => Net::HTTP::Post, "PUT" => Net::HTTP::Put, "DELETE" => Net::HTTP::Delete }.fetch(method)
    req = klass.new(uri.request_uri)
    req["Authorization"] = "Bearer #{@token}"
    req["Accept"] = "application/json"
    # Canvas resolves its root account from the configured public Host.
    req["Host"] = URI(@instance.public_base_url).authority
    if data
      req["Content-Type"] = "application/json"
      req.body = JSON.generate(data)
    end
    http = Net::HTTP.new(uri.host, uri.port, nil)
    http.use_ssl = uri.scheme == "https"
    http.open_timeout = 5
    http.read_timeout = 30
    response = http.request(req)
    if method == "GET" && [301,302,303,307,308].include?(response.code.to_i) && redirects < 3
      next_uri = URI.join(uri.to_s, response.fetch("Location"))
      public_uri = URI(@instance.public_base_url)
      if next_uri.host == public_uri.host && next_uri.port == public_uri.port && next_uri.scheme == public_uri.scheme
        next_uri = URI.join(@base.to_s, next_uri.request_uri)
      end
      raise Error.new(0, "Redirect Canvas keluar origin") unless next_uri.host == @base.host && next_uri.port == @base.port && next_uri.scheme == @base.scheme
      return request("GET", next_uri.request_uri, nil, allow_missing: allow_missing, redirects: redirects + 1)
    end
    return nil if allow_missing && response.code.to_i == 404
    raise Error.new(response.code.to_i, "Canvas #{method} gagal HTTP #{response.code}") unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)
  rescue Timeout::Error, SocketError, IOError, SystemCallError => error
    raise Error.new(0, "Koneksi Canvas gagal (#{error.class.name})")
  rescue JSON::ParserError
    raise Error.new(0, "Canvas tidak mengembalikan JSON")
  end

  def list(path)
    result = []
    (1..100).each do |page|
      rows = request("GET", path + (path.include?("?") ? "&" : "?") + "per_page=100&page=#{page}")
      raise Error.new(0, "Daftar Canvas tidak sesuai") unless rows.is_a?(Array)
      result.concat(rows)
      return result if rows.length < 100
    end
    raise Error.new(0, "Pagination Canvas melampaui batas; hentikan agar tidak salah rekonsiliasi")
  end
end
