require 'rails_helper'

describe "PhoneCalls" do
  include PhoneCallHelpers
  include PhoneCallHelpers::TwilioHelpers
  include TwilioHelpers::TwimlAssertions::RSpec
  include MobilePhoneHelpers
  include ActiveJobHelpers

  let(:twiml) { response.body }
  let(:caller) { create(:user, :mobile_number => my_number) }
  let(:phone_call) { PhoneCall.last! }
  let(:my_number) { generate(:mobile_number) }

  context "when I call" do
    let(:asserted_locale) { "kh" }
    let(:asserted_filename) { "#{asserted_locale}/ringback_tone.mp3" }
    let(:asserted_redirect_url) { phone_call_url(phone_call, :format => :xml) }
    let(:phone_call_params) { {:api_version => sample_adhearsion_twilio_api_version} }

    def make_call(options = {})
      super(phone_call_params.merge(options))
    end

    def update_phone_call(phone_call, options = {})
      super(phone_call, phone_call_params.merge(options))
    end

    def get_phone_call(phone_call, options = {})
      super(phone_call, phone_call_params.merge(options))
    end

    before do
      make_call(:from => my_number)
    end

    it "should redirect back to the call" do
      assert_redirect!
    end

    context "after the ringback tone has been played" do
      def setup_scenario
      end

      before do
        setup_scenario
        trigger_job { update_phone_call(phone_call) }
      end

      xit "should redirect to the phone call" do
        assert_redirect!(:method => "GET")
      end

      context "in the meantime" do
        context "if the charge failed" do
          def setup_scenario
            create(:charge_request, :failed, :requester => phone_call)
          end

          context "when the twiml is requested" do
            let(:asserted_filename) { "#{asserted_locale}/not_enough_credit.mp3" }

            before do
              get_phone_call(phone_call)
            end

            it "should play a file telling the user they don't have enough credit" do
              assert_play!
              assert_redirect!
            end
          end

          context "after the file has been played" do
            before do
              trigger_job { update_phone_call(phone_call) }
            end

            xit "should redirect to the phone call" do
              assert_redirect!(:method => "GET")
            end

            context "when the twiml is requested" do
              before do
                get_phone_call(phone_call)
              end

              it "should hangup" do
                assert_hangup!
              end
            end
          end
        end

        context "if there are friends available" do
          let(:friend) { create(:user, :mobile_number => friends_number) }
          let(:friends_number) { registered_operator(:number) }

          def setup_scenario
            friend
          end

          context "when the twiml is requested" do
            before do
              get_phone_call(phone_call)
            end

            it "should redirect to update the phone call" do
              assert_redirect!
            end

            context "when the phone call is updated again" do
              before do
                trigger_job { update_phone_call(phone_call) }
              end

              xit "should redirect to the phone call" do
                assert_redirect!(:method => "GET")
              end

              context "when the twiml is requested again" do
                before do
                  get_phone_call(phone_call)
                end

                it "should dial friends" do
                  assert_dial! do |dial_twiml|
                    assert_numbers_dialed!(dial_twiml, 1)

                    assert_number!(
                      dial_twiml,
                      interpolated_assertion(
                        registered_operator(:dial_string),
                        :number_to_dial => friends_number,
                        :dial_string_number_prefix => registered_operator(:dial_string_number_prefix),
                        :voip_gateway_host => registered_operator(:voip_gateway_host)
                      ),
                      :callerId => registered_operator(:caller_id),
                      :index => 0
                    )
                  end
                end

                context "after the dial has completed (and the call was connected)" do
                  before do
                    trigger_job { update_phone_call(phone_call, :dial_call_status => "completed") }
                  end

                  xit "should redirect to the phone call" do
                    assert_redirect!(:method => "GET")
                  end

                  context "when the twiml is requested again" do
                    before do
                      get_phone_call(phone_call)
                    end

                    it "should hang up" do
                      assert_hangup!
                    end
                  end
                end
              end
            end
          end
        end

        context "if the caller is already in a chat" do
          let(:partner) { create(:user, :mobile_number => partners_number) }

          let(:partners_number) { registered_operator(:number) }

          let(:asserted_number_to_dial) do
            interpolated_assertion(
              registered_operator(:dial_string),
              :number_to_dial => partners_number,
              :dial_string_number_prefix => registered_operator(:dial_string_number_prefix),
              :voip_gateway_host => registered_operator(:voip_gateway_host)
            )
          end

          let(:asserted_caller_id) { registered_operator(:caller_id) }

          def setup_scenario
            create(:chat, :active, :user => phone_call.user, :friend => partner)
          end

          context "when the twiml is requested" do
            before do
              get_phone_call(phone_call)
            end

            it "should connect the caller with his friend" do
              assert_dial! do |dial_twiml|
                assert_number!(dial_twiml, asserted_number_to_dial, :callerId => asserted_caller_id)
              end
            end
          end

          context "after the friend has been connected" do
            before do
              trigger_job { update_phone_call(phone_call, :dial_call_status => "completed") }
            end

            xit "should redirect to the phone call" do
              assert_redirect!(:method => "GET")
            end

            context "when the twiml is requested" do
              before do
                get_phone_call(phone_call)
              end

              it "should hangup" do
                assert_hangup!
              end
            end
          end
        end
      end
    end
  end
end
