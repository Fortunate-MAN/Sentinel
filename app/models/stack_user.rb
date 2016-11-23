class StackUser < ApplicationRecord
  belongs_to :user

  def update_details
    api_key = Rails.application.config.se_api_key
    api_response = HTTParty.get("https://api.stackexchange.com/2.2/users/me?key=#{api_key}&access_token=#{self.access_token}&site=stackoverflow&filter=!bWUXTP2WcWld0F")
    if api_response.status == 200
      user_json = api_response.parsed_response
      self.network_id = user_json['items'][0]['account_id']
      self.username = user_json['items'][0]['display_name']

      # Haaaaaaaaack.
      self.chat_so_id = Net::HTTP.get_response(URI.parse("http://chat.stackoverflow.com/accounts/#{stack_exchange_account_id}"))["location"].scan(/\/users\/(\d*)\//)[0][0]

      self.save
    else
      false
    end
  end
end