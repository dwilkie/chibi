class User < ActiveRecord::Base
  STATUS = {
    :newbie => 'newbie',
    :registering => 'registering',
    :ready => 'ready',
    :rocking => 'rocking'
  }

  def parse!(text)
    handler.process! text, self
  end

  def handler
    "#{self.status}_handler".classify.constantize.new
  end

  def update_status(value)
    update_attributes :status => STATUS[value]
  end
end
