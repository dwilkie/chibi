require 'spec_helper'

describe "PhoneCalls", :focus do

  describe "POST /phone_calls.xml" do
    include PhoneCallHelpers

    include_context "existing users"

    let(:new_phone_call) { build(:phone_call) }

    let(:my_number) { "8553243313" }

    let(:xml_response) do
      full_response = Nokogiri::XML(response.body) do |config|
        config.options = Nokogiri::XML::ParseOptions::DEFAULT_XML | Nokogiri::XML::ParseOptions::NOBLANKS
      end

      full_response.xpath("/Response")
    end

    def current_call(options = {})
      @call_sid ||= make_call(options)
    end

    alias :call :current_call

    shared_examples_for "introducing me to chibi" do
      it "should introduce me to Chibi" do
        xml_response.xpath("//Play").first.content.strip.should == "https://s3.amazonaws.com/chibimp3/cowbell.mp3"
      end
    end

    context "as a new user" do

      context "when I call" do
        before do
          call(:call_sid => new_phone_call.sid)
        end

        it_should_behave_like "introducing me to chibi"

        it "should ask me whether I am a guy or a girl" do
          #assert_twiml(1, :play => )
        end

        context "given I press '1' for guy" do
          before do
            update_call_status(:from => my_number, :call_sid => current_call, :digits => "1")
          end

          it "should ask me whether I want to chat with a guy or a girl" do
            pending
          end

          context "given I press '2' for girl" do
            before do
              update_call_status(:from => my_number, :call_sid => current_call, :digits => "2")
            end

            it "should connect me to a girl" do
              pending
            end
          end
        end
      end
    end
  end
end
