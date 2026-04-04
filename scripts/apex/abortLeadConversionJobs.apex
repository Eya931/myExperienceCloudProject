for (CronTrigger ct : [SELECT Id, CronJobDetail.Name FROM CronTrigger WHERE CronJobDetail.Name LIKE 'LeadConversionScheduledProcessorJob%']) {
    System.abortJob(ct.Id);
}
