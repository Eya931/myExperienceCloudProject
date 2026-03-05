/**
 * LeadConversionService
 * Converts a qualified Lead into Account + Contact + Opportunity.
 * Called automatically by CVParserService when the match score ≥ 70 %,
 * or can be invoked manually from a Flow / trigger.
 */
public without sharing class LeadConversionService {

    /**
     * Convert a Lead and link the resulting Opportunity to the originating Job.
     * @param leadId  The Lead to convert
     * @param jobId   The Job__c record the candidate applied for
     */
    @AuraEnabled
    public static void convertLead(Id leadId, Id jobId) {
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
        if (opportunityId != null && String.isNotBlank(jobId)) {
            Opportunity opp = [SELECT Id, Description FROM Opportunity WHERE Id = :opportunityId LIMIT 1];
            // Fetch job info for a meaningful Opportunity description
            List<Job__c> jobs = [SELECT Job_Title__c, Name FROM Job__c WHERE Id = :jobId LIMIT 1];
            if (!jobs.isEmpty()) {
                opp.Description = 'Auto-converted from application for: '
                    + jobs[0].Job_Title__c + ' at ' + jobs[0].Name
                    + '\nJob ID: ' + jobId;
            }
            update opp;
        }
    }
}
