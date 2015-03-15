require 'rails_helper'

describe MessagePart do
  describe "associations" do
    it { is_expected.to belong_to(:message) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:sequence_number) }
    it { is_expected.to validate_presence_of(:body) }
  end
end
