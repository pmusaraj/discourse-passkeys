# frozen_string_literal: true

class ::PasskeysController < ::ApplicationController
  requires_login only: %i[create_options register_credentials delete_first]

  def create_options
    # Generate and store the WebAuthn User ID the first time the user registers a credential
    webauthn_id = UserCustomField.find_by(user_id: current_user.id, name: "webauthn_id")&.value
    if !webauthn_id
      new_id = ::WebAuthn.generate_user_id

      # Temporarily a user custom field, this should be a column or a separate table
      UserCustomField.create!(
        user_id: current_user.id,
        name: "webauthn_id",
        value: new_id,
      )
    end

    # existing_passkeys = UserSecurityKey
    #   .where(user_id: current_user.id, factor_type: UserSecurityKey.factor_types[:first_factor])

    options = ::WebAuthn::Credential.options_for_create(
      user: { id: webauthn_id || new_id, name: current_user.username },
      # Not sure yet if we need this
      # exclude: existing_passkeys.map { |c| c.credential_id }
    )

    # Store the challenge so we can verify it later.
    session[:creation_challenge] = options.challenge

    render json: options
  end

  def register_credentials
    params.require(:publicKeyCredential)
    webauthn_credential = ::WebAuthn::Credential.from_create(params[:publicKeyCredential])

    begin
      webauthn_credential.verify(session[:creation_challenge])

      pp webauthn_credential
      # Store Credential ID, Credential Public Key
      UserSecurityKey.create(
        user: current_user,
        credential_id: webauthn_credential.id,
        public_key: webauthn_credential.public_key,
        name: "Passkey #{rand(100)}", # need to provide a form for this
        factor_type: UserSecurityKey.factor_types[:first_factor],
      )

    rescue ::WebAuthn::Error => e
      puts e
      # TODO: Add error handling
    end
  end

  def challenge
    options = ::WebAuthn::Credential.options_for_get()
    session[:authentication_challenge] = options.challenge
    render json: options
  end

  def auth
    params.require(:publicKeyCredential)
    # Assuming you're using @github/webauthn-json package to send the `PublicKeyCredential` object back
    # in params[:publicKeyCredential]:
    webauthn_credential = ::WebAuthn::Credential.from_get(params[:publicKeyCredential])

    stored_credential = UserSecurityKey.find_by(credential_id: webauthn_credential.id)
    pp webauthn_credential.id

    if !stored_credential
      render json: failed_json
      return
    end

    begin
      webauthn_credential.verify(
        session[:authentication_challenge],
        public_key: stored_credential.public_key,
        sign_count: 0 # TODO: look into adding sign count verification
      )

      # Continue with successful sign in
      pp "Success!"
      user = User.find_by(id: stored_credential.user_id)
      if user.active && user.email_confirmed?
        stored_credential.update!(last_used: DateTime.now)

        log_on_user(user)
        render_serialized(user, UserSerializer)
      else
        render json: failed_json
      end
    # rescue WebAuthn::SignCountVerificationError => e
    #   # Cryptographic verification of the authenticator data succeeded, but the signature counter was less then or equal
    #   # to the stored value. This can have several reasons and depending on your risk tolerance you can choose to fail or
    #   # pass authentication. For more information see https://www.w3.org/TR/webauthn/#sign-counter
    rescue WebAuthn::Error => e
      pp e
      # Handle error
    end
  end

  def delete_first
    # Temporary endpoint to reset current user's passkey
    UserSecurityKey
      .where(user_id: current_user.id, factor_type: UserSecurityKey.factor_types[:first_factor])
      .destroy_all
  end
end
