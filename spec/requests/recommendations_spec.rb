require 'spec_helper'

describe "Recommendations" do
  include MessagingHelpers
  include TranslationHelpers

  let(:girls_looking_for_boys) do
    create_list(:girl_looking_for_guy, 6)
  end

  let(:sok) { create(:guy_looking_for_girl) }
  let(:last_message) { Message.last }
  let(:reply) { last_message.reply }

  SEARCH_KEYWORDS = {
    :meet => "nhom chong meet srey",
    :rok => "nhom chong rok srey",
    :find => "nhom chong find srey"
  }

  context "Sok is looking for a girl" do
    context "and there are many girls looking for guys" do
      context "when he searches", :search => true do
        before(:all) do
          sok
          girls_looking_for_boys
          Sunspot.commit
          search(sok)
        end

        it "should recommend him some girls to chat with" do
          usernames = girls_looking_for_boys.slice(0..4).map { |girl| girl.username }
          reply.body.should == spec_translate(
            :suggestions,
            :looking_for => sok.looking_for,
            :usernames => usernames
          )
        end

        it "should give him 5 recommendations" do
          reply.body.should include(5.to_s)
        end

        it "should not recommend that he chats with himself" do
          reply.body.should_not include(sok.username)
        end
      end
    end

    shared_examples_for "recommend sok some girls to chat with" do
      before do
        send_message(:from => sok.mobile_number,:body => message_text)
      end

      context "the last message" do
        it "should have a reply" do
          last_message.reply.should be_present
        end

        context "reply" do
          it "should be sent to Sok" do
            reply.subscription.user.should == sok
          end

          it "should contain some recommendations" do
            reply.body.should == spec_translate(
              :suggestions,
              :looking_for => sok.looking_for,
              :usernames => []
            )
          end
        end
      end
    end

    context "and he sends the keyword" do
      SEARCH_KEYWORDS.each do |keyword, example|
        context "'#{keyword}'" do
          it_should_behave_like "recommend sok some girls to chat with" do
            let(:message_text) { example }
          end
        end
      end
    end
  end
end

