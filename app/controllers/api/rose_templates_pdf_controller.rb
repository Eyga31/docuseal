# frozen_string_literal: true

# Ajout Agence Rose (AGPL v3) : creer un modele de signature a partir d'un PDF envoye par un programme.
#
# POST /api/templates/pdf  (en-tete X-Auth-Token)
# {
#   "name": "Contrat Client X",                     (facultatif, sinon nom du fichier)
#   "folder_name": "Contrats",                       (facultatif)
#   "external_id": "projet-123",                     (facultatif)
#   "documents": [{ "name": "contrat.pdf", "file": "<base64 ou data URL ou URL https>" }],
#   "fields": [                                      (facultatif)
#     { "name": "Signature client", "role": "Client", "type": "signature", "required": true,
#       "areas": [{ "x": 0.55, "y": 0.80, "w": 0.35, "h": 0.08, "page": 2, "document": 0 }] }
#   ]
# }
# x, y, w, h : fractions de la page (0 a 1, depuis le coin haut gauche). page : numero de page, a partir de 1.
# Les champs de formulaire du PDF (dont les champs signature) sont aussi repris automatiquement.
# Sans aucun champ, une signature est placee en bas a droite de la derniere page.
# Ensuite : POST /api/submissions avec template_id et "send_email": false pour obtenir le lien de signature.
module Api
  class RoseTemplatesPdfController < ApiBaseController
    DEFAULT_AREA = { 'x' => 0.55, 'y' => 0.82, 'w' => 0.35, 'h' => 0.08 }.freeze

    def create
      template = Template.new(account: current_account, author: current_user, source: 'api')

      authorize!(:create, template)

      files = Array(params.require(:documents)).map { |doc| build_file(doc) }

      template.name = params[:name].presence || File.basename(files.first.original_filename, '.*')
      template.external_id = params[:external_id].presence
      template.folder = TemplateFolders.find_or_create_by_name(current_user, params[:folder_name])

      roles = Array(params[:fields]).filter_map { |f| f[:role].presence }.uniq
      template.submitters = roles.map { |name| { 'name' => name, 'uuid' => SecureRandom.uuid } } if roles.present?

      Templates.maybe_assign_access(template)

      template.save!

      documents, = Templates::CreateAttachments.call(template, { files: }, extract_fields: true)

      template.fields = Templates::ProcessDocument.normalize_attachment_fields(template, documents)
      template.fields += build_fields(template, documents)
      template.fields = [default_signature_field(template, documents.last)] if template.fields.blank?
      template.schema = documents.map { |doc| { 'attachment_uuid' => doc.uuid, 'name' => doc.filename.base } }

      template.save!

      WebhookUrls.enqueue_events(template, 'template.created')
      SearchEntries.enqueue_reindex(template)

      render json: Templates::SerializeForApi.call(template)
    rescue Templates::CreateAttachments::PdfEncrypted
      render json: { error: 'PDF chiffre : envoyer un PDF sans mot de passe' }, status: :unprocessable_content
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def build_file(doc)
      source = doc[:file].to_s

      raise ArgumentError, 'documents[].file manquant' if source.blank?

      data =
        if source.start_with?('https://')
          DownloadUtils.call(source, validate: true).body
        else
          Base64.decode64(source.sub(/\Adata:[^,]*,/, ''))
        end

      tempfile = Tempfile.new(['rose', '.pdf'])
      tempfile.binmode
      tempfile.write(data)
      tempfile.rewind

      ActionDispatch::Http::UploadedFile.new(tempfile:, type: 'application/pdf',
                                             filename: doc[:name].presence || 'document.pdf')
    end

    def build_fields(template, documents)
      Array(params[:fields]).map do |f|
        submitter = template.submitters.find { |s| s['name'] == f[:role] } || template.submitters.first

        {
          'uuid' => SecureRandom.uuid,
          'submitter_uuid' => submitter['uuid'],
          'name' => f[:name].to_s,
          'type' => f[:type].presence || 'signature',
          'required' => f[:required] != false,
          'areas' => Array(f[:areas]).map { |a| build_area(a, documents) }
        }
      end
    end

    def build_area(area, documents)
      document = documents[area[:document].to_i] || raise(ArgumentError, 'areas[].document inconnu')

      {
        'x' => area[:x].to_f, 'y' => area[:y].to_f, 'w' => area[:w].to_f, 'h' => area[:h].to_f,
        'page' => [area[:page].to_i - 1, 0].max,
        'attachment_uuid' => document.uuid
      }
    end

    def default_signature_field(template, document)
      pages = document.metadata.dig('pdf', 'number_of_pages').to_i

      {
        'uuid' => SecureRandom.uuid,
        'submitter_uuid' => template.submitters.first['uuid'],
        'name' => 'Signature',
        'type' => 'signature',
        'required' => true,
        'areas' => [DEFAULT_AREA.merge('page' => [pages - 1, 0].max, 'attachment_uuid' => document.uuid)]
      }
    end
  end
end
