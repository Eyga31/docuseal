# frozen_string_literal: true

# Ajout Agence Rose (AGPL v3) : logo de l'entreprise affiche aux signataires
# (page de signature, mails, piste d'audit, tampon de signature).
# La mention « DocuSeal » reste en place dans l'interface (LICENSE_ADDITIONAL_TERMS).
module RoseLogo
  CONTENT_TYPES = %w[image/png image/jpeg].freeze
  MAX_SIZE = 2.megabytes

  module_function

  def attached?(account)
    account.present? && account.logo.attached?
  end

  def url(account)
    ActiveStorage::Blob.proxy_url(account.logo.blob)
  end

  def io(account)
    StringIO.new(account.logo.download)
  end

  def banner_account(assigns)
    assigns[:submitter]&.account || assigns[:submission]&.account || assigns[:template]&.account
  end
end
