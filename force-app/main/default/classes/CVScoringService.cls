public without sharing class CVScoringService {

    private static final Decimal QUALIFICATION_THRESHOLD = 19;
    private static final String SITE_URL = 'https://orgfarm-3ed211f8bb-dev-ed.develop.my.site.com/home2/s/login';
    private static final String GROQ_ENDPOINT = 'https://api.groq.com/openai/v1/chat/completions';
    private static final String GROQ_MODEL = 'llama-3.3-70b-versatile';
    private static final Integer MAX_TEXT_LENGTH = 3000;

    private static final String STATUS_PARSING = 'Condidature - IA Parsing';
    private static final String STATUS_VALIDATED = 'Condidature - Validee-Email Envoye';
    private static final String STATUS_REJECTED = 'Condidature Refuse';

    public class CVScoringException extends Exception {}

    public static void scoreCVForLeads(Set<Id> leadIds) {
        if (leadIds == null || leadIds.isEmpty()) {
            return;
        }

        List<Lead> leadsToUpdate = [
            SELECT Id, Status, IsConverted
            FROM Lead
            WHERE Id IN :leadIds AND IsConverted = false
        ];

        for (Lead l : leadsToUpdate) {
            String parsingStatus = resolveLeadStatusValue(STATUS_PARSING, l.Status);
            if (String.isNotBlank(parsingStatus)) {
                l.Status = parsingStatus;
            }
        }

        if (!leadsToUpdate.isEmpty()) {
            update leadsToUpdate;
        }

        System.enqueueJob(new CVScoringQueue(new List<Id>(leadIds)));
    }

    public static void scoreCVForLeadNow(Id leadId) {
        if (leadId == null) {
            return;
        }

        Lead l = [SELECT Id, Status, IsConverted FROM Lead WHERE Id = :leadId LIMIT 1];
        if (!l.IsConverted) {
            String parsingStatus = resolveLeadStatusValue(STATUS_PARSING, l.Status);
            if (String.isNotBlank(parsingStatus)) {
                l.Status = parsingStatus;
                update l;
            }
        }

        runProcessing(leadId);
    }

    private class CVScoringQueue implements Queueable, Database.AllowsCallouts {
        private List<Id> ids;

        public CVScoringQueue(List<Id> ids) {
            this.ids = ids;
        }

        public void execute(QueueableContext ctx) {
            for (Id leadId : ids) {
                runProcessing(leadId);
            }
        }
    }

    private static String getGroqApiKey() {
        // 1) Preferred: query API_Configuration__c.api_groq__c directly
        try {
            Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
            if (globalDescribe.containsKey('API_Configuration__c')) {
                List<SObject> apiConfigs = Database.query('SELECT api_groq__c FROM API_Configuration__c LIMIT 1');
                if (!apiConfigs.isEmpty()) {
                    String apiKey = (String) apiConfigs[0].get('api_groq__c');
                    if (String.isNotBlank(apiKey)) {
                        return apiKey;
                    }
                }
            }
        } catch (Exception e) {
            // Object may not exist in all orgs; continue fallback lookup.
        }

        // 2) Fallback: API_Configuration__c.api_groq__c
        API_Configuration__c config = API_Configuration__c.getInstance();
        if (config != null && String.isNotBlank(config.api_groq__c)) {
            return config.api_groq__c;
        }

        throw new CVScoringException('Groq API key is not configured in API_Configuration__c.api_groq__c.');
    }

    private static String extractCVText(Id leadId) {
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId
            ORDER BY SystemModstamp DESC
            LIMIT 1
        ];
        if (cdls.isEmpty()) {
            return null;
        }

        List<ContentVersion> cvs = [
            SELECT VersionData, Title, FileExtension
            FROM ContentVersion
            WHERE ContentDocumentId = :cdls[0].ContentDocumentId
              AND IsLatest = true
            LIMIT 1
        ];
        if (cvs.isEmpty()) {
            return null;
        }

        try {
            String text = cvs[0].VersionData.toString();
            if (text != null && text.length() > MAX_TEXT_LENGTH) {
                text = text.substring(0, MAX_TEXT_LENGTH);
            }
            return text;
        } catch (Exception e) {
            System.debug('Unable to extract CV text: ' + e.getMessage());
            return null;
        }
    }

    private static String extractProfileText(String leadDescription) {
        if (String.isBlank(leadDescription)) {
            return null;
        }

        Integer idx = leadDescription.indexOf('PROFILE_TEXT:');
        if (idx < 0) {
            return null;
        }

        String text = leadDescription.substring(idx + 'PROFILE_TEXT:'.length()).trim();
        if (text.length() > MAX_TEXT_LENGTH) {
            text = text.substring(0, MAX_TEXT_LENGTH);
        }
        return text;
    }

    private static String getJobDescription(String leadDescription) {
        if (String.isBlank(leadDescription)) {
            return null;
        }

        String jobId = null;
        for (String line : leadDescription.split('\n')) {
            String trimmed = line != null ? line.trim() : '';
            if (trimmed.startsWith('JOB_ID:')) {
                jobId = trimmed.replace('JOB_ID:', '').trim();
                break;
            }
            if (trimmed.startsWith('Job ID:')) {
                jobId = trimmed.replace('Job ID:', '').trim();
                break;
            }
        }

        if (String.isBlank(jobId)) {
            return null;
        }

        try {
            List<Job__c> jobs = [
                SELECT Job_Title__c, Department__c, Required_Skills__c, Job_Description__c
                FROM Job__c
                WHERE Id = :jobId
                LIMIT 1
            ];
            if (jobs.isEmpty()) {
                return null;
            }

            Job__c job = jobs[0];
            List<String> parts = new List<String>();
            parts.add('Poste: ' + job.Job_Title__c);
            if (String.isNotBlank(job.Department__c)) {
                parts.add('Department: ' + job.Department__c);
            }
            if (String.isNotBlank(job.Required_Skills__c)) {
                parts.add('Required Skills: ' + job.Required_Skills__c);
            }
            if (String.isNotBlank(job.Job_Description__c)) {
                parts.add('Description: ' + job.Job_Description__c);
            }
            return String.join(parts, '\n');
        } catch (Exception e) {
            System.debug('Error while loading job: ' + e.getMessage());
            return null;
        }
    }

    private static Map<String, Object> callGroqAPI(String cvText, String profileText, String jobDescription) {
        String apiKey = getGroqApiKey();

        String candidateInfo = '';
        if (String.isNotBlank(cvText)) {
            candidateInfo += 'CV content:\n' + cvText + '\n\n';
        }
        if (String.isNotBlank(profileText)) {
            candidateInfo += 'Candidate profile:\n' + profileText + '\n\n';
        }
        if (String.isBlank(candidateInfo)) {
            candidateInfo = 'No detailed candidate information available.';
        }

        String jobInfo = String.isNotBlank(jobDescription)
            ? jobDescription
            : 'No job description available.';

        String systemPrompt = 'You are an HR expert specialized in CV analysis and candidate-job matching. '
            + 'You must respond only with valid JSON and no extra text. '
            + 'Use this exact structure: '
            + '{"score":<integer 0..100>,"recommendation":"<2-3 sentences>","points_forts":"<bullet list>","points_faibles":"<bullet list>"}';

        String userPrompt = 'Analyze this candidate profile against the job posting and assign a matching score between 0 and 100.\n\n'
            + '=== JOB DESCRIPTION ===\n' + jobInfo + '\n\n'
            + '=== CANDIDATE PROFILE ===\n' + candidateInfo + '\n\n'
            + 'Scoring weights:\n'
            + '- Relevant technical skills (40%)\n'
            + '- Relevant professional experience (25%)\n'
            + '- Education and certifications (20%)\n'
            + '- Soft skills and cultural fit (15%)\n\n'
            + 'Be realistic and objective. Respond only with valid JSON.';

        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('model', GROQ_MODEL);
        requestBody.put('temperature', 0.3);
        requestBody.put('max_tokens', 600);
        requestBody.put('messages', new List<Map<String, String>>{
            new Map<String, String>{ 'role' => 'system', 'content' => systemPrompt },
            new Map<String, String>{ 'role' => 'user', 'content' => userPrompt }
        });

        HttpRequest req = new HttpRequest();
        req.setEndpoint(GROQ_ENDPOINT);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('Authorization', 'Bearer ' + apiKey);
        req.setTimeout(30000);
        req.setBody(JSON.serialize(requestBody));

        HttpResponse res = new Http().send(req);
        if (res.getStatusCode() != 200) {
            throw new CVScoringException('Groq API error (' + res.getStatusCode() + '): ' + res.getBody());
        }

        Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        List<Object> choices = (List<Object>) responseMap.get('choices');
        if (choices == null || choices.isEmpty()) {
            throw new CVScoringException('Groq API returned no choices.');
        }

        Map<String, Object> firstChoice = (Map<String, Object>) choices[0];
        Map<String, Object> message = (Map<String, Object>) firstChoice.get('message');
        String content = (String) message.get('content');
        content = stripCodeFence(content);

        return (Map<String, Object>) JSON.deserializeUntyped(content);
    }

    private static String stripCodeFence(String content) {
        if (String.isBlank(content)) {
            return content;
        }

        String cleaned = content.trim();
        if (cleaned.startsWith('```json')) {
            cleaned = cleaned.substring(7);
        } else if (cleaned.startsWith('```')) {
            cleaned = cleaned.substring(3);
        }
        if (cleaned.endsWith('```')) {
            cleaned = cleaned.substring(0, cleaned.length() - 3);
        }
        return cleaned.trim();
    }

    private static void runProcessing(Id leadId) {
        try {
            Lead lead = [
                SELECT Id, FirstName, LastName, Email, Description, IsConverted, Status
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            if (lead.IsConverted) {
                return;
            }

            String cvText = extractCVText(leadId);
            String profileText = extractProfileText(lead.Description);
            String jobDescription = getJobDescription(lead.Description);

            Decimal score = 0;
            String recommendation = '';
            String pointsForts = '';
            String pointsFaibles = '';

            try {
                Map<String, Object> aiResult = callGroqAPI(cvText, profileText, jobDescription);
                Object scoreObj = aiResult.get('score');
                score = Decimal.valueOf(String.valueOf(scoreObj));
                score = Math.max(0, Math.min(100, score));

                recommendation = String.valueOf(aiResult.get('recommendation'));
                pointsForts = String.valueOf(aiResult.get('points_forts'));
                pointsFaibles = String.valueOf(aiResult.get('points_faibles'));
            } catch (Exception aiEx) {
                recommendation = 'AI analysis error: ' + aiEx.getMessage();
            }

            // Mirror AI output into Lead.Description for easier operational visibility.
            List<String> analysisLines = new List<String>();
            analysisLines.add('=== CV IA Analysis ===');
            analysisLines.add('Score: ' + String.valueOf(score) + '%');
            if (String.isNotBlank(recommendation)) {
                analysisLines.add('Recommendation: ' + recommendation);
            }
            if (String.isNotBlank(pointsForts)) {
                analysisLines.add('Points forts: ' + pointsForts);
            }
            if (String.isNotBlank(pointsFaibles)) {
                analysisLines.add('Points faibles: ' + pointsFaibles);
            }

            String analysisBlock = String.join(analysisLines, '\n');
            String existingDescription = String.isNotBlank(lead.Description) ? lead.Description : '';
            String mergedDescription = analysisBlock + (String.isNotBlank(existingDescription) ? '\n\n' + existingDescription : '');

            // Lead.Description max size is 32k. Keep a safety margin.
            if (mergedDescription.length() > 30000) {
                mergedDescription = mergedDescription.substring(0, 30000);
            }
            lead.Description = mergedDescription;

            setLeadFieldIfExists(lead, 'Score_Matching__c', score);
            setLeadFieldIfExists(lead, 'AI_Recommendation__c', recommendation);
            setLeadFieldIfExists(lead, 'AI_Points_Forts__c', pointsForts);
            setLeadFieldIfExists(lead, 'AI_Points_Faibles__c', pointsFaibles);

            if (score >= 80) {
                lead.Rating = 'Hot';
            } else if (score >= QUALIFICATION_THRESHOLD) {
                lead.Rating = 'Warm';
            } else {
                lead.Rating = 'Cold';
            }

            if (score >= QUALIFICATION_THRESHOLD) {
                String validatedStatus = resolveLeadStatusValue(STATUS_VALIDATED, lead.Status);
                if (String.isNotBlank(validatedStatus)) {
                    lead.Status = validatedStatus;
                }
                update lead;
                executeFullConversion(lead, score);
            } else {
                String rejectedStatus = resolveLeadStatusValue(STATUS_REJECTED, lead.Status);
                if (String.isNotBlank(rejectedStatus)) {
                    lead.Status = rejectedStatus;
                }
                update lead;
            }
        } catch (Exception e) {
            System.debug('runProcessing error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    private static void executeFullConversion(Lead lead, Decimal score) {
        try {
            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(lead.Id);

            List<Contact> existingContacts = [
                SELECT Id, AccountId
                FROM Contact
                WHERE Email = :lead.Email
                LIMIT 1
            ];

            if (!existingContacts.isEmpty()) {
                lc.setContactId(existingContacts[0].Id);
                if (existingContacts[0].AccountId != null) {
                    lc.setAccountId(existingContacts[0].AccountId);
                }
            } else {
                Account newAcc = new Account(Name = String.isNotBlank(lead.Email) ? lead.Email : 'Candidate Account');
                insert newAcc;
                lc.setAccountId(newAcc.Id);
            }

            LeadStatus convertStatus = [SELECT MasterLabel FROM LeadStatus WHERE IsConverted = true LIMIT 1];
            lc.setConvertedStatus(convertStatus.MasterLabel);
            lc.setOpportunityName(lead.LastName + ' - Candidature (' + score + '%)');
            lc.setDoNotCreateOpportunity(false);

            Database.LeadConvertResult lcr = Database.convertLead(lc);
            if (!lcr.isSuccess()) {
                return;
            }

            Id contactId = lcr.getContactId();
            Id oppId = lcr.getOpportunityId();

            if (oppId != null) {
                Opportunity oppUpd = new Opportunity(Id = oppId);
                setOpportunityFieldIfExists(oppUpd, 'Score_Matching__c', score);
                update oppUpd;
            }

            if (contactId != null && String.isNotBlank(lead.Email)) {
                createPortalUserAsync(contactId, lead.FirstName, lead.LastName, lead.Email);
            }
        } catch (Exception e) {
            System.debug('Conversion error: ' + e.getMessage());
        }
    }

    @future
    public static void createPortalUserAsync(Id conId, String fName, String lName, String email) {
        try {
            if (conId == null || String.isBlank(email)) {
                return;
            }

            List<User> existingUsers = [
                SELECT Id, IsActive, UserType, ContactId, Username
                FROM User
                WHERE (Email = :email OR ContactId = :conId)
                  AND UserType IN ('CspLitePortal', 'CustomerPortal', 'PowerCustomerSuccess', 'PowerPartner')
                LIMIT 1
            ];

            if (!existingUsers.isEmpty()) {
                User existingUser = existingUsers[0];
                if (!existingUser.IsActive) {
                    existingUser.IsActive = true;
                    update existingUser;
                }

                if (existingUser.ContactId != conId) {
                    existingUser.ContactId = conId;
                    update existingUser;
                }

                String tempPasswordExisting = generateTempPassword();
                System.setPassword(existingUser.Id, tempPasswordExisting);
                sendWelcomeEmail(email, fName, existingUser.Username, tempPasswordExisting, true);
                return;
            }

            List<User> internalUsers = [SELECT Id FROM User WHERE Email = :email LIMIT 1];
            if (!internalUsers.isEmpty()) {
                return;
            }

            List<Profile> p = [
                SELECT Id, Name
                FROM Profile
                WHERE Name = 'Customer Community Login User'
                LIMIT 1
            ];
            if (p.isEmpty()) {
                p = [SELECT Id, Name FROM Profile WHERE Name = 'Customer Community User' LIMIT 1];
            }
            if (p.isEmpty()) {
                return;
            }

            String safeFirstName = String.isNotBlank(fName) ? fName : 'Candidate';
            String safeLastName = String.isNotBlank(lName) ? lName : 'User';
            String uniqueName = email + '.' + String.valueOf(DateTime.now().getTime());
            String alias = (safeFirstName.substring(0, 1) + safeLastName).left(8).toLowerCase();
            String nickname = (safeFirstName + safeLastName + String.valueOf(DateTime.now().getTime())).left(40);

            User u = new User(
                ContactId = conId,
                ProfileId = p[0].Id,
                FirstName = safeFirstName,
                LastName = safeLastName,
                Email = email,
                Username = uniqueName,
                Alias = alias,
                CommunityNickname = nickname,
                TimeZoneSidKey = 'Africa/Tunis',
                LocaleSidKey = 'fr_TN',
                EmailEncodingKey = 'UTF-8',
                LanguageLocaleKey = 'fr',
                IsActive = true
            );
            insert u;

            String tempPassword = generateTempPassword();
            System.setPassword(u.Id, tempPassword);
            sendWelcomeEmail(email, safeFirstName, u.Username, tempPassword, false);
        } catch (Exception e) {
            System.debug('createPortalUserAsync error: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    public static String generateTempPassword() {
        String upper = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
        String lower = 'abcdefghjkmnpqrstuvwxyz';
        String digits = '23456789';
        String special = '!@#$%&*';
        String all = upper + lower + digits + special;

        List<String> chars = new List<String>();
        Integer idx;

        idx = Math.mod(Math.abs(Crypto.getRandomInteger()), upper.length());
        chars.add(upper.substring(idx, idx + 1));

        idx = Math.mod(Math.abs(Crypto.getRandomInteger()), lower.length());
        chars.add(lower.substring(idx, idx + 1));

        idx = Math.mod(Math.abs(Crypto.getRandomInteger()), digits.length());
        chars.add(digits.substring(idx, idx + 1));

        idx = Math.mod(Math.abs(Crypto.getRandomInteger()), special.length());
        chars.add(special.substring(idx, idx + 1));

        for (Integer i = 4; i < 10; i++) {
            idx = Math.mod(Math.abs(Crypto.getRandomInteger()), all.length());
            chars.add(all.substring(idx, idx + 1));
        }

        String pwd = '';
        while (!chars.isEmpty()) {
            Integer pick = Math.mod(Math.abs(Crypto.getRandomInteger()), chars.size());
            pwd += chars.remove(pick);
        }
        return pwd;
    }

    private static void sendWelcomeEmail(String toEmail, String firstName, String username, String tempPassword, Boolean isExisting) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ toEmail });
            mail.setSubject('Bienvenue sur le Portail RH Talan - Vos identifiants de connexion');
            mail.setSaveAsActivity(false);

            String safeFirstName = String.isNotBlank(firstName) ? firstName : '';
            String body = '<div style="font-family:Segoe UI,Arial,sans-serif; max-width:600px; margin:auto;">'
                + '<div style="background:linear-gradient(135deg,#2F7D59,#1a4d2e); padding:30px; text-align:center; border-radius:12px 12px 0 0;">'
                + '<h1 style="color:#fff; margin:0; font-size:24px;">Portail RH Talan</h1>'
                + '<p style="color:rgba(255,255,255,0.8); margin:8px 0 0; font-size:14px;">Votre espace candidat</p>'
                + '</div>'
                + '<div style="background:#fff; padding:30px; border:1px solid #e0e0e0;">'
                + '<p style="font-size:16px;">Bonjour <strong>' + safeFirstName + '</strong>,</p>';

            if (isExisting) {
                body += '<p>Votre nouvelle candidature a ete validee par notre IA. Voici vos identifiants mis a jour :</p>';
            } else {
                body += '<p>Felicitations ! Votre candidature a ete analysee et validee par notre IA.</p>'
                    + '<p>Un compte a ete cree pour vous. Voici vos identifiants de connexion :</p>';
            }

            body += '<div style="background:#f5f9f7; padding:20px; border-radius:10px; border-left:4px solid #2F7D59; margin:20px 0;">'
                + '<table style="width:100%; border:none;">'
                + '<tr><td style="padding:6px 0; color:#666; width:120px;">Email :</td>'
                + '<td style="padding:6px 0; font-weight:bold;">' + toEmail + '</td></tr>'
                + '<tr><td style="padding:6px 0; color:#666;">Nom utilisateur :</td>'
                + '<td style="padding:6px 0; font-weight:bold;">' + username + '</td></tr>'
                + '<tr><td style="padding:6px 0; color:#666;">Mot de passe :</td>'
                + '<td style="padding:6px 0; font-weight:bold; font-family:monospace; font-size:16px; color:#2F7D59; letter-spacing:1px;">' + tempPassword + '</td></tr>'
                + '</table></div>'
                + '<p style="color:#e65100; font-size:13px;">Nous vous recommandons de changer votre mot de passe apres votre premiere connexion.</p>';

            body += '<p style="text-align:center; margin:25px 0;">'
                + '<a href="' + SITE_URL + '" '
                + 'style="background:#2F7D59; color:#fff; padding:14px 40px; border-radius:8px; text-decoration:none; font-weight:bold; font-size:15px; display:inline-block;">'
                + 'Se connecter au Portail</a></p>'
                + '<p style="color:#999; font-size:12px; margin-top:30px; text-align:center; border-top:1px solid #eee; padding-top:15px;">'
                + 'Cet email a ete envoye automatiquement par le systeme de recrutement Talan.<br>'
                + 'Ne partagez jamais vos identifiants avec un tiers.</p>'
                + '</div></div>';

            mail.setHtmlBody(body);
            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug('sendWelcomeEmail error: ' + e.getMessage());
        }
    }

    private static String resolveLeadStatusValue(String desiredStatus, String fallbackStatus) {
        Set<String> availableStatuses = new Set<String>();
        for (Schema.PicklistEntry entry : Lead.Status.getDescribe().getPicklistValues()) {
            availableStatuses.add(entry.getValue());
        }

        if (String.isNotBlank(desiredStatus) && availableStatuses.contains(desiredStatus)) {
            return desiredStatus;
        }
        if (String.isNotBlank(fallbackStatus) && availableStatuses.contains(fallbackStatus)) {
            return fallbackStatus;
        }
        return null;
    }

    private static void setLeadFieldIfExists(Lead leadRecord, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> leadFields = Schema.SObjectType.Lead.fields.getMap();
        if (leadFields.containsKey(fieldApiName)) {
            leadRecord.put(fieldApiName, value);
        }
    }

    private static void setOpportunityFieldIfExists(Opportunity oppRecord, String fieldApiName, Object value) {
        Map<String, Schema.SObjectField> oppFields = Schema.SObjectType.Opportunity.fields.getMap();
        if (oppFields.containsKey(fieldApiName)) {
            oppRecord.put(fieldApiName, value);
        }
    }
}
