require 'rails_helper'

describe TwilioMessageStatusFetcherJob do
  it { expect(subject).to be_a(ActiveJob::Base) }

  describe "#queue_name" do
    it { expect(subject.queue_name).to eq(Rails.application.secrets[:twilio_message_status_fetcher_queue]) }
  end

  describe "#perform(reply_id)", :focus, :vcr, :cassette => :"twilio/get_message" do
    include EnvHelpers
    include ActiveJobHelpers

    let(:twilio_account_sid) { "twilio-account-sid" }
    let(:twilio_auth_token) { "twilio-auth-token" }
    let(:reply) {
      create(
        :reply,
        :twilio_channel,
        :twilio_delivered_by_smsc,
        :with_recorded_twilio_message_sid
      )
    }

    def setup_scenario
      stub_env(:twilio_account_sid => twilio_account_sid, :twilio_auth_token => twilio_auth_token)
      clear_enqueued_jobs
      subject.perform(reply.id)
    end

    before do
      setup_scenario
    end

    TWILIO_MESSAGE_STATUSES = {
      "queued" => {:reply_state => "delivered_by_smsc", :reschedule_job => true},
      "sending" => {:reply_state => "delivered_by_smsc", :reschedule_job => true},
      "sent" => { :reply_state => "unknown", :reschedule_job => false},
      "receiving" => {:reply_state => "delivered_by_smsc", :reschedule_job => true},
      "delivered" => {:reply_state => "confirmed", :reschedule_job => false},
      "undelivered" => {:reply_state => "failed", :reschedule_job => false},
      "failed" => {:reply_state => "errored", :reschedule_job => false}
    }

    def assert_twilio_job!(job, options = {})
      expect(job).to be_present
      expect(job[:args]).to eq([options[:id]]) if options[:id]
      expect(job[:job]).to eq(options[:job_class])
      if options[:scheduled]
        expect(job[:at]).to be_present
      else
        expect(job[:at]).not_to be_present
      end
    end

    def assert_fetch_twilio_message_status_job_enqueued!(job, options = {})
      assert_twilio_job!(job, {:job_class => TwilioMessageStatusFetcherJob, :scheduled => true}.merge(options))
    end

    TWILIO_MESSAGE_STATUSES.each do |twilio_message_status, assertions|

      context "twilio's message state is: '#{twilio_message_status}'", :twilio_message_status => twilio_message_status, :vcr_options => {:match_requests_on => [:method, :twilio_api_request], :erb => {:twilio_status => twilio_message_status}} do

        def assert_update_message_state!(example)
          twilio_message_status = example.metadata[:twilio_message_status]
          assertions = TWILIO_MESSAGE_STATUSES[twilio_message_status]
          reply.reload
          expect(reply.smsc_message_status).to eq(twilio_message_status)
          expect(reply.state).to eq(assertions[:reply_state])
          job = enqueued_jobs.last
          if assertions[:reschedule_job]
            assert_fetch_twilio_message_status_job_enqueued!(job, :id => reply.id)
          else
            expect(enqueued_jobs).to be_empty
          end
        end

        it { |example| assert_update_message_state!(example) }
      end
    end
  end
end
