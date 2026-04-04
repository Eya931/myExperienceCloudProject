for (CronTrigger ct : [SELECT Id FROM CronTrigger WHERE CronJobDetail.Name LIKE 'LeadConversionScheduledProcessorJob%']) {
    System.abortJob(ct.Id);
}
for (AsyncApexJob job : [
    SELECT Id, Status, ApexClass.Name
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'LeadConversionScheduledProcessor'
      AND Status IN ('Holding','Queued','Preparing','Processing')
]) {
    System.abortJob(job.Id);
}
