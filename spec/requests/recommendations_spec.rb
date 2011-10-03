require 'spec_helper'

describe "Recommendations" do
  include MessagingHelpers
  include TranslationHelpers

  let(:girl_looking_for_boy) do
    create(:girl_looking_for_guy)
  end

  let(:sok) do
    create(:guy_looking_for_girl)
  end

  let(:girlfriend_of_sok) do
    create(:friendship, :user => sok).friend
  end

  let(:girl_that_befriended_sok) do
    create(:friendship, :friend => sok).user
  end

  let(:girl_that_was_already_suggested_for_sok) do
    create(:friendship_suggestion, :user => sok).suggested_friend
  end

  let(:girl_that_sok_was_suggested_to) do
    create(:friendship_suggestion, :suggested_friend => sok).user
  end

  let(:users) do
    [
      sok, girl_looking_for_boy,
      girlfriend_of_sok, girl_that_befriended_sok,
      girl_that_was_already_suggested_for_sok, girl_that_sok_was_suggested_to
    ]
  end

  let(:last_message) do
    Message.last
  end

  let(:reply) do
    last_message.reply
  end

  SEARCH_KEYWORDS = {
    :meet => "nhom chong meet srey",
    :rok => "nhom chong rok srey",
    :find => "nhom chong find srey"
  }

  context "Sok is looking for a girl" do
    context "and there are many girls looking for guys", :search => true do
      def reload_index_and_commit(reload_instances)
        reload_instances.each do |instance|
          instance.reload.index
        end

        Sunspot.commit
      end

      before(:all) do
        reload_index_and_commit(users)
      end

      context "when he searches" do
        before(:all) do
          search(sok)
        end

        it "should give him 2 recommendations" do
          reply.body.should include(2.to_s)
        end

        it "should recommend that he chats with a girl that he was suggested to and the girl looking for a guy" do
          usernames = [girl_looking_for_boy, girl_that_sok_was_suggested_to].map { |girl| girl.username }
          reply.body.should == spec_translate(
            :suggestions,
            :looking_for => sok.looking_for,
            :usernames => usernames
          )
        end

        it "should not recommend that he chats with himself" do
          reply.body.should_not include(sok.username)
        end

        it "should not recommend that he chats with his girlfriend" do
          reply.body.should_not include(girlfriend_of_sok.username)
        end

        it "should not recommend that he chats with the girl that befriended him" do
          reply.body.should_not include(girl_that_befriended_sok.username)
        end

        it "should not recommend that he chats with the girl that was already suggested to him" do
          reply.body.should_not include(girl_that_was_already_suggested_for_sok.username)
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

