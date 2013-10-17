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
        options = { access_token: @access_token.token }.update(options)
        filtered_response(self.class.send(method, url, query: options))
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

    private

    # Filter the response after checking for any errors
    def filtered_response response
      raise Skydrive::Error.new({"code" => "no_response_received", "message" => "Request didn't make through or response not received"}) unless response
      if response.success?
        filtered_response = response.parsed_response
        if response.response.code == "200"
          raise Skydrive::Error.new(filtered_response["error"]) if filtered_response["error"]
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
        raise Skydrive::Error.new("code" => "http_error_#{response.response.code}", "message" => response.response.message)
      end
    end

  end
end