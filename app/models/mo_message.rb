class MoMessage < ActiveRecord::Base
  attr_accessible :from, :body, :guid
end

