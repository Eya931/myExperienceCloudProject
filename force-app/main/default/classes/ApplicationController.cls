/**
 * ApplicationController
 * Handles job application submissions from guest users.
 * Creates a Lead record and attaches the uploaded CV, then enqueues
 * the CV-parsing / job-matching background job.
 */
public without sharing class ApplicationController {

    @AuraEnabled
    public static Id submitApplication(
        String firstName,
        String lastName,
        String email,
        String phone,
        String jobId,
        String cvFileName,
        String cvBase64
    ) {
        // ---- Input validation ----
        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            throw new AuraHandledException('First Name and Last Name are required.');
        }
        if (String.isBlank(email) || !Pattern.matches('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$', email)) {
            throw new AuraHandledException('A valid email address is required.');
        }
        if (String.isBlank(cvBase64) || String.isBlank(cvFileName)) {
            throw new AuraHandledException('Please upload your CV.');
        }
        if (String.isBlank(jobId) || !(jobId instanceOf Id)) {
            throw new AuraHandledException('Invalid job reference.');
        }

        // ---- Fetch job title for Lead description ----
        List<Job__c> jobs = [
            SELECT Id, Job_Title__c, Name
            FROM Job__c
            WHERE Id = :jobId
            LIMIT 1
        ];
        String jobLabel = jobs.isEmpty()
            ? jobId
            : jobs[0].Job_Title__c + ' at ' + jobs[0].Name;

        // ---- Create Lead ----
        Lead newLead = new Lead(
            FirstName  = firstName.trim(),
            LastName   = lastName.trim(),
            Email      = email.trim(),
            Phone      = String.isNotBlank(phone) ? phone.trim() : null,
            Company    = firstName.trim() + ' ' + lastName.trim(),
            LeadSource = 'Web',
            Status     = 'Candidat - Non contacté',
            Description = 'Applied for: ' + jobLabel + '\nJob ID: ' + jobId
        );
        insert newLead;

        // ---- Attach CV as a file (ContentVersion) ----
        ContentVersion cv = new ContentVersion(
            Title                 = cvFileName,
            PathOnClient          = '/' + cvFileName,
            VersionData           = EncodingUtil.base64Decode(cvBase64),
            FirstPublishLocationId = newLead.Id
        );
        insert cv;

        System.debug('>>> START QUEUEABLE <<<');
        System.debug('LeadId: ' + newLead.Id);
        System.debug('JobId: ' + jobId);

        CVParserService service = new CVParserService(newLead.Id, jobId);
        System.debug('Service created: ' + service);

        System.enqueueJob(service);
        return newLead.Id;
    }
}