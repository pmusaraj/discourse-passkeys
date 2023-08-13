# frozen_string_literal: true

# name: discourse-passkeys
# about: Experimental Passkeys support for Discourse
# version: 0.1
# authors: Penar Musaraj
# url: https://github.com/discourse/discourse-passkeys

gem "android_key_attestation", "0.3.0"
gem "bindata", "2.4.0"
gem "awrence", "1.1.0"
gem "cbor", "0.5.9.6"
gem "safety_net_attestation", "0.4.0"
gem "tpm-key_attestation", "0.12.0", require: false
gem 'webauthn', '3.0.0'
# core already includes "cose" and "openssl"

enabled_site_setting :enable_passkeys

after_initialize do
  require File.expand_path("../app/controllers/passkeys_controller.rb", __FILE__)

  Discourse::Application.routes.append do
    get "/passkeys/create-options" => "passkeys#create_options"
    post "/passkeys/register" => "passkeys#register_credentials"
    get "/passkeys/challenge" => "passkeys#challenge"
    post "/passkeys/auth" => "passkeys#auth"
    delete "passkeys/delete-first" => "passkeys#delete_first"
  end

  ::WebAuthn.configure do |config|
    # This value needs to match `window.location.origin` evaluated by
    # the User Agent during registration and authentication ceremonies.
    if Rails.env.development?
      # You may need to tweak this in a dev environment
      config.origin = "http://localhost:4200"
    else
      config.origin = Discourse.base_url
    end

    # Relying Party name for display purposes
    config.rp_name = "Test"

    # Optionally configure a client timeout hint, in milliseconds.
    # This hint specifies how long the browser should wait for any
    # interaction with the user.
    # This hint may be overridden by the browser.
    # https://www.w3.org/TR/webauthn/#dom-publickeycredentialcreationoptions-timeout
    # config.credential_options_timeout = 120_000

    # You can optionally specify a different Relying Party ID
    # (https://www.w3.org/TR/webauthn/#relying-party-identifier)
    # if it differs from the default one.
    #
    # In this case the default would be "auth.example.com", but you can set it to
    # the suffix "example.com"
    #
    # config.rp_id = "example.com"

    # Configure preferred binary-to-text encoding scheme. This should match the encoding scheme
    # used in your client-side (user agent) code before sending the credential to the server.
    # Supported values: `:base64url` (default), `:base64` or `false` to disable all encoding.
    #
    # config.encoding = :base64url

    # Possible values: "ES256", "ES384", "ES512", "PS256", "PS384", "PS512", "RS256", "RS384", "RS512", "RS1"
    # Default: ["ES256", "PS256", "RS256"]
    #
    # config.algorithms << "ES384"

    # pp config
  end

  # Probably shouldn't use current user serializer here,
  # best to use something more specific to preferences route
  add_to_serializer(:current_user, :passkeys, false) do
    UserSecurityKey
      .where(user_id: object.id, factor_type: UserSecurityKey.factor_types[:first_factor])
      .map do |usk|
        {
          name: usk.name,
          last_used: usk.last_used,
          created_at: usk.created_at
        }
      end
  end
end
