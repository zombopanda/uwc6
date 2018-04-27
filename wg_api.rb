class WgAPI
  include HTTParty
  base_uri 'https://api.worldoftanks.ru/wot'

  def initialize(api_key, logger)
    @api_key = api_key
    @logger = logger
    self.class.default_params application_id: @api_key
  end

  # define api methods
  %w(globalwar_top clan_info tanks_stats encyclopedia_tankinfo).each do |method|
    define_method method do |*args|
      query = args[0] || {}
      request "/#{method.sub('_', '/')}/", query: query
    end
  end

  private

  # perform request
  def request(url, options = {})
    loop do
      response = self.class.get url, options
      if response['status'] == 'ok'
        @logger.log "perform api request #{url} with #{options.to_json}"
        return response['data']
      end
      sleep 0.1
    end
  end 
end
