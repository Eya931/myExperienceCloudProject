/**
 * HRDashboardController
 * Provides all data for the HR Dashboard LWC component.
 * Exposes wire-compatible @AuraEnabled(cacheable=true) methods.
 */
public without sharing class HRDashboardController {

    // ── Stat counters ─────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Integer getOpenJobsCount() {
        return [
            SELECT COUNT() FROM Job__c
            WHERE Status__c = 'Active'
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Integer getActiveCandidatesCount() {
        return [
            SELECT COUNT() FROM Opportunity
            WHERE StageName NOT IN ('Offer Accepted', 'Rejected')
            AND IsClosed = false
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Integer getInterviewsTodayCount() {
        DateTime startOfDay = DateTime.newInstance(Date.today(), Time.newInstance(0,0,0,0));
        DateTime endOfDay   = DateTime.newInstance(Date.today(), Time.newInstance(23,59,59,999));
        return [
            SELECT COUNT() FROM Interview__c
            WHERE Interview_Date_Time__c >= :startOfDay
            AND Interview_Date_Time__c <= :endOfDay
            AND Interview_Status__c = 'Scheduled'
            ];
        }

    // ── Dashboard stats object ────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getDashboardStats() {
        Map<String, Object> stats = new Map<String, Object>();

        // Open jobs
        stats.put('openJobs', [
            SELECT COUNT() FROM Job__c WHERE Status__c = 'Active'
        ]);

        // Urgent jobs (posted > 14 days with low applicants)
        stats.put('urgentJobs', [
            SELECT COUNT() FROM Job__c
            WHERE Status__c = 'Active'
            AND Posted_Date__c < :Date.today().addDays(-14)
            AND Number_of_Applicants__c < 5
        ]);

        // Active candidates (open opportunities)
        stats.put('activeCandidates', [
            SELECT COUNT() FROM Opportunity WHERE IsClosed = false
        ]);

        // New this week
        stats.put('newThisWeek', [
            SELECT COUNT() FROM Opportunity
            WHERE CreatedDate = THIS_WEEK
        ]);

        // Scheduled interviews
       Date firstDay = Date.today().toStartOfMonth();
        Date lastDay  = firstDay.addMonths(1);
        DateTime startDT = DateTime.newInstance(firstDay, Time.newInstance(0,0,0,0));
        DateTime endDT   = DateTime.newInstance(lastDay,  Time.newInstance(0,0,0,0));
        stats.put('scheduledInterviews', [
            SELECT COUNT() FROM Interview__c
            WHERE Interview_Status__c = 'Scheduled'
            AND Interview_Date_Time__c >= :startDT
            AND Interview_Date_Time__c < :endDT
        ]);

        // Offers extended
        stats.put('offersExtended', [
            SELECT COUNT() FROM Opportunity WHERE StageName = 'Offer Extended'
        ]);

        return stats;
    }

    // ── Recent applications ───────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getRecentApplications() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        List<Opportunity> opps = [
            SELECT Id, Name, StageName, AI_Match_Score__c,
                   ContactId, Applied_Job__c
            FROM Opportunity
            WHERE IsClosed = false
            ORDER BY CreatedDate DESC
            LIMIT 10
        ];

        Set<Id> contactIds = new Set<Id>();
        Set<Id> jobIds = new Set<Id>();
        for (Opportunity opp : opps) {
            if (opp.ContactId != null) {
                contactIds.add(opp.ContactId);
            }
            Id jobId = (Id) opp.get('Applied_Job__c');
            if (jobId != null) {
                jobIds.add(jobId);
            }
        }

        Map<Id, Contact> contactsById = new Map<Id, Contact>();
        if (!contactIds.isEmpty()) {
            contactsById = new Map<Id, Contact>([
                SELECT Id, FirstName, LastName, Email
                FROM Contact
                WHERE Id IN :contactIds
            ]);
        }

        Map<Id, Job__c> jobsById = new Map<Id, Job__c>();
        if (!jobIds.isEmpty()) {
            jobsById = new Map<Id, Job__c>([
                SELECT Id, Name, Job_Title__c
                FROM Job__c
                WHERE Id IN :jobIds
            ]);
        }

        for (Opportunity opp : opps) {
            Map<String, Object> row = new Map<String, Object>();
            Contact c = contactsById.get(opp.ContactId);
            Id jobId = (Id) opp.get('Applied_Job__c');
            Job__c job = jobsById.get(jobId);

            row.put('id',        opp.Id);
            row.put('firstName', c != null ? c.FirstName : null);
            row.put('lastName',  c != null ? c.LastName : null);
            row.put('email',     c != null ? c.Email : null);
            row.put('role',      job != null ? (String.isNotBlank(job.Job_Title__c) ? job.Job_Title__c : job.Name) : null);
            row.put('stage',     opp.StageName);
            row.put('aiScore',   opp.AI_Match_Score__c != null ? Integer.valueOf(opp.AI_Match_Score__c) : 0);
            result.add(row);
        }

        return result;
    }

    // ── Today's interviews ────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getTodaysInterviews() {
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    DateTime startOfDay = DateTime.newInstance(Date.today(), Time.newInstance(0,0,0,0));
    DateTime endOfDay   = DateTime.newInstance(Date.today(), Time.newInstance(23,59,59,999));

    List<Interview__c> interviews = [
        SELECT Id, Interview_Round__c, Interview_Date_Time__c,
               Format__c, Interview_Status__c
        FROM Interview__c
        WHERE Interview_Date_Time__c >= :startOfDay
        AND Interview_Date_Time__c <= :endOfDay
        AND Interview_Status__c = 'Scheduled'
        ORDER BY Interview_Date_Time__c ASC
        LIMIT 10
    ];

        for (Interview__c iv : interviews) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id',            iv.Id);
            row.put('round',         iv.Interview_Round__c);
            row.put('dateTime',      iv.Interview_Date_Time__c);
            row.put('format',        iv.Format__c);
            row.put('interviewer',   null);
            row.put('candidateName', '');
            result.add(row);
        }

        return result;
    }

    // ── Open jobs ─────────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOpenJobs() {
        List<Map<String, Object>> result = new List<Map<String, Object>>();

        List<Job__c> jobs = [
            SELECT Id, Name, Department__c, Location__c,
                   Number_of_Applicants__c
            FROM Job__c
            WHERE Status__c = 'Active'
            ORDER BY Number_of_Applicants__c DESC NULLS LAST
            LIMIT 6
        ];

        for (Job__c job : jobs) {
            Map<String, Object> row = new Map<String, Object>();
            row.put('id',         job.Id);
            row.put('title',      job.Name);
            row.put('dept',       job.Department__c);
            row.put('location',   job.Location__c);
            row.put('applicants', job.Number_of_Applicants__c != null
                                   ? Integer.valueOf(job.Number_of_Applicants__c) : 0);
            result.add(row);
        }

        return result;
    }

    // ── Pipeline data ─────────────────────────────────────────────────────────

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPipelineData() {
        List<String> stages = new List<String>{
            'Application Received', 'HR Interview',
            'Technical Interview', 'Final Interview',
            'Offer Extended'
        };

        // Count per stage using AggregateResult
        Map<String, Integer> countMap = new Map<String, Integer>();
        for (String s : stages) { countMap.put(s, 0); }

        for (AggregateResult ar : [
            SELECT StageName, COUNT(Id) cnt
            FROM Opportunity
            WHERE StageName IN :stages
            AND IsClosed = false
            GROUP BY StageName
        ]) {
            countMap.put((String)ar.get('StageName'), Integer.valueOf(ar.get('cnt')));
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (String s : stages) {
            result.add(new Map<String, Object>{ 'name' => s, 'count' => countMap.get(s) });
        }
        return result;
    }
}