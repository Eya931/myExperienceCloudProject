/*public without sharing class LeadConversionService {

    @future
    public static void convertLeadAsync(Id leadId, Id jobId) {
        convertLead(leadId, jobId);
    }

        @AuraEnabled
        public static void convertLead(Id leadId, Id jobId) {

            if (leadId == null) {
                System.debug(LoggingLevel.ERROR, 'convertLead aborted: leadId is null');
                return;
            }

            System.debug('=== convertLead START === LeadId: ' + leadId);

            try {
                List<Lead> leads = [
                    SELECT Id, FirstName, LastName, Email, Company,
                        OwnerId, IsConverted, Description
                    FROM Lead
                    WHERE Id = :leadId
                    LIMIT 1
                ];

                if (leads.isEmpty()) {
                    System.debug(LoggingLevel.ERROR, 'Lead not found: ' + leadId);
                    return;
                }

                Lead theLead = leads[0];

                if (theLead.IsConverted) {
                    System.debug('Lead already converted. STOP.');
                    return;
                }

                List<LeadStatus> statuses = [
                    SELECT MasterLabel FROM LeadStatus
                    WHERE IsConverted = true
                    LIMIT 1
                ];
                if (statuses.isEmpty()) {
                    System.debug(LoggingLevel.ERROR, 'No converted LeadStatus configured.');
                    return;
                }
                LeadStatus convertedStatus = statuses[0];

                String firstName = theLead.FirstName != null ? theLead.FirstName : '';
                String lastName  = theLead.LastName  != null ? theLead.LastName  : 'Unknown';

                if (String.isBlank(theLead.Company)) {
                    theLead.Company = (firstName + ' ' + lastName).trim();
                    update theLead;
                }

                Database.LeadConvert lc = new Database.LeadConvert();
                lc.setLeadId(leadId);
                lc.setConvertedStatus(convertedStatus.MasterLabel);
                lc.setDoNotCreateOpportunity(false);
                lc.setOverwriteLeadSource(false);
                lc.setOpportunityName('Application - ' + lastName);

                String companyName = String.isNotBlank(theLead.Company)
                    ? theLead.Company
                    : (firstName + ' ' + lastName).trim();
                Id contactIdForConversion;
                Id accountIdForConversion;

                accountIdForConversion = createAccountForLead(companyName);

                Contact newContact = new Contact();
                newContact.FirstName = firstName;
                newContact.LastName  = lastName;
                newContact.Email     = theLead.Email;
                newContact.AccountId = accountIdForConversion;

                Database.DMLOptions dml = new Database.DMLOptions();
                dml.DuplicateRuleHeader.allowSave = true;
                dml.DuplicateRuleHeader.runAsCurrentUser = false;
                Database.insert(newContact, dml);

                contactIdForConversion = newContact.Id;

                if (contactIdForConversion != null && accountIdForConversion == null) {
                    System.debug(LoggingLevel.ERROR,
                        'Conversion aborted: accountId is null while contactId is set for Lead ' + leadId);
                    return;
                }

                lc.setContactId(contactIdForConversion);
                lc.setAccountId(accountIdForConversion);

                System.debug('Calling convertLead...');
                Database.LeadConvertResult result = Database.convertLead(lc, false);
                System.debug('Conversion success: ' + result.isSuccess());

                if (!result.isSuccess()) {
                    String errors = '';
                    for (Database.Error err : result.getErrors()) {
                        errors += '[' + err.getStatusCode() + '] ' + err.getMessage() + ' | ';
                    }
                    System.debug(LoggingLevel.ERROR, 'CONVERSION FAILED: ' + errors);
                    Lead errLead = [SELECT Id, Description FROM Lead WHERE Id = :leadId LIMIT 1];
                    errLead.Description = '[CONVERSION ERROR] ' + errors;
                    update errLead;
                    return;
                }

                System.debug('✅ CONVERSION SUCCESS');

                Id opportunityId = result.getOpportunityId();
                if (opportunityId != null && jobId != null) {
                    List<Job__c> jobs = [SELECT Job_Title__c, Name
                                        FROM Job__c WHERE Id = :jobId LIMIT 1];
                    if (!jobs.isEmpty()) {
                        Opportunity opp = [SELECT Id, Description
                                        FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
                        opp.Description = 'Auto-converted: ' + jobs[0].Job_Title__c
                                        + ' at ' + jobs[0].Name;
                        update opp;
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'convertLead exception for Lead ' + leadId + ': '
                    + e.getMessage() + '\n' + e.getStackTraceString());

                try {
                    List<Lead> errLeads = [SELECT Id, Description FROM Lead WHERE Id = :leadId LIMIT 1];
                    if (!errLeads.isEmpty()) {
                        errLeads[0].Description = '[CONVERSION EXCEPTION] ' + e.getMessage()
                            + '\n' + (errLeads[0].Description != null ? errLeads[0].Description : '');
                        update errLeads[0];
                    }
                } catch (Exception logEx) {
                    System.debug(LoggingLevel.ERROR,
                        'Failed to persist conversion exception on Lead ' + leadId + ': '
                        + logEx.getMessage());
                }
            }
        // Send email notification to Lead Owner 
        //sendConversionNotification(theLead, jobTitle, result.getContactId()); } 
        /** * Sends an email to the Lead Owner informing them of the auto-conversion. */ 
        /*private static void sendConversionNotification(Lead theLead, String jobTitle, Id contactId) { 
            try {
                // Get the owner's email 
                User owner = [
                    SELECT Email, Name 
                    FROM User 
                    WHERE Id = :theLead.OwnerId 
                    LIMIT 1
                    ]; 
                String candidateName = theLead.FirstName + ' ' + theLead.LastName; 
                String contactUrl = URL.getOrgDomainURL().toExternalForm() + '/' + contactId; 
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage(); 
                mail.setToAddresses(new List<String>{ owner.Email }); 
                mail.setSubject('New Hot Candidate Auto-Converted: ' + candidateName); 
                mail.setSaveAsActivity(false); mail.setHtmlBody( '<div style="font-family:Arial,sans-serif;max-width:600px;">' + 
                '<h2 style="color:#04844B;">New Qualified Candidate</h2>' + 
                '<p>A candidate has been <strong>automatically converted</strong> based on their ATS score.</p>' + 
                '<table style="border-collapse:collapse;width:100%;margin:16px 0;">' + 
                '<tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Candidate</td>' + 
                '<td style="padding:8px;border:1px solid #ddd;">' + candidateName + '</td></tr>' 
                + '<tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Email</td>' 
                + '<td style="padding:8px;border:1px solid #ddd;">' + theLead.Email + '</td></tr>' 
                + '<tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Position</td>' 
                + '<td style="padding:8px;border:1px solid #ddd;">' 
                + (String.isNotBlank(jobTitle) ? jobTitle : 'N/A') + '</td></tr>' 
                + '<tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Rating</td>' 
                + '<td style="padding:8px;border:1px solid #ddd;color:#04844B;font-weight:bold;">' 
                + theLead.Rating + '</td></tr>' + '</table>' + '<p><a href="' + contactUrl + '" ' 
                + 'style="background:#0070D2;color:white;padding:10px 24px;text-decoration:none;border-radius:4px;">' 
                + 'View Contact Record</a></p>' + '<hr style="border:none;border-top:1px solid #eee;margin:24px 0;"/>' 
                + '<p style="color:#666;font-size:12px;">ATS Analysis Details:<br/>' 
                + (theLead.Description != null ? theLead.Description.left(500).replaceAll('\n', '<br/>') : '') 
                + '</p>' + '</div>' ); Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail }); 
            } catch (Exception e) { 
                System.debug(LoggingLevel.ERROR, 'Failed to send conversion notification: ' + e.getMessage()); 
            } 
        }*/
   // }

   /*private static Id createAccountForLead(String companyName) {
        String safeCompanyName = String.isNotBlank(companyName) ? companyName : 'Individual Candidate';
        Account a = new Account(Name = safeCompanyName);
        Database.DMLOptions dml = new Database.DMLOptions();
        dml.DuplicateRuleHeader.allowSave = true;
        dml.DuplicateRuleHeader.runAsCurrentUser = false;
        Database.insert(a, dml);
        return a.Id;
    }
}*/

