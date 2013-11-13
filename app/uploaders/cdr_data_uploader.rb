class CdrDataUploader < CarrierWave::Uploader::Base
  include CarrierWave::MimeTypes

  storage :fog
  process :set_content_type

  private

  def store_dir
    "cdrs/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def extension_white_list
    %w(xml)
  end
end
