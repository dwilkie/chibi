require 'spec_helper'

describe OutboundCdr do
  include CdrHelpers

  def cdr_body(*args)
    options = args.flatten!.extract_options!
    super(*args, {:variables => {"direction" => "outbound"}}.deep_merge(options))
  end

  let(:cdr) { create_cdr.typed }
  subject { build_cdr.typed }

  describe "factory" do
    it "should be valid" do
      subject.should be_valid
    end
  end

  it "should be valid without an associated incoming cdr" do
    # these can get created before and incoming CDR is received
    subject.bridge_uuid = "invalid"
    subject.should be_valid
  end

  it "should not be valid without a bridge_uuid" do
    subject.save!
    subject.bridge_uuid = nil
    subject.should_not be_valid
  end

  describe "callbacks" do
    describe "before validate on create" do
      context "given an existing related inbound cdr" do
        let(:inbound_cdr) { create_cdr(:variables => {"direction" => "inbound"}) }
        subject { build_cdr(:variables => {"bridge_uuid" => inbound_cdr.uuid}).typed }

        it "should set the related inbound cdr" do
          subject.valid?
          subject.bridge_uuid.should == inbound_cdr.uuid
        end
      end

      context "given no existing related inbound cdr" do
        it "should still set the bridge uuid" do
          subject.valid?
          subject.bridge_uuid.should be_present
        end
      end
    end

    describe "after create" do
      let(:user) { create(:user) }
      let(:friend) { create(:user) }

      context "given there is an existing chat between the caller and the recipient" do
        let(:chat) { create(:chat, :friend_active, :user => user, :friend => friend) }
        subject { build_cdr(:user_who_called => user, :user_who_was_called => friend).typed }

        it "should reactivate the chat" do
          chat.should_not be_active
          subject.save!
          chat.reload.should be_active
        end
      end
    end
  end
end
