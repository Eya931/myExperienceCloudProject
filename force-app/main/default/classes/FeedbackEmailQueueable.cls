public class FeedbackEmailQueueable implements Queueable {
    
    private Id leadId;
    private String leadEmail;
    private String leadFirstName;
    private String jobTitle;
    private String report;
    private Integer score;
    private Boolean aiSucceeded;

    public FeedbackEmailQueueable(
        Id leadId,
        String leadEmail,
        String leadFirstName,
        String jobTitle,
        String report,
        Integer score,
        Boolean aiSucceeded
    ) {
        this.leadId        = leadId;
        this.leadEmail     = leadEmail;
        this.leadFirstName = leadFirstName;
        this.jobTitle      = jobTitle;
        this.report        = report;
        this.score         = score;
        this.aiSucceeded   = aiSucceeded;
    }

    public void execute(QueueableContext ctx) {
        try {
            if (String.isBlank(this.leadEmail)) {
                System.debug(LoggingLevel.WARN, 'No email on Lead ' + leadId + ' — skipping feedback email.');
                return;
            }

            String matchedSkills = '';
            String missingSkills = '';
            String summary       = '';

            if (String.isNotBlank(this.report)) {
                if (this.report.contains('Matched Skills:')) {
                    matchedSkills = this.report.substringAfter('Matched Skills:')
                                              .substringBefore('\n').trim();
                }
                if (this.report.contains('Missing Skills:')) {
                    missingSkills = this.report.substringAfter('Missing Skills:')
                                              .substringBefore('\n').trim();
                }
                // Extract last summary paragraph if present
                if (this.report.contains('\n\n')) {
                    summary = this.report.substringAfterLast('\n\n').trim();
                }
            }

            String firstName    = String.isNotBlank(this.leadFirstName) ? this.leadFirstName : 'Candidat(e)';
            String scoreDisplay = (this.score != null) ? String.valueOf(this.score) + '%' : 'N/A';
            String scoreColor   = '#e05a2b';
            if (this.score != null) {
                scoreColor = this.score >= 60 ? '#22c55e' : this.score >= 35 ? '#f59e0b' : '#e05a2b';
            }

            // ── Matched skills HTML rows ──
            String matchedHtml = '';
            if (String.isNotBlank(matchedSkills)) {
                for (String sk : matchedSkills.split(',')) {
                    String s = sk.trim();
                    if (String.isNotBlank(s)) {
                        matchedHtml += '<span style="display:inline-block;background:#dcfce7;color:#15803d;'
                            + 'border-radius:20px;padding:4px 12px;font-size:12px;font-weight:600;'
                            + 'margin:3px 3px 3px 0;font-family:\'DM Sans\',Arial,sans-serif;">'
                            + s + '</span>';
                    }
                }
            }

            // ── Missing skills HTML rows ──
            String missingHtml = '';
            if (String.isNotBlank(missingSkills)) {
                for (String sk : missingSkills.split(',')) {
                    String s = sk.trim();
                    if (String.isNotBlank(s)) {
                        missingHtml += '<span style="display:inline-block;background:#fee2e2;color:#b91c1c;'
                            + 'border-radius:20px;padding:4px 12px;font-size:12px;font-weight:600;'
                            + 'margin:3px 3px 3px 0;font-family:\'DM Sans\',Arial,sans-serif;">'
                            + s + '</span>';
                    }
                }
            }

            // ── Score block ──
            String scoreBlock = '';
            if (this.aiSucceeded && this.score != null) {
                scoreBlock = '<table width="100%" cellpadding="0" cellspacing="0" border="0" style="margin:24px 0;">'
                    + '<tr><td align="center">'
                    + '<div style="display:inline-block;background:#fff8f6;border:2px solid ' + scoreColor + ';'
                    + 'border-radius:16px;padding:20px 40px;text-align:center;">'
                    + '<p style="margin:0 0 4px;font-size:12px;color:#9ca3af;letter-spacing:1px;'
                    + 'text-transform:uppercase;font-family:\'DM Sans\',Arial,sans-serif;">Score de correspondance</p>'
                    + '<p style="margin:0;font-size:44px;font-weight:700;color:' + scoreColor + ';'
                    + 'font-family:Georgia,serif;line-height:1;">' + scoreDisplay + '</p>'
                    + '</div>'
                    + '</td></tr></table>';
            }

            // ── Matched skills section ──
            String matchedSection = '';
            if (String.isNotBlank(matchedHtml)) {
                matchedSection = '<div style="margin-bottom:20px;">'
                    + '<p style="margin:0 0 10px;font-size:13px;font-weight:700;color:#374151;'
                    + 'text-transform:uppercase;letter-spacing:0.8px;font-family:\'DM Sans\',Arial,sans-serif;">'
                    + '✅ &nbsp;Compétences présentes</p>'
                    + '<div>' + matchedHtml + '</div>'
                    + '</div>';
            }

            // ── Missing skills section ──
            String missingSection = '';
            if (String.isNotBlank(missingHtml)) {
                missingSection = '<div style="margin-bottom:20px;">'
                    + '<p style="margin:0 0 10px;font-size:13px;font-weight:700;color:#374151;'
                    + 'text-transform:uppercase;letter-spacing:0.8px;font-family:\'DM Sans\',Arial,sans-serif;">'
                    + '❌ &nbsp;Compétences à développer</p>'
                    + '<div>' + missingHtml + '</div>'
                    + '</div>';
            }

            // ── AI unavailable block ──
            String aiUnavailableBlock = '';
            if (!this.aiSucceeded) {
                aiUnavailableBlock = '<div style="background:#fef9ec;border-left:4px solid #f59e0b;'
                    + 'border-radius:8px;padding:16px 20px;margin:20px 0;">'
                    + '<p style="margin:0;font-size:13.5px;color:#92400e;font-family:\'DM Sans\',Arial,sans-serif;">'
                    + 'Notre système d\'analyse automatique n\'a pas pu évaluer votre CV. '
                    + 'Votre candidature sera examinée manuellement par notre équipe de recrutement.'
                    + '</p></div>';
            }

            // ── Summary block ──
            String summaryBlock = '';
            if (String.isNotBlank(summary)) {
                summaryBlock = '<div style="background:#f8fafc;border-radius:10px;padding:16px 20px;margin:16px 0 0;">'
                    + '<p style="margin:0;font-size:13.5px;color:#475569;line-height:1.7;'
                    + 'font-family:\'DM Sans\',Arial,sans-serif;font-style:italic;">'
                    + summary + '</p></div>';
            }

            // ════════════════════════════════════════
            // FULL HTML EMAIL
            // ════════════════════════════════════════
            String htmlBody =
                '<!DOCTYPE html>'
              + '<html lang="fr"><head><meta charset="UTF-8">'
              + '<meta name="viewport" content="width=device-width,initial-scale=1">'
              + '<title>Retour sur votre candidature</title></head>'
              + '<body style="margin:0;padding:0;background:#f1f5f9;font-family:\'DM Sans\',Arial,sans-serif;">'

              // ── Outer wrapper ──
              + '<table width="100%" cellpadding="0" cellspacing="0" border="0" bgcolor="#f1f5f9">'
              + '<tr><td align="center" style="padding:40px 16px;">'

              // ── Card ──
              + '<table width="600" cellpadding="0" cellspacing="0" border="0" '
              + 'style="max-width:600px;background:#ffffff;border-radius:20px;'
              + 'overflow:hidden;box-shadow:0 4px 40px rgba(0,0,0,0.08);">'

              // ── Header band ──
              + '<tr><td style="background:linear-gradient(135deg,#0d0d14 0%,#1e1b2e 100%);padding:36px 40px 32px;">'
              + '<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
              + '<td>'
              + '<table cellpadding="0" cellspacing="0" border="0"><tr>'
              + '<td style="background:#ff5c35;border-radius:10px;width:36px;height:36px;'
              + 'text-align:center;vertical-align:middle;">'
              + '<span style="color:#fff;font-size:18px;font-weight:700;line-height:36px;">&#9671;</span>'
              + '</td>'
              + '<td style="padding-left:10px;color:#ffffff;font-size:18px;font-weight:600;'
              + 'letter-spacing:-0.3px;font-family:\'DM Sans\',Arial,sans-serif;">TalentBridge</td>'
              + '</tr></table>'
              + '</td>'
              + '<td align="right">'
              + '<span style="background:rgba(255,255,255,0.1);border:1px solid rgba(255,255,255,0.2);'
              + 'color:rgba(255,255,255,0.75);font-size:11px;padding:5px 14px;border-radius:20px;'
              + 'font-family:\'DM Sans\',Arial,sans-serif;letter-spacing:0.5px;">Retour candidature</span>'
              + '</td></tr></table>'
              + '</td></tr>'

              // ── Rejection banner ──
              + '<tr><td style="background:#fff5f2;border-bottom:1px solid #ffe4db;padding:24px 40px;">'
              + '<table width="100%" cellpadding="0" cellspacing="0" border="0"><tr>'
              + '<td style="width:44px;vertical-align:top;padding-top:2px;">'
              + '<div style="width:40px;height:40px;background:#fff0ec;border:2px solid #ffcfc4;'
              + 'border-radius:50%;text-align:center;line-height:38px;font-size:18px;">😔</div>'
              + '</td>'
              + '<td style="padding-left:14px;">'
              + '<p style="margin:0 0 4px;font-size:16px;font-weight:700;color:#c0392b;'
              + 'font-family:Georgia,serif;">Candidature non retenue</p>'
              + '<p style="margin:0;font-size:13.5px;color:#7f3223;line-height:1.6;'
              + 'font-family:\'DM Sans\',Arial,sans-serif;">'
              + 'Nous sommes navrés de vous informer que votre candidature pour le poste de '
              + '<strong>' + this.jobTitle + '</strong> n\'a pas pu être retenue à ce stade.'
              + '</p>'
              + '</td></tr></table>'
              + '</td></tr>'

              // ── Body ──
              + '<tr><td style="padding:32px 40px;">'

              // Greeting
              + '<p style="margin:0 0 16px;font-size:15px;color:#1e293b;font-weight:600;'
              + 'font-family:\'DM Sans\',Arial,sans-serif;">Bonjour ' + firstName + ',</p>'
              + '<p style="margin:0 0 24px;font-size:14px;color:#475569;line-height:1.75;'
              + 'font-family:\'DM Sans\',Arial,sans-serif;">'
              + 'Merci de l\'intérêt que vous portez à TalentBridge et d\'avoir pris le temps de '
              + 'postuler pour le poste de <strong style="color:#0d0d14;">' + this.jobTitle + '</strong>. '
              + 'Après examen de votre dossier, nous regrettons de ne pas pouvoir donner suite '
              + 'à votre candidature. Voici un retour détaillé pour vous aider à progresser.'
              + '</p>'

              // Divider
              + '<div style="height:1px;background:linear-gradient(to right,#e2e8f0,transparent);margin:0 0 24px;"></div>'

              // Score + skills
              + scoreBlock
              + aiUnavailableBlock
              + matchedSection
              + missingSection
              + summaryBlock

              // Divider
              + '<div style="height:1px;background:linear-gradient(to right,#e2e8f0,transparent);margin:28px 0;"></div>'

              // Tips
              + '<p style="margin:0 0 14px;font-size:13px;font-weight:700;color:#374151;'
              + 'text-transform:uppercase;letter-spacing:0.8px;font-family:\'DM Sans\',Arial,sans-serif;">'
              + '💡 &nbsp;Nos conseils pour la suite</p>'

              + '<table width="100%" cellpadding="0" cellspacing="0" border="0">'
              + tipRow('1', 'Renforcez vos compétences manquantes via Udemy, Coursera ou LinkedIn Learning.')
              + tipRow('2', 'Quantifiez vos réalisations avec des résultats mesurables dans votre CV.')
              + tipRow('3', 'Utilisez les mots-clés exacts de l\'offre pour optimiser le passage des filtres ATS.')
              + tipRow('4', 'N\'hésitez pas à repostuler après avoir renforcé votre profil — nous gardons votre dossier.')
              + '</table>'

              // Closing
              + '<div style="height:1px;background:linear-gradient(to right,#e2e8f0,transparent);margin:28px 0;"></div>'
              + '<p style="margin:0;font-size:14px;color:#475569;line-height:1.75;'
              + 'font-family:\'DM Sans\',Arial,sans-serif;">'
              + 'Nous vous souhaitons le meilleur dans votre recherche d\'emploi et espérons avoir '
              + 'l\'occasion de collaborer avec vous à l\'avenir.'
              + '</p>'
              + '<p style="margin:20px 0 0;font-size:14px;color:#0d0d14;font-weight:600;'
              + 'font-family:\'DM Sans\',Arial,sans-serif;">Cordialement,<br/>'
              + '<span style="color:#ff5c35;">L\'équipe TalentBridge</span></p>'
              + '</td></tr>'

              // ── Footer ──
              + '<tr><td style="background:#f8fafc;border-top:1px solid #e2e8f0;'
              + 'padding:20px 40px;text-align:center;">'
              + '<p style="margin:0;font-size:11.5px;color:#94a3b8;'
              + 'font-family:\'DM Sans\',Arial,sans-serif;">'
              + 'Cet email a été envoyé automatiquement suite à votre candidature sur TalentBridge. '
              + 'Merci de ne pas y répondre directement.'
              + '</p>'
              + '</td></tr>'

              + '</table>' // end card
              + '</td></tr></table>' // end outer
              + '</body></html>';

            String subject = 'Votre candidature — ' + this.jobTitle + ' | Retour personnalisé';

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new List<String>{ this.leadEmail });
            email.setSubject(subject);
            email.setHtmlBody(htmlBody);
            email.setPlainTextBody(buildPlainText(firstName, scoreDisplay, matchedSkills, missingSkills));
            email.setSaveAsActivity(false);
            email.setUseSignature(false);

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ email });

            System.debug(LoggingLevel.INFO,
                'Feedback email sent to: ' + this.leadEmail + ' | Score: ' + scoreDisplay);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'FeedbackEmailQueueable error for Lead ' + this.leadId + ': ' + e.getMessage());
        }
    }

    // ── Helper: tip row ──
    private String tipRow(String num, String text) {
        return '<tr><td style="padding:8px 0;vertical-align:top;width:28px;">'
            + '<div style="width:22px;height:22px;background:#fff0ec;border:1.5px solid #ffcfc4;'
            + 'border-radius:50%;text-align:center;line-height:20px;font-size:11px;font-weight:700;'
            + 'color:#ff5c35;font-family:\'DM Sans\',Arial,sans-serif;">' + num + '</div>'
            + '</td>'
            + '<td style="padding:8px 0 8px 10px;font-size:13.5px;color:#475569;line-height:1.65;'
            + 'font-family:\'DM Sans\',Arial,sans-serif;">' + text + '</td></tr>';
    }

    // ── Plain-text fallback ──
    private String buildPlainText(String firstName, String scoreDisplay,
                                   String matchedSkills, String missingSkills) {
        String txt = 'Bonjour ' + firstName + ',\n\n'
            + '--- CANDIDATURE NON RETENUE ---\n\n'
            + 'Nous sommes navrés de vous informer que votre candidature pour le poste de '
            + this.jobTitle + ' n\'a pas pu être retenue.\n\n';
        if (this.aiSucceeded && this.score != null) {
            txt += 'Score de correspondance : ' + scoreDisplay + '\n';
            if (String.isNotBlank(matchedSkills)) txt += 'Compétences présentes : ' + matchedSkills + '\n';
            if (String.isNotBlank(missingSkills)) txt += 'Compétences manquantes : ' + missingSkills + '\n';
        }
        txt += '\nNos conseils :\n'
            + '1. Renforcez vos compétences manquantes via Udemy, Coursera ou LinkedIn Learning.\n'
            + '2. Quantifiez vos réalisations avec des résultats mesurables.\n'
            + '3. Utilisez les mots-clés exacts de l\'offre pour les filtres ATS.\n'
            + '4. N\'hésitez pas à repostuler après avoir renforcé votre profil.\n\n'
            + 'Cordialement,\nL\'équipe TalentBridge';
        return txt;
    }
}