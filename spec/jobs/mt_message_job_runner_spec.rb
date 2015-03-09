require 'rails_helper'

describe MtMessageJobRunner do
  it { expect(subject).not_to be_a(ActiveJob::Base) }
  it { expect(subject).not_to respond_to(:perform) }

  describe ".sidekiq_options" do
    it { expect(described_class.sidekiq_options["queue"]).to eq(Rails.application.secrets[:smpp_external_mt_message_queue]) }
  end
end
