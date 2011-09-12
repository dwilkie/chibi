## Tropo

ActionSms::Base.establish_connection(
  :adapter => "tropo",
  :outgoing_token => ENV['TROPO_OUTGOING_TOKEN'],
  :authentication_key => ENV['SMS_AUTHENTICATION_KEY'],
  :use_ssl => true,
  :environment => Rails.env
)

