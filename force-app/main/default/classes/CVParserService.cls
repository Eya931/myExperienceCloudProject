/**
 * CVParserService  (Queueable)
 * Runs asynchronously after a Lead is created.
 * 1. Reads the attached CV content.
 * 2. Extracts text (plain-text / txt files directly; for PDF/DOCX a
 *    production org would call an external AI API — see placeholder below).
 * 3. Compares extracted skills against the Job__c.Required_Skills__c field.
 * 4. Rates the Lead: Hot (≥ 70 %), Warm (≥ 40 %), Cold (< 40 %).
 * 5. If Hot → auto-converts the Lead via LeadConversionService.
 */
public without sharing class CVParserService implements Queueable {

    private Id leadId;
    private Id jobId;

    public CVParserService(Id leadId, Id jobId) {
        this.leadId = leadId;
        this.jobId  = jobId;
    }

    /* ---- Queueable entry point ---- */

    public void execute(QueueableContext ctx) {
        try {
            String cvText = extractCVText();
            if (String.isBlank(cvText)) {
                return; // nothing to parse
            }

            Job__c job = [
                SELECT Required_Skills__c, Department__c, Job_Title__c
                FROM Job__c
                WHERE Id = :jobId
                LIMIT 1
            ];

            Integer matchScore = calculateMatchScore(cvText, job.Required_Skills__c);

            // Update Lead rating + append score to description
            Lead lead = [SELECT Id, Description, Rating FROM Lead WHERE Id = :leadId LIMIT 1];
            lead.Rating = matchScore >= 70 ? 'Hot'
                        : matchScore >= 40 ? 'Warm'
                        : 'Cold';

            String scoreNote = 'CV Match Score: ' + matchScore + '% for ' + job.Job_Title__c;
            lead.Description = scoreNote + '\n' + (lead.Description != null ? lead.Description : '');
            update lead;

            // Auto-convert hot leads
            if (matchScore >= 70) {
                LeadConversionService.convertLead(leadId, jobId);
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'CVParserService failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
        }
    }

    /* ---- CV text extraction ---- */

    private String extractCVText() {
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId
            LIMIT 1
        ];
        if (cdls.isEmpty()) {
            return null;
        }

        ContentVersion cv = [
            SELECT VersionData, FileExtension, Title
            FROM ContentVersion
            WHERE ContentDocumentId = :cdls[0].ContentDocumentId
              AND IsLatest = true
            LIMIT 1
        ];

        String ext = cv.FileExtension?.toLowerCase();

        // Plain-text files can be read directly
        if (ext == 'txt' || ext == 'csv') {
            return cv.VersionData.toString();
        }

        /*
         * ---------------------------------------------------------------
         * PRODUCTION AI INTEGRATION PLACEHOLDER
         * For PDF / DOCX, send the binary to an external extraction or
         * LLM service (e.g. OpenAI, Claude, Google Document AI).
         *
         *   HttpRequest req = new HttpRequest();
         *   req.setEndpoint('callout:CV_Parser_API/extract');
         *   req.setMethod('POST');
         *   req.setBodyAsBlob(cv.VersionData);
         *   HttpResponse res = new Http().send(req);
         *   return res.getBody();
         *
         * For now we fall back to the file title so the skill-matching
         * can still demonstrate functionality.
         * ---------------------------------------------------------------
         */
        return cv.Title != null ? cv.Title : '';
    }

    /* ---- Skill matching ---- */

    @TestVisible
    private Integer calculateMatchScore(String cvText, String requiredSkills) {
        if (String.isBlank(requiredSkills) || String.isBlank(cvText)) {
            return 0;
        }

        List<String> skills = requiredSkills.split(',');
        Integer total   = 0;
        Integer matched = 0;
        String  cvLower = cvText.toLowerCase();

        for (String skill : skills) {
            String trimmed = skill.trim().toLowerCase();
            if (String.isBlank(trimmed)) {
                continue;
            }
            total++;
            if (cvLower.contains(trimmed)) {
                matched++;
            }
        }

        return total == 0 ? 0 : (matched * 100) / total;
    }
}
