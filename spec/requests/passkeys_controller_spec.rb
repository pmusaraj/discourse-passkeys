# frozen_string_literal: true

require "rails_helper"

RSpec.describe PasskeysController do

  describe "#challenge" do
    it "generates a challenge" do
      get "/passkeys/challenge.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["challenge"]).not_to be_empty
      expect(response.parsed_body["timeout"]).not_to be_empty
    end
  end
end
