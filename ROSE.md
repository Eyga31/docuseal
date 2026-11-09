# DocuSeal — version Agence Rose

Fork de [docusealco/docuseal](https://github.com/docusealco/docuseal) (AGPL v3), branche `rose`.
Tourne sur docuseal.os.agencerose.com. La mention DocuSeal reste dans l'interface (LICENSE_ADDITIONAL_TERMS).

Version DocuSeal de base en production : 3.3.6

## Ajouts (fichiers marqués « Ajout Agence Rose »)
- Logo de l'entreprise : `lib/rose_logo.rb`, `app/controllers/rose_logos_controller.rb`, `app/views/rose_logos/`,
  `app/views/personalization_settings/_logo_form.html.erb`, `app/views/submit_form/_banner.html.erb`,
  `app/views/start_form/_banner.html.erb`, `app/views/layouts/mailer.html.erb`, `app/models/account.rb`,
  `lib/submissions/generate_audit_trail.rb`, `lib/submitters/create_stamp_attachment.rb`.
- Import PDF par l'API (`POST /api/templates/pdf`) : `app/controllers/api/rose_templates_pdf_controller.rb`.
- Routes : `config/routes.rb`.

## Mettre à jour
Rebaser `rose` sur le nouveau tag, résoudre les conflits sur les fichiers ci-dessus, reconstruire l'image,
tester sur le compartiment Test, puis changer « Version DocuSeal de base en production » ici.
