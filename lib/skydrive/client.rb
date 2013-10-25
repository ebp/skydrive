module Skydrive
  # The client class
  class Client
    attr_reader :access_token
    include HTTMultiParty
    include Operations
    base_uri "https://apis.live.net/v5.0/"
    format :json

    def initialize access_token
      @access_token = access_token
      @user_data    = nil
    end

    def user_data
      @user_data  ||= me
    end

    def user_id
      user_data["id"]
    end

    %w( get post put move delete ).each do |method|
      define_method(method.to_sym) do |url, options = {}|
        query      = { access_token: @access_token.token }.update(options.fetch(:query, {}))
        options    = options.merge(query: query)
        return_raw = options.delete(:raw)
        overrides  = options.delete(:overrides) || {}
        response   = self.class.send(method, url, options)

        return_raw ? response : filtered_response(response, overrides)
      end
    end

    # Get the acting user
    # @return [Hash]
    def me
      get("/me")
    end

    # Refresh the access token
    def refresh_access_token!
      @access_token = access_token.refresh!
    end

    # Return a Skdrive::Object sub class
    def object response
      if response.is_a? Array
        return response.collect{ |object| "Skydrive::#{object["type"].capitalize}".constantize.new(self, object)}
      else
        return "Skydrive::#{response["type"].capitalize}"
      end
    end

    def search_files(file_query, options = {})
      options = options.dup
      options[:query] ||= {}
      options[:query].update(q: file_query.to_s)
      get("/me/skydrive/search", options)
    end

    def upload(remote_path, file_name, content, options = {})
      file_name = file_name.to_s
      content   = content.respond_to?(:read) ? content.read.to_s : content.to_s
      size      = ( content.bytesize rescue content.size )
      nl        = "\r\n"
      boundary  = 'A300x'
      body      = ''
      body << '--' << boundary << nl
      body << 'Content-Disposition: form-data; name="file"; filename=' << file_name.dump << nl
      body << 'Content-Type: application/octet-stream' << nl << nl
      body << content << nl
      body << '--' << boundary << '--' << nl

      extra_properties = { 'size' => size, 'from' => user_data }
      headers          = { 'Content-Type' => "multipart/form-data; boundary=#{ boundary }" }

      options =
        options.merge(
          body:        body,
          headers:     headers.update(options.fetch(:headers, {})),
          overrides:   extra_properties.update(options.fetch(:overrides, {}))
        )

      post(remote_path, options)
    end

    private

    # Filter the response after checking for any errors
    def filtered_response response, overrides = {}
      raise Skydrive::Error.new({"code" => "no_response_received", "message" => "Request didn't make through or response not received"}) unless response
      if response.success?
        filtered_response = response.parsed_response
        filtered_response.update(overrides) if filtered_response.is_a?(::Hash)

        if response.response.code =~ /^2/
          raise Skydrive::Error.new(filtered_response["error"], response) if filtered_response["error"]
          if filtered_response["data"]
            return Skydrive::Collection.new(self, filtered_response["data"])
          elsif filtered_response["location"]
            return filtered_response
          elsif filtered_response.key?("id") && type = filtered_response["id"].to_s[/^(comment|file)\./, 1]
            return Skydrive.const_get(type.capitalize).new(self, filtered_response)
          elsif filtered_response.key?("type")
            return "Skydrive::#{filtered_response["type"].capitalize}".constantize.new(self, filtered_response)
          else
            return filtered_response
          end
        else
          return true
        end
      else
        raise Skydrive::Error.new({"code" => "http_error_#{response.response.code}", "message" => response.response.message}, response)
      end
    end

  end
end