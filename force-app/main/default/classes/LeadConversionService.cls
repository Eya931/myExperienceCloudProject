/**
 * LeadConversionService
 * Converts a qualified Lead into Account + Contact + Opportunity.
 * Called automatically by CVParserService when the match score ≥ 70 %,
 * or can be invoked manually from a Flow / trigger.
 * Sends an email notification to the Lead Owner upon conversion.
 */
public without sharing class LeadConversionService {

    /**
     * Convert a Lead and link the resulting Opportunity to the originating Job.
     * @param leadId  The Lead to convert
     * @param jobId   The Job__c record the candidate applied for
     */
    @AuraEnabled
    public static void convertLead(Id leadId, Id jobId) {

        // Fetch Lead info for the notification email
        Lead theLead = [
            SELECT FirstName, LastName, Email, Rating, Description, OwnerId, IsConverted
            FROM Lead
            WHERE Id = :leadId
            LIMIT 1
        ];

        if(theLead.IsConverted){
            System.debug('Lead already converted. Skipping.');
            return;
        }

        // Find the converted status value configured in the org
        LeadStatus convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ];

        Database.LeadConvert lc = new Database.LeadConvert();
        lc.setLeadId(leadId);
        lc.setConvertedStatus(convertedStatus.MasterLabel);
        lc.setDoNotCreateOpportunity(false);

        Database.LeadConvertResult result = Database.convertLead(lc);

        if (!result.isSuccess()) {
            String errors = '';
            for (Database.Error err : result.getErrors()) {
                errors += err.getMessage() + ' ';
            }
            System.debug(LoggingLevel.ERROR, 'Lead conversion failed: ' + errors);
            return;
        }

        // Stamp the Opportunity with the Job reference
        Id opportunityId = result.getOpportunityId();
        String jobTitle = '';
        if (opportunityId != null && String.isNotBlank(jobId)) {
            Opportunity opp = [SELECT Id, Description FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            List<Job__c> jobs = [SELECT Job_Title__c, Name FROM Job__c WHERE Id = :jobId LIMIT 1];
            if (!jobs.isEmpty()) {
                jobTitle = jobs[0].Job_Title__c;
                opp.Description = 'Auto-converted from application for: '
                    + jobTitle + ' at ' + jobs[0].Name
                    + '\nJob ID: ' + jobId;
            }
            update opp;
        }

        // Send email notification to Lead Owner
        sendConversionNotification(theLead, jobTitle, result.getContactId());
    }

    /**
     * Sends an email to the Lead Owner informing them of the auto-conversion.
     */
    private static void sendConversionNotification(Lead theLead, String jobTitle, Id contactId) {
        try {
            // Get the owner's email
            User owner = [SELECT Email, Name FROM User WHERE Id = :theLead.OwnerId LIMIT 1];

            String candidateName = theLead.FirstName + ' ' + theLead.LastName;
            String contactUrl = URL.getOrgDomainURL().toExternalForm()
                + '/' + contactId;

            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new List<String>{ owner.Email });
            mail.setSubject('New Hot Candidate Auto-Converted: ' + candidateName);
            mail.setSaveAsActivity(false);
            mail.setHtmlBody(
                '<div style="font-family:Arial,sans-serif;max-width:600px;">'
              + '<h2 style="color:#04844B;">New Qualified Candidate</h2>'
              + '<p>A candidate has been <strong>automatically converted</strong> based on their ATS score.</p>'
              + '<table style="border-collapse:collapse;width:100%;margin:16px 0;">'
              + '<tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Candidate</td>'
              +     '<td style="padding:8px;border:1px solid #ddd;">' + candidateName + '</td></tr>'
              + '<tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Email</td>'
              +     '<td style="padding:8px;border:1px solid #ddd;">' + theLead.Email + '</td></tr>'
              + '<tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Position</td>'
              +     '<td style="padding:8px;border:1px solid #ddd;">' + (String.isNotBlank(jobTitle) ? jobTitle : 'N/A') + '</td></tr>'
              + '<tr><td style="padding:8px;border:1px solid #ddd;font-weight:bold;">Rating</td>'
              +     '<td style="padding:8px;border:1px solid #ddd;color:#04844B;font-weight:bold;">' + theLead.Rating + '</td></tr>'
              + '</table>'
              + '<p><a href="' + contactUrl + '" '
              + 'style="background:#0070D2;color:white;padding:10px 24px;text-decoration:none;border-radius:4px;">'
              + 'View Contact Record</a></p>'
              + '<hr style="border:none;border-top:1px solid #eee;margin:24px 0;"/>'
              + '<p style="color:#666;font-size:12px;">ATS Analysis Details:<br/>'
              + (theLead.Description != null ? theLead.Description.left(500).replaceAll('\n', '<br/>') : '') + '</p>'
              + '</div>'
            );

            Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ mail });
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'Failed to send conversion notification: ' + e.getMessage());
        }
    }
}
