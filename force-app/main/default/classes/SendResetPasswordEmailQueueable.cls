public class SendResetPasswordEmailQueueable implements Queueable {

    private Id userId;

    public SendResetPasswordEmailQueueable(Id userId) {
        this.userId = userId;
    }

    public void execute(QueueableContext ctx) {
        try {
            User portalUser = [
                SELECT Id, Username, Email, FirstName, LastName
                FROM User
                WHERE Id = :this.userId
                LIMIT 1
            ];

            if (String.isBlank(portalUser.Email)) {
                System.debug(LoggingLevel.WARN, 'No email for user ' + this.userId);
                return;
            }

            // ✅ Génère le token sans envoyer l'email standard Salesforce
            System.ResetPasswordResult rpResult = System.resetPassword(this.userId, false);
            String token = rpResult.getPassword();

            // Stocke le token sur le User
            update new User(Id = this.userId, Reset_Token__c = token);

            System.debug(LoggingLevel.INFO, 'Token generated: ' + token);

            // Récupère l'URL du site Experience Cloud par son nom
            List<Network> networks = [
                SELECT Id, UrlPathPrefix 
                FROM Network 
                WHERE Name = 'Core'  // ← mets le nom exact de ton site
                LIMIT 1
            ];

            String baseUrl = 'https://orgfarm-cc5ae60b0b-dev-ed.develop.my.site.com/Core';

            // ✅ Construit le lien vers ta page CheckPassword avec paramètre 'c'
            // Ta page LWC lit : urlParams.get('c')
            String resetLink = baseUrl + '/CheckPasswordResetEmail?c=' 
                             + EncodingUtil.urlEncode(token, 'UTF-8');

            System.debug(LoggingLevel.INFO, 'Reset link: ' + resetLink);

            // ✅ Envoie l'email custom
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ portalUser.Email });
            mail.setSenderDisplayName('TalentBridge Recrutement');
            mail.setSubject('🎉 Votre candidature est qualifiée — Accédez à votre espace TalentBridge');
            mail.setHtmlBody(buildEmailBody(portalUser.FirstName, portalUser.Username, resetLink));
            mail.setTreatTargetObjectAsRecipient(false);

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });

            System.debug(LoggingLevel.INFO, '✅ Email envoyé à : ' + portalUser.Email);

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'SendResetPasswordEmailQueueable error: ' + e.getMessage()
                + '\n' + e.getStackTraceString());
            throw e;
        }
    }

    private String buildEmailBody(String firstName, String username, String resetLink) {
        return '<!DOCTYPE html>'
             + '<html><body style="font-family:Arial,sans-serif;background:#f4f4f4;margin:0;padding:0;">'
             + '<div style="max-width:600px;margin:40px auto;background:white;'
             +      'border-radius:8px;overflow:hidden;box-shadow:0 2px 8px rgba(0,0,0,0.1);">'

             // ── Header ──
             + '<div style="background:#0070d2;padding:30px;text-align:center;">'
             + '<h1 style="color:white;margin:0;font-size:24px;">TalentBridge</h1>'
             + '<p style="color:#cce5ff;margin:8px 0 0;">Espace Candidat</p>'
             + '</div>'

             // ── Body ──
             + '<div style="padding:40px;">'
             + '<h2 style="color:#333;margin-top:0;">Félicitations, ' + firstName + ' ! 🎉</h2>'
             + '<p style="color:#555;line-height:1.6;">'
             + 'Votre candidature a été <strong>qualifiée automatiquement</strong> '
             + 'par notre système IA. Accédez à votre espace candidat pour suivre '
             + 'votre processus de recrutement en temps réel.'
             + '</p>'

             // ── Étapes recrutement ──
             + '<div style="background:#f8f9fa;border-radius:6px;padding:20px;margin:24px 0;">'
             + '<p style="margin:0 0 12px;font-weight:bold;color:#333;">📋 Votre parcours :</p>'
             + '<div style="color:#0070d2;font-weight:bold;">✅ Application Received</div>'
             + '<div style="color:#888;margin-top:8px;">⏳ HR Interview</div>'
             + '<div style="color:#888;margin-top:8px;">⏳ Technical Interview</div>'
             + '<div style="color:#888;margin-top:8px;">⏳ Final Interview</div>'
             + '<div style="color:#888;margin-top:8px;">⏳ Offer Extended / Rejected</div>'
             + '</div>'
             // ── Credentials ──
             + '<div style="background:#e8f4fd;border-radius:6px;padding:16px;margin:24px 0;border-left:4px solid #0070d2;">'
             + '<p style="margin:0 0 8px;font-weight:bold;color:#333;">🔑 Vos identifiants de connexion :</p>'
             + '<p style="margin:4px 0 0;color:#555;">Nom d\'utilisateur : <strong>' + username + '</strong></p>'
             + '</div>'



             // ── CTA ──
             + '<div style="text-align:center;margin:32px 0;">'
             + '<a href="' + resetLink + '" '
             + 'style="background:#0070d2;color:white;padding:14px 32px;'
             + 'border-radius:6px;text-decoration:none;font-size:16px;'
             + 'font-weight:bold;display:inline-block;">'
             + 'Définir mon mot de passe →</a>'
             + '</div>'

             + '<p style="color:#888;font-size:13px;">'
             + '⚠️ Ce lien est valable <strong>24 heures</strong>. '
             + 'Passé ce délai, contactez votre recruteur.</p>'
             + '</div>'

             // ── Footer ──
             + '<div style="background:#f4f4f4;padding:20px;text-align:center;">'
             + '<p style="color:#aaa;font-size:12px;margin:0;">'
             + 'TalentBridge — Système de recrutement automatisé<br>'
             + 'Si vous n\'avez pas postulé, ignorez cet email.</p>'
             + '</div>'

             + '</div></body></html>';
    }
}