# Dopo ogni modifica riavviare il server.
# Vedi https://guides.rubyonrails.org/security.html#content-security-policy-header

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
    policy.style_src       :self, :unsafe_inline # colori degli avatar inline
    policy.connect_src     :self                 # vale anche per il websocket di action cable sullo stesso host
  end

  # per richiesta: prima del login l'id di sessione è vuoto; Turbo ignora il nonce nel confronto degli asset
  config.content_security_policy_nonce_generator = ->(_request) { SecureRandom.base64(16) }
  config.content_security_policy_nonce_directives = %w[ script-src ]
end
