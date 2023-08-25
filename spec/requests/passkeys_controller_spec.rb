# frozen_string_literal: true

require "rails_helper"
require 'webauthn/fake_client'

RSpec.describe PasskeysController do

  describe "webauthn creation/registration" do
    it "works" do
      user1 = Fabricate(:user)
      sign_in(user1)

      get "/passkeys/create-options.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["challenge"]).not_to be_empty
      expect(response.parsed_body["rp"]["name"]).to eq(SiteSetting.title)

      challenge = response.parsed_body["challenge"]

      webauthn_client = WebAuthn::FakeClient.new(Discourse.base_url)
      creds = webauthn_client.create(challenge: challenge)

      post "/passkeys/register.json", params: { publicKeyCredential: creds }

      expect(response.status).to eq(200)

      stored_key = UserSecurityKey
        .where(user_id: user1.id, factor_type: UserSecurityKey.factor_types[:first_factor])

      expect(stored_key.count).to eq(1)
      expect(stored_key.first.name).to eq(response.parsed_body["name"])

      sign_out

      # test auth with key we just registered
      get "/passkeys/challenge.json"

      expect(response.status).to eq(200)
      expect(response.parsed_body["challenge"]).not_to be_empty
      expect(response.parsed_body["timeout"]).to eq(120_000)

      auth_challenge = response.parsed_body["challenge"]
      auth_creds = webauthn_client.get(challenge: auth_challenge)

      # pretend user has confirmed email
      token = Fabricate(:email_token, user: user1)
      EmailToken.confirm(token.token)

      post "/passkeys/auth.json", params: { publicKeyCredential: auth_creds }

      expect(response.status).to eq(200)
      # TODO: test that session is set
    end

    it "fails when using a mismatching challenge" do
      sign_in(Fabricate(:user))

      get "/passkeys/create-options.json"
      expect(response.parsed_body["challenge"]).not_to be_empty

      # different challenge
      challenge = Base64.strict_encode64(SecureRandom.random_bytes(16))
      webauthn_client = WebAuthn::FakeClient.new(Discourse.base_url)
      creds = webauthn_client.create(challenge: challenge)
      post "/passkeys/register.json", params: { publicKeyCredential: creds }

      expect(response.status).to eq(403)
    end
  end

end
