public without sharing class PortalController {

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMyMessages() {
        // Keep payload shape expected by LWCs; empty list is handled by UI fallbacks.
        return new List<Map<String, Object>>();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMyApplications() {
        // Keep payload shape expected by LWCs; empty list is handled by UI fallbacks.
        return new List<Map<String, Object>>();
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOpenJobs() {
        List<Map<String, Object>> jobs = new List<Map<String, Object>>();
        try {
            for (Job__c job : [
                SELECT Id, Name, Department__c, Location__c, Employment_Type__c
                FROM Job__c
                WHERE Status__c = 'Active'
                ORDER BY CreatedDate DESC
                LIMIT 100
            ]) {
                jobs.add(new Map<String, Object>{
                    'id' => job.Id,
                    'dept' => job.Department__c,
                    'title' => job.Name,
                    'type' => job.Employment_Type__c,
                    'location' => job.Location__c,
                    'exp' => '',
                    'salary' => '',
                    'posted' => ''
                });
            }
        } catch (Exception e) {
            // LWC already falls back to local demo data when this list is empty.
        }
        return jobs;
    }

    @AuraEnabled
    public static void saveProfile(String firstName, String lastName, Boolean available) {
        // Placeholder endpoint to satisfy LWC contract.
        // Persisting profile data can be implemented later against Contact/User model.
    }
}
