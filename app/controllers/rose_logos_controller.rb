# frozen_string_literal: true

# Ajout Agence Rose (AGPL v3) : televerser ou retirer le logo de l'entreprise.
class RoseLogosController < ApplicationController
  def create
    authorize!(:manage, current_account)

    file = params[:logo]

    content_type = file.present? ? Marcel::MimeType.for(file.tempfile) : nil

    if content_type.nil? || RoseLogo::CONTENT_TYPES.exclude?(content_type) || file.size > RoseLogo::MAX_SIZE
      return redirect_to settings_personalization_path, alert: 'Logo refusé : PNG ou JPEG, 2 Mo maximum.'
    end

    current_account.logo.attach(io: file.tempfile, filename: file.original_filename, content_type:)

    redirect_to settings_personalization_path, notice: I18n.t('changes_have_been_saved')
  end

  def destroy
    authorize!(:manage, current_account)

    current_account.logo.purge

    redirect_to settings_personalization_path, notice: I18n.t('changes_have_been_saved')
  end
end
