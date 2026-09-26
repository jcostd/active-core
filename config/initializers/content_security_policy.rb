# Be sure to restart your server when you modify this file.
# See https://guides.rubyonrails.org/security.html#content-security-policy-header

Rails.application.configure do
  config.content_security_policy do |policy|
    policy.default_src     :self
    policy.base_uri        :self
    policy.form_action     :self
    policy.frame_ancestors :none
    policy.object_src      :none
    policy.font_src        :self, :data
    policy.img_src         :self, :data
    policy.script_src      :self
    policy.style_src       :self, :unsafe_inline # avatar colors are inline
    policy.connect_src     :self, :ws, :wss      # action cable
  end

  # per request: session id is blank before login, Turbo ignores nonce when diffing assets
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[ script-src ]
end
