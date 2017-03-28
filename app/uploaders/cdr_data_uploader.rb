class CdrDataUploader < CarrierWave::Uploader::Base
  storage :fog

  private

  def store_dir
    "cdrs/#{model.class.to_s.underscore}/#{mounted_as}/#{model.id}"
  end

  def extension_white_list
    %w(xml)
  end
end
