Fog.mock!

connection = Fog::Storage.new(
  :provider => 'AWS',
  :aws_access_key_id => Rails.application.secrets[:aws_access_key_id],
  :aws_secret_access_key => Rails.application.secrets[:aws_secret_access_key]
)

connection.directories.create(:key => Rails.application.secrets[:aws_fog_directory])