public without sharing class LeadConversionService {
    @InvocableMethod
    public static void convertLeads(List<Id> leadIds) {
        for (Id leadId : leadIds) {

            Lead lead = [
                SELECT Id, FirstName, LastName, Company, Email, AI_Match_Score__c
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            // ✅ Créer l'Account manuellement AVANT la conversion
            //    (setAccountName n'existe pas dans l'API Apex)
            String accountName = 'Candidat - ' + lead.FirstName + ' ' + lead.LastName;

            // Vérifie si un Account avec ce nom existe déjà
            List<Account> existingAccounts = [
                SELECT Id FROM Account
                WHERE Name = :accountName
                LIMIT 1
            ];

            Id accountId;
            if (!existingAccounts.isEmpty()) {
                accountId = existingAccounts[0].Id;
            } else {
                Account acc = new Account(Name = accountName);
                insert acc;
                accountId = acc.Id;
            }

            Database.LeadConvert lc = new Database.LeadConvert();
            lc.setLeadId(leadId);

            // ✅ Statut converti valide
            lc.setConvertedStatus('Candidat Converti');

            // ✅ On VEUT une Opportunity — process de recrutement
            lc.setDoNotCreateOpportunity(false);

            // ✅ Nom de l'Opportunity = "Application - Prénom Nom"
            lc.setOpportunityName('Application - ' + lead.FirstName + ' ' + lead.LastName);

            // ✅ Account = "Candidat - Prénom Nom"
            lc.setAccountId(accountId);

            // ✅ Pas d'email automatique (conversion par IA)
            lc.setSendNotificationEmail(false);

            try {
                Database.LeadConvertResult result = Database.convertLead(lc);

                if (result.isSuccess()) {
                    System.debug(LoggingLevel.INFO,
                        '✅ Lead converti: ' + leadId
                        + ' | Contact: '     + result.getContactId()
                        + ' | Account: '     + result.getAccountId()
                        + ' | Opportunity: ' + result.getOpportunityId());

                    Id contactId     = result.getContactId();
                    Id opportunityId = result.getOpportunityId();

                    // ✅ Met à jour l'Opportunity avec le bon StageName
                    //    et les infos de recrutement
                    Opportunity opp = [
                        SELECT Id, Name, StageName, CloseDate, Candidate_Contact__c
                        FROM Opportunity
                        WHERE Id = :opportunityId
                        LIMIT 1
                    ];

                    opp.StageName = 'Application Received';  // ← 1ère étape du process
                    opp.CloseDate = Date.today().addDays(60); // deadline estimée
                    opp.Candidate_Contact__c = contactId;
                    opp.Description = 'Candidature automatiquement qualifiée par IA.\n'
                                    + 'Score ATS : ' + lead.AI_Match_Score__c + '%\n'
                                    + 'Lead source : ' + leadId;

                    // Lien vers le Job si le champ existe sur Opportunity
                    // opp.Job__c = lead.Job__c;


                    update opp;

                    // ✅ Crée aussi un OpportunityContactRole (standard Salesforce)
                    OpportunityContactRole ocr = new OpportunityContactRole(
                        OpportunityId = opportunityId,
                        ContactId     = contactId,
                        Role          = 'Decision Maker',
                        IsPrimary     = true
                    );
                    insert ocr;

                    // ✅ Empêche le Flow de re-déclencher en boucle
                    update new Lead(Id = leadId, Auto_Converted__c = true, Conversion_Triggered__c = false);

                } else {
                    for (Database.Error err : result.getErrors()) {
                        System.debug(LoggingLevel.ERROR,
                            '❌ Erreur conversion ' + leadId + ': '
                            + err.getStatusCode() + ' — ' + err.getMessage());
                    }
                }

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'LeadConversionService exception: ' + e.getMessage()
                    + '\n' + e.getStackTraceString());
            }
        }
    }
}
