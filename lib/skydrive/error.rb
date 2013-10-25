module Skydrive
  # The class that handles the errors
  class Error < StandardError
    attr_reader :code, :error_message, :message, :response
    def initialize error, response = nil
      @code = error["code"]
      @error_message = error["message"]
      @response = response
    end

    def message
      "#{code}: #{error_message}"
    end

    alias :to_s :message
  end
end