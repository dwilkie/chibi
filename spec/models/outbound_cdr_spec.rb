require 'rails_helper'

describe OutboundCdr do
  include CdrHelpers

  def cdr_body(*args)
    options = args.flatten!.extract_options!
    super(*args, {:cdr_variables => {"variables" => {"direction" => "outbound"}}}.deep_merge(options))
  end

  let(:cdr) { create_cdr }
  subject { build_cdr }

  describe "factory" do
    it "should be valid" do
      subject.should be_valid
    end
  end

  it "should not be valid without a related user" do
    build_cdr(
      :cdr_variables => {
        "variables" => {"sip_to_user" => "invalid"},
        "callflow" => {
          "caller_profile" => {"destination_number" => "invalid"}
        }
      }
    ).should_not be_valid
  end

  it_should_behave_like "communicable from user", :passive => true do
    let(:communicable_resource) { cdr }
  end

  describe "callbacks" do
    describe "before_validation(:on => :create)" do
      context "given a bridge_uuid" do
        subject do
          build_cdr(
            :cdr_variables => {"variables" => {"bridge_uuid" => bridge_uuid}}
          )
        end

        let(:bridge_uuid) { generate(:guid) }

        context "and an existing related inbound cdr" do
          let(:inbound_cdr) do
            create_cdr(
              :cdr_variables => {"variables" => {"direction" => "inbound"}}
            )
          end

          let(:bridge_uuid) { inbound_cdr.uuid }

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

        context "given there's a related phone call" do
          let(:phone_call) { create(:phone_call) }
          let(:bridge_uuid) { phone_call.sid }

          it "should set the related phone call" do
            subject.valid?
            subject.phone_call.should == phone_call
          end
        end

        context "when parsing the destination number" do
          include MobilePhoneHelpers

          def build_cdr(options = {})
            super(
              :cdr_variables => {
                "variables" => {
                  "sip_to_user" => options[:sip_to_user],
                  "sip_to_host" => options[:sip_to_host],
                },
                "callflow" => {
                  "caller_profile" => {"network_addr" => options[:network_addr]}
                }
              }
            )
          end

          it "should strip off the dial string number prefix" do
            with_operators do |number_parts, assertions|
              number = number_parts.join
              default_cdr_options = {:sip_to_user => assertions["dial_string_number_prefix"].to_s + number}

              cdr = build_cdr(default_cdr_options.merge(:sip_to_host => assertions["voip_gateway_host"]))
              cdr.valid?
              cdr.from.should == number

              cdr = build_cdr(default_cdr_options.merge(:sip_to_host => "invalid", :network_addr => assertions["voip_gateway_host"]))
              cdr.valid?
              cdr.from.should == number
            end
          end
        end
      end
    end

    describe "after_create" do
      let(:user) { create(:user) }
      let(:friend) { create(:user) }

      include MessagingHelpers
      include TranslationHelpers
      include_context "replies"

      context "given there is an existing chat between the caller and the recipient" do

        let(:phone_call) { create(:phone_call, :user => user) }

        subject {
          build_cdr(
            :user_who_called => user,
            :user_who_was_called => friend,
            :cdr_variables => {"variables" => {"bridge_uuid" => phone_call.sid}}
          )
        }

        context "which is not active" do
          let!(:chat) {
            create(:chat, :friend_active, :user => user, :friend => friend)
          }


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

        context "which is currently active" do
          let!(:chat) { create(:chat, :active, :user => user, :friend => friend) }
          it "should not send any canned messages" do
            chat.should be_active
            subject.save!
            chat.reload.should be_active
            reply_to(user, chat).should be_nil
            reply_to(friend, chat).should be_nil
          end
        end
      end
    end
  end
end
