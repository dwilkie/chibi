require 'spec_helper'

describe "PhoneCalls" do

  describe "POST /phone_calls.xml" do
    include PhoneCallHelpers

    include_context "existing users"
    include_context "twiml"

    let(:my_number) { "8553243313" }
    let(:twiml_response) { parse_twiml(response.body) }

    def current_call(options = {})
      @call_sid ||= make_call(options)
    end

    alias :call :current_call

    def assert_redirect_to_current_url
      assert_redirect(twiml_response, phone_calls_url)
    end

    def assert_ask_for_input(prompt)
      assert_gather(twiml_response, :numDigits => 1) do |gather|
        assert_play(gather, "kh/#{prompt}.mp3")
      end
      assert_redirect_to_current_url
    end

    def update_current_call_status(options = {})
      options[:from] ||= my_number
      options[:call_sid] ||= current_call
      update_call_status(options)
    end

    shared_examples_for "introducing me to chibi" do
      it "should introduce me to Chibi", :focus do
        assert_play(twiml_response, "kh/welcome.mp3")
        assert_redirect_to_current_url
      end
    end

    before do
      load_users
    end

    context "as a new user" do
      context "when I call" do
        before do
          call(:from => my_number, :call_sid => build(:phone_call).sid)
        end

        it_should_behave_like "introducing me to chibi"

        context "after I hear the welcome message" do
          before do
            update_current_call_status
          end

          it "should ask me whether I am a guy or a girl" do
            assert_ask_for_input(:ask_for_gender)
          end

          context "if I press answer that I am a 'guy'", :focus do
            before do
              update_current_call_status(:digits => 1)
            end

            it "should ask me whether I want to chat with a guy or a girl" do
              assert_ask_for_input(:ask_for_looking_for)
            end

            context "then if I press '2' for girl" do
              before do
                update_current_call_status(:digits => 2)
              end

              it "should offer me the menu" do
                assert_ask_for_input(:offer_menu)
              end

              it "should connect me with a girl" do
                pending
                #assert_dial(mara.mobile_number, )
              end
            end

            context "then if I press '1' for guy" do
              before do
                update_current_call_status(:digits => 1)
              end

              it "should connect me with a guy" do
                pending
              end
            end
          end
        end
      end
    end
  end
end
