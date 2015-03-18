require 'rails_helper'

describe "all internal queues" do
  def internal_queues_used_by_application
    Rails.application.secrets.select do |key, value|
      key_name = key.to_s
      key_name =~ /queue$/ && key_name !~ /external/
    end.values.uniq
  end

  it "should be defined" do
    expect(Rails.application.secrets[:internal_queues].to_s.split(":").sort).to eq(internal_queues_used_by_application.sort)
  end
end
