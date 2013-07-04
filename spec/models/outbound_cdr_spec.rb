require 'spec_helper'

describe OutboundCdr do
  include CdrHelpers

  def cdr_body(*args)
    options = args.flatten!.extract_options!
    super(*args, {:variables => {"direction" => "outbound"}}.deep_merge(options))
  end

  let(:cdr) { create_cdr }
  subject { build_cdr }

  describe "factory" do
    it "should be valid" do
      subject.should be_valid
    end
  end

  it "should not be valid without a bridge_uuid" do
    subject.save!
    subject.bridge_uuid = nil
    subject.should_not be_valid
  end

  it "should not be valid without a related user" do
    build_cdr(:variables => {"sip_to_user" => "invalid", "destination_number" => "invalid"}).should_not be_valid
  end

  describe "callbacks" do
    describe "before validate on create" do
      context "given an existing related inbound cdr" do
        let(:inbound_cdr) { create_cdr(:variables => {"direction" => "inbound"}) }
        subject { build_cdr(:variables => {"bridge_uuid" => inbound_cdr.uuid}) }

        it "should set the related inbound cdr" do
          subject.valid?
          subject.inbound_cdr.should == inbound_cdr
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

      include MessagingHelpers
      include TranslationHelpers
      include_context "replies"

      context "given there is an existing chat between the caller and the recipient" do
        def build_cdr(options = {})
          super({:user_who_called => user, :user_who_was_called => friend}.merge(options))
        end

        let!(:chat) { create(:chat, :friend_active, :user => user, :friend => friend) }
        subject { build_cdr }

        it "should reactivate the chat" do
          chat.should_not be_active
          subject.save!
          chat.reload.should be_active
        end

        it "should send a canned message to the caller from the receiver and to the receiver from the caller" do
          expect_message { subject.save! }
          reply_to(user, chat).body.should =~ /#{spec_translate(:forward_message_approx, user.locale, friend.screen_id)}/
          reply_to(friend, chat).body.should =~ /#{spec_translate(:forward_message_approx, friend.locale, user.screen_id)}/
        end
      end
    end
  end
end
