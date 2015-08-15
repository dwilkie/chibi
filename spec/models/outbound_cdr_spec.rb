require 'rails_helper'

describe OutboundCdr do
  include CdrHelpers

  def cdr_body(*args)
    options = args.flatten!.extract_options!
    super(*args, {:cdr_variables => {"variables" => {"direction" => "outbound"}}}.deep_merge(options))
  end

  let(:cdr) { create_cdr }
  subject { build_cdr }

  describe "validations" do
    describe "#user" do
      subject {
        build_cdr(
          :cdr_variables => {
            "variables" => {"sip_to_user" => "invalid"},
            "callflow" => {
              "caller_profile" => {"destination_number" => "invalid"}
            }
          }
        )
      }

      it { is_expected.not_to be_valid }
    end
  end

  it_should_behave_like "communicable from user", :passive => true do
    subject { cdr }
  end

  describe "initialization" do
    subject { CallDataRecord.new(:body => File.read("#{fixture_path}/outbound_cdr.xml")).typed }

    before do
      subject.save!
    end

    it "should extract the correct data" do
      # assertions are from fixture
      expect(subject).to be_a(OutboundCdr)
      expect(subject.uuid).to eq("3415f9c3-2e76-46c8-84d8-e15103b1d3d3")
      expect(subject.duration).to eq(31)
      expect(subject.bill_sec).to eq(0)
      expect(subject.bridge_uuid).to eq("359b1cf0-f0dc-11e4-859e-f3ff45d0abdc")
      expect(subject.from).to eq("85589481811")
      expect(subject.phone_call).to eq(nil)
    end
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
            expect(subject.inbound_cdr).to eq(inbound_cdr)
          end
        end

        context "given no existing related inbound cdr" do
          it "should still set the bridge uuid" do
            subject.valid?
            expect(subject.bridge_uuid).to be_present
          end
        end

        context "given there's a related phone call" do
          let(:phone_call) { create(:phone_call) }
          let(:bridge_uuid) { phone_call.sid }

          it "should set the related phone call" do
            subject.valid?
            expect(subject.phone_call).to eq(phone_call)
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
              expect(cdr.from).to eq(number)

              cdr = build_cdr(default_cdr_options.merge(:sip_to_host => "invalid", :network_addr => assertions["voip_gateway_host"]))
              cdr.valid?
              expect(cdr.from).to eq(number)
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
          let(:chat) {
            create(:chat, :friend_active, :user => user, :friend => friend)
          }

          before do
            chat
          end

          it "should reactivate the chat" do
            expect(chat).not_to be_active
            subject.save!
            expect(chat.reload).to be_active
          end

          context "canned messages" do
            before do
              subject.save!
            end

            it { expect(reply_to(user, chat).body).to match(/#{spec_translate(:forward_message_approx, user.locale, friend.screen_id)}/) }
            it {  expect(reply_to(friend, chat).body).to match(/#{spec_translate(:forward_message_approx, friend.locale, user.screen_id)}/) }
          end
        end

        context "which is currently active" do
          let!(:chat) { create(:chat, :active, :user => user, :friend => friend) }
          it "should not send any canned messages" do
            expect(chat).to be_active
            subject.save!
            expect(chat.reload).to be_active
            expect(reply_to(user, chat)).to be_nil
            expect(reply_to(friend, chat)).to be_nil
          end
        end
      end
    end
  end
end
