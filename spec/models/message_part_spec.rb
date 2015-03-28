require 'rails_helper'

describe MessagePart do
  include ActiveJobHelpers

  describe "associations" do
    it { is_expected.to belong_to(:message) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:sequence_number) }
    it { is_expected.to validate_presence_of(:body) }
  end

  describe "#process!" do
    let(:original_message) { create(:message, :awaiting_parts) }
    let(:created_at) { Time.now }
    let(:csms_reference_number) { original_message.csms_reference_number }
    let(:job) { enqueued_jobs.first }

    let(:new_message) {
      create(
        :message,
        :awaiting_parts,
        :csms_reference_number => csms_reference_number,
        :from => original_message.from,
        :to => original_message.to,
        :channel => original_message.channel,
        :created_at => created_at
      )
    }

    subject {
      create(
        :message_part,
        :sequence_number => sequence_number,
        :message => new_message
      )
    }

    before do
      expect(subject.message).to eq(new_message)
      subject.process!
      subject.reload
      original_message.reload
    end

    context "the part belongs to another message" do
      let(:sequence_number) { original_message.number_of_parts }

      it "should set this part to belong to the original message" do
        expect(subject.message).to eq(original_message)
        expect(original_message).not_to be_awaiting_parts
        expect(job[:job]).to eq(MessageProcessorJob)
        expect(job[:args]).to eq([original_message.id])
      end

      context "but the message cannot yet be found" do
        let(:csms_reference_number) { 123 }

        context "and the message has not been awaiting parts too long" do
          it "should schedule the job to be reprocessed" do
            expect(job[:job]).to eq(MessagePartProcessorJob)
            expect(job[:args]).to eq([subject.id])
            expect(job[:at]).to be_present
          end
        end

        context "but the message has been awaiting parts too long" do
          let(:configured_timeout) { (Rails.application.secrets[:message_awaiting_parts_timeout] || 300).to_i }
          let(:created_at) { configured_timeout.seconds.ago }

          it "should should give up awaiting parts and process the message" do
            expect(subject.message).to eq(new_message)
            expect(new_message).not_to be_awaiting_parts
            expect(job[:job]).to eq(MessageProcessorJob)
            expect(job[:args]).to eq([new_message.id])
          end
        end
      end
    end

    context "the part is the first in the sequence" do
      let(:sequence_number) { 1 }

      it "should do nothing" do
        expect(subject.message).to eq(new_message)
        expect(job).to eq(nil)
      end
    end
  end
end
