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
    end

    %w( get post put move delete ).each do |method|
      define_method(method.to_sym) do |url, options = {}|
        query      = { access_token: @access_token.token }.update( options.fetch( :query, {} ) )
        options    = options.merge( query: query )
        return_raw = options.delete( :raw )
        response   = self.class.send(method, url, options)

        return_raw ? response : filtered_response(response)
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

    def upload(remote_path, file_name, content)
      file_name = file_name.to_s
      content   = content.respond_to?(:read) ? content.read.to_s : content.to_s
      nl        = "\r\n"
      boundary  = 'A300x'
      body      = ''
      body << '--' << boundary << nl
      body << 'Content-Disposition: form-data; name="file"; filename=' << file_name.dump << nl
      body << 'Content-Type: application/octet-stream' << nl << nl
      body << content << nl
      body << '--' << boundary << '--' << nl

      headers = { 'Content-Type' => "multipart/form-data; boundary=#{ boundary }" }
      post(remote_path, headers: headers, body: body, format: :plain)
    end

    private

    # Filter the response after checking for any errors
    def filtered_response response
      raise Skydrive::Error.new({"code" => "no_response_received", "message" => "Request didn't make through or response not received"}) unless response
      if response.success?
        filtered_response = response.parsed_response
        if response.response.code == "200"
          raise Skydrive::Error.new(filtered_response["error"], response) if filtered_response["error"]
          if filtered_response["data"]
            return Skydrive::Collection.new(self, filtered_response["data"])
          elsif filtered_response["location"]
            return filtered_response
          elsif filtered_response["id"].match(/^comment\..+/)
            return Skydrive::Comment.new(self, filtered_response)
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