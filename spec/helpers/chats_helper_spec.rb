require 'rails_helper'

describe ChatsHelper do
  let(:chat) { create(:chat) }

  describe "#chat_user_link" do
    let(:active_chat_with_single_user) { create(:chat, :initiator_active) }

    def assert_chat_user_link(reference_chat, user_type, options = {})
      result = helper.chat_user_link(reference_chat, user_type)
      if options[:link] == false
        expect(result).to eq("-")
      else
        reference_user = reference_chat.send(user_type)
        expect(result).to have_link(
          reference_user.screen_id,
          :href => "/users/#{reference_user.id}"
        )
      end
    end

    it "should return a link for the chat user" do
      assert_chat_user_link(chat, :inactive_user, :link => false)

      USER_TYPES_IN_CHAT.each do |user_type|
        assert_chat_user_link(active_chat_with_single_user, user_type)
      end
    end
  end
end
