public without sharing class LeadConversionQueueable implements Queueable {
    private static final Integer MAX_RETRIES = 2;

    private Id leadId;
    private Id jobId;
    private Integer retryCount;

    public LeadConversionQueueable(Id leadId, Id jobId) {
        this(leadId, jobId, 0);
    }

    public LeadConversionQueueable(Id leadId, Id jobId, Integer retryCount) {
        this.leadId = leadId;
        this.jobId  = jobId;
        this.retryCount = retryCount != null ? retryCount : 0;
    }

    public void execute(QueueableContext ctx) {
        if (leadId == null) {
            System.debug(LoggingLevel.ERROR, 'LeadConversionQueueable aborted: leadId is null');
            return;
        }

        if (UserInfo.getUserType() == 'Guest') {
            System.debug(LoggingLevel.WARN,
                'LeadConversionQueueable skipped for Guest user context. LeadId=' + leadId);
            return;
        }

        try {
            //LeadConversionService.convertLead(leadId, jobId);

            Lead latestLead = [
                SELECT Id, IsConverted, Description
                FROM Lead
                WHERE Id = :leadId
                LIMIT 1
            ];

            if (!latestLead.IsConverted && retryCount < MAX_RETRIES) {
                System.debug(LoggingLevel.WARN,
                    'Lead still not converted, retrying conversion. LeadId=' + leadId
                    + ', attempt=' + String.valueOf(retryCount + 1));
                System.enqueueJob(new LeadConversionQueueable(leadId, jobId, retryCount + 1));
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'LeadConversionQueueable failed for Lead ' + leadId + ': '
                + e.getMessage() + '\n' + e.getStackTraceString());

            if (retryCount < MAX_RETRIES) {
                System.enqueueJob(new LeadConversionQueueable(leadId, jobId, retryCount + 1));
            }
        }
    }
}