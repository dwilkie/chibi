require 'rails_helper'

module Chibi
  describe StringIO do
    let(:filename) { "filename.txt" }
    let(:string) { "some text" }
    subject { StringIO.new(filename, string) }

    describe "#original_filename" do
      it "should return the filename that it was initialized with" do
        subject.original_filename.should == filename
      end
    end
  end
end
