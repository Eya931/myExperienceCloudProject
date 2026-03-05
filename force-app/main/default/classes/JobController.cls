public without sharing class JobController {

    @AuraEnabled(cacheable=true)
    public static List<Job__c> getJobs() {
        return [
            SELECT Id, Name, Job_Title__c, Location__c, Currency__c,
                   Department__c, Experience_Level__c, Employment_Type__c,
                   Required_Skills__c, Job_Description__c,
                   Number_of_Openings__c, Status__c, CreatedDate
            FROM Job__c
            WHERE Status__c = 'Open'
            ORDER BY CreatedDate DESC
        ];
    }
}