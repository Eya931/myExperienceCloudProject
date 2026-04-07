public without sharing class PortalController {
    private static final String ASSISTANT_PROMPT_TEMPLATE_API_NAME = 'Candidate_Portal_Assistant';
    private static final String ASSISTANT_APP_NAME = 'TalentBridge_CandidateAssistant';
    private static final String ASSISTANT_VALIDATION_CHECKLIST =
        'Validate in Experience Cloud with a real candidate user: profile edit, CV upload, applications stage flow, and interview reminders.';


    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMyMessages() {
        User portalUser = getCurrentPortalUser();
        if (portalUser == null) {
            return new List<Map<String, Object>>();
        }

        Id candidateContactId = resolveCandidateContactId(portalUser);
        Set<String> candidateEmails = collectCandidateEmails(portalUser);
        Set<Id> opportunityIds = getCandidateOpportunityIds(candidateContactId, candidateEmails);
        List<Map<String, Object>> messages = buildInterviewMessages(candidateContactId, opportunityIds);

        Integer seed = 0;
        for (Map<String, Object> app : getMyApplications()) {
            if (seed >= 3) {
                break;
            }

            String appTitle = (String) app.get('title');
            String stageName = (String) app.get('stage');
            String appliedDate = (String) app.get('appliedDate');
            messages.add(new Map<String, Object>{
                'id' => 'stage-' + String.valueOf(seed),
                'from' => 'TalentBridge Team',
                'subject' => 'Application update - ' + (String.isNotBlank(appTitle) ? appTitle : 'Your application'),
                'preview' => 'Current stage: ' + (String.isNotBlank(stageName) ? stageName : 'Application Received'),
                'time' => appliedDate,
                'unread' => false,
                'category' => 'application',
                'body' => '<p>Your application is currently at stage <b>'
                    + (String.isNotBlank(stageName) ? stageName : 'Application Received')
                    + '</b>.</p>'
            });
            seed++;
        }

        return messages;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getMyApplications() {
        User portalUser = getCurrentPortalUser();
        if (portalUser == null) {
            return new List<Map<String, Object>>();
        }

        Id candidateContactId = resolveCandidateContactId(portalUser);
        Set<String> candidateEmails = collectCandidateEmails(portalUser);
        Set<Id> opportunityIds = getCandidateOpportunityIds(candidateContactId, candidateEmails);
        if (opportunityIds.isEmpty()) {
            return new List<Map<String, Object>>();
        }

        List<Opportunity> opportunities = [
            SELECT Id, Name, StageName, CreatedDate, AI_Match_Score__c, Applied_Job__c
            FROM Opportunity
            WHERE Id IN :opportunityIds
            ORDER BY CreatedDate DESC
            LIMIT 100
        ];

        Set<Id> jobIds = new Set<Id>();
        for (Opportunity opp : opportunities) {
            if (opp.Applied_Job__c != null) {
                jobIds.add(opp.Applied_Job__c);
            }
        }

        Map<Id, Job__c> jobsById = new Map<Id, Job__c>();
        if (!jobIds.isEmpty()) {
            jobsById = new Map<Id, Job__c>([
                SELECT Id, Name, Job_Title__c, Department__c, Location__c, Salary_Range__c
                FROM Job__c
                WHERE Id IN :jobIds
            ]);
        }

        List<Map<String, Object>> result = new List<Map<String, Object>>();
        for (Opportunity opp : opportunities) {
            Job__c job = jobsById.get(opp.Applied_Job__c);
            String title = job != null
                ? (String.isNotBlank(job.Job_Title__c) ? job.Job_Title__c : job.Name)
                : opp.Name;
            String dept = job != null ? job.Department__c : '';
            String location = job != null ? job.Location__c : '';
            String salary = job != null ? job.Salary_Range__c : '';
            String stage = String.isNotBlank(opp.StageName) ? opp.StageName : 'Application Received';

            result.add(new Map<String, Object>{
                'id' => opp.Id,
                'title' => title,
                'dept' => dept,
                'location' => location,
                'salary' => salary,
                'stage' => stage,
                'appliedDate' => opp.CreatedDate.format('MMM d, yyyy'),
                'currentStep' => resolveStageStep(stage),
                'badgeClass' => resolveBadgeClass(stage),
                'initials' => extractInitials(title),
                'iconClass' => 'app-ico',
                'role' => title,
                'meta' => joinMeta(dept, location),
                'aiScore' => opp.AI_Match_Score__c != null ? Integer.valueOf(opp.AI_Match_Score__c) : 0
            });
        }

        return result;
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getOpenJobs() {
        List<Map<String, Object>> jobs = new List<Map<String, Object>>();
        try {
            for (Job__c job : [
                SELECT Id, Name, Department__c, Location__c, Employment_Type__c
                FROM Job__c
                WHERE Status__c IN ('Open', 'Active')
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
    public static void saveProfile(String firstName, String lastName, String email, String phone, Boolean available) {
        User portalUser = getCurrentPortalUser();
        if (portalUser == null) {
            throw new AuraHandledException('Unable to load current user profile.');
        }

        Id candidateContactId = resolveCandidateContactId(portalUser);

        if (String.isBlank(firstName) || String.isBlank(lastName)) {
            throw new AuraHandledException('First Name and Last Name are required.');
        }

        if (String.isBlank(email) || !Pattern.matches('^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$', email)) {
            throw new AuraHandledException('Please provide a valid email.');
        }

        portalUser.FirstName = firstName.trim();
        portalUser.LastName = lastName.trim();
        portalUser.Email = email.trim();
        update portalUser;

        if (candidateContactId != null) {
            Contact contactRecord = [
                SELECT Id, FirstName, LastName, Email, Phone
                FROM Contact
                WHERE Id = :candidateContactId
                LIMIT 1
            ];
            contactRecord.FirstName = firstName.trim();
            contactRecord.LastName = lastName.trim();
            contactRecord.Email = email.trim();
            contactRecord.Phone = String.isNotBlank(phone) ? phone.trim() : null;
            update contactRecord;
        }
    }

    @AuraEnabled
    public static String uploadProfileCv(String cvFileName, String cvBase64) {
        if (String.isBlank(cvFileName) || String.isBlank(cvBase64)) {
            throw new AuraHandledException('Please select a CV file before upload.');
        }

        User portalUser = getCurrentPortalUser();
        if (portalUser == null) {
            throw new AuraHandledException('Unable to identify current user.');
        }

        Id candidateContactId = resolveCandidateContactId(portalUser);
        Id targetId = candidateContactId != null ? candidateContactId : portalUser.Id;
        ContentVersion cv = new ContentVersion(
            Title = cvFileName,
            PathOnClient = '/' + cvFileName,
            VersionData = EncodingUtil.base64Decode(cvBase64),
            FirstPublishLocationId = targetId
        );
        insert cv;
        return cv.Id;
    }

    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCurrentCandidateProfile() {
        User portalUser = getCurrentPortalUser();
        if (portalUser == null) {
            return new Map<String, Object>();
        }

        Id candidateContactId = resolveCandidateContactId(portalUser);

        String firstName = String.isNotBlank(portalUser.FirstName) ? portalUser.FirstName : '';
        String lastName = String.isNotBlank(portalUser.LastName) ? portalUser.LastName : '';
        Set<String> candidateEmails = collectCandidateEmails(portalUser);
        String email = String.isNotBlank(portalUser.Email)
            ? portalUser.Email
            : (candidateEmails.isEmpty() ? '' : candidateEmails.iterator().next());
        String phone = '';

        if (candidateContactId != null) {
            List<Contact> contacts = [
                SELECT Id, FirstName, LastName, Email, Phone
                FROM Contact
                WHERE Id = :candidateContactId
                LIMIT 1
            ];
            if (!contacts.isEmpty()) {
                Contact contactRecord = contacts[0];

                if (String.isNotBlank(contactRecord.FirstName)) {
                    firstName = contactRecord.FirstName;
                }
                if (String.isNotBlank(contactRecord.LastName)) {
                    lastName = contactRecord.LastName;
                }
                if (String.isNotBlank(contactRecord.Email)) {
                    email = contactRecord.Email;
                }
                phone = String.isNotBlank(contactRecord.Phone) ? contactRecord.Phone : '';
            }
        }

        if (String.isBlank(firstName) && String.isBlank(lastName) && String.isNotBlank(portalUser.Name)) {
            List<String> nameParts = portalUser.Name.trim().split(' ');
            if (!nameParts.isEmpty()) {
                firstName = nameParts[0];
                if (nameParts.size() > 1) {
                    List<String> lastNameParts = new List<String>();
                    for (Integer i = 1; i < nameParts.size(); i++) {
                        lastNameParts.add(nameParts[i]);
                    }
                    lastName = String.join(lastNameParts, ' ');
                }
            }
        }

        Set<Id> opportunityIds = getCandidateOpportunityIds(candidateContactId, candidateEmails);

        Integer matchingScore = 0;
        String latestStage = '';
        if (!opportunityIds.isEmpty()) {
            List<Opportunity> latestOppList = [
                SELECT Id, StageName, AI_Match_Score__c, CreatedDate
                FROM Opportunity
                WHERE Id IN :opportunityIds
                ORDER BY CreatedDate DESC
                LIMIT 1
            ];
            if (!latestOppList.isEmpty()) {
                Opportunity latestOpp = latestOppList[0];
                matchingScore = latestOpp.AI_Match_Score__c != null ? Integer.valueOf(latestOpp.AI_Match_Score__c) : 0;
                latestStage = latestOpp.StageName;
            }
        }

        Map<String, Object> cvInfo = getLatestCvInfo(candidateContactId, portalUser.Id, candidateEmails);
        String cvFileName = (String) cvInfo.get('cvFileName');
        String cvDocumentId = (String) cvInfo.get('cvDocumentId');

        Integer completionTotal = 5;
        Integer completionFilled = 0;
        if (String.isNotBlank(firstName)) completionFilled++;
        if (String.isNotBlank(lastName)) completionFilled++;
        if (String.isNotBlank(email)) completionFilled++;
        if (String.isNotBlank(phone)) completionFilled++;
        if (String.isNotBlank(cvFileName)) completionFilled++;
        Integer profileCompletion = (completionFilled * 100) / completionTotal;

        String fullName = (firstName + ' ' + lastName).trim();
        return new Map<String, Object>{
            'firstName' => firstName,
            'lastName' => lastName,
            'fullName' => String.isNotBlank(fullName) ? fullName : portalUser.Name,
            'email' => email,
            'phone' => phone,
            'contactId' => candidateContactId,
            'matchingScore' => matchingScore,
            'latestStage' => latestStage,
            'profileCompletion' => profileCompletion,
            'cvFileName' => cvFileName,
            'cvDocumentId' => cvDocumentId
        };
    }

    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getPortalNews() {
        List<Map<String, Object>> newsItems = new List<Map<String, Object>>{
            new Map<String, Object>{
                'id' => 'company-1',
                'category' => 'Company News',
                'title' => 'TalentBridge opens a new engineering hub in Tunis',
                'date' => formatDate(Date.today().addDays(-2)),
                'summary' => 'New offices and hiring plans to support regional growth.'
            },
            new Map<String, Object>{
                'id' => 'company-2',
                'category' => 'Company News',
                'title' => 'Interview process updated with clearer candidate feedback',
                'date' => formatDate(Date.today().addDays(-7)),
                'summary' => 'Candidates now receive more structured feedback after each stage.'
            }
        };

        for (Job__c job : [
            SELECT Id, Name, Job_Title__c, Department__c, Location__c, CreatedDate
            FROM Job__c
            WHERE Status__c IN ('Open', 'Active')
            ORDER BY CreatedDate DESC
            LIMIT 8
        ]) {
            String title = String.isNotBlank(job.Job_Title__c) ? job.Job_Title__c : job.Name;
            newsItems.add(new Map<String, Object>{
                'id' => 'job-' + String.valueOf(job.Id),
                'category' => 'Job Offers',
                'title' => title,
                'date' => formatDate(job.CreatedDate.date()),
                'summary' => joinMeta(job.Department__c, job.Location__c)
            });
        }

        return newsItems;
    }

    @AuraEnabled
    public static Map<String, Object> getAssistantResponse(String message) {
        String userMessage = String.isNotBlank(message) ? message.trim() : '';
        if (String.isBlank(userMessage)) {
            throw new AuraHandledException('Please enter a message for the assistant.');
        }

        String responseText = buildAssistantFallbackReply(userMessage);
        String source = 'fallback';

        try {
            User portalUser = getCurrentPortalUser();
            Id candidateContactId = resolveCandidateContactId(portalUser);
            Set<String> candidateEmails = collectCandidateEmails(portalUser);
            Set<Id> opportunityIds = portalUser != null
                ? getCandidateOpportunityIds(candidateContactId, candidateEmails)
                : new Set<Id>();

            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            inputParams.put('Input:message', toWrappedValue(userMessage));
            inputParams.put('Input:userName', toWrappedValue(portalUser != null ? portalUser.Name : 'Candidate'));
            inputParams.put('Input:applicationsCount', toWrappedValue(String.valueOf(opportunityIds.size())));
            inputParams.put('Input:validationChecklist', toWrappedValue(ASSISTANT_VALIDATION_CHECKLIST));

            ConnectApi.EinsteinPromptTemplateGenerationsInput genInput =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            genInput.inputParams = inputParams;
            genInput.isPreview = false;
            genInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            genInput.additionalConfig.applicationName = ASSISTANT_APP_NAME;

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    ASSISTANT_PROMPT_TEMPLATE_API_NAME,
                    genInput
                );

            String aiText = extractEinsteinAssistantText(response);
            if (String.isNotBlank(aiText)) {
                responseText = aiText;
                source = 'salesforce-ai';
            }
        } catch (Exception e) {
            source = 'fallback';
        }

        return new Map<String, Object>{
            'text' => responseText,
            'source' => source,
            'validationChecklist' => ASSISTANT_VALIDATION_CHECKLIST
        };
    }

    private static User getCurrentPortalUser() {
        try {
            return [
                SELECT Id, Name, FirstName, LastName, Email, ContactId
                FROM User
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
        } catch (Exception e) {
            return null;
        }
    }

    private static Set<Id> getCandidateOpportunityIds(Id contactId, Set<String> candidateEmails) {
        Set<Id> ids = new Set<Id>();

        if (contactId != null) {
            for (Opportunity opp : [
                SELECT Id
                FROM Opportunity
                WHERE Candidate_Contact__c = :contactId
                LIMIT 500
            ]) {
                ids.add(opp.Id);
            }

            for (OpportunityContactRole role : [
                SELECT OpportunityId
                FROM OpportunityContactRole
                WHERE ContactId = :contactId
                LIMIT 500
            ]) {
                ids.add(role.OpportunityId);
            }
        }

        if (candidateEmails != null && !candidateEmails.isEmpty()) {
            for (Lead convertedLead : [
                SELECT ConvertedOpportunityId
                FROM Lead
                WHERE Email IN :candidateEmails
                    AND IsConverted = true
                    AND ConvertedOpportunityId != null
                LIMIT 500
            ]) {
                ids.add(convertedLead.ConvertedOpportunityId);
            }
        }

        return ids;
    }

    private static List<Map<String, Object>> buildInterviewMessages(Id contactId, Set<Id> opportunityIds) {
        List<Map<String, Object>> result = new List<Map<String, Object>>();
        if (contactId == null && (opportunityIds == null || opportunityIds.isEmpty())) {
            return result;
        }

        Map<String, Schema.SObjectField> fields = Schema.SObjectType.Interview__c.fields.getMap();
        String contactField = null;
        if (fields.containsKey('Candidate_Contact__c')) {
            contactField = 'Candidate_Contact__c';
        } else if (fields.containsKey('Contact__c')) {
            contactField = 'Contact__c';
        }

        String opportunityField = fields.containsKey('Opportunity__c') ? 'Opportunity__c' : null;
        if (contactField == null && opportunityField == null) {
            return result;
        }

        DateTime nowDt = System.now();
        DateTime rangeEnd = nowDt.addDays(30);
        String soql = 'SELECT Id, Interview_Round__c, Interview_Date_Time__c, Interview_Status__c';
        if (contactField != null) {
            soql += ', ' + contactField;
        }
        if (opportunityField != null) {
            soql += ', ' + opportunityField;
        }
        soql += ' FROM Interview__c'
            + ' WHERE Interview_Status__c = \'Scheduled\''
            + ' AND Interview_Date_Time__c >= :nowDt'
            + ' AND Interview_Date_Time__c <= :rangeEnd'
            + ' ORDER BY Interview_Date_Time__c ASC'
            + ' LIMIT 200';

        for (SObject record : Database.query(soql)) {
            Boolean belongsToCandidate = false;
            if (contactField != null) {
                Id linkedContact = (Id) record.get(contactField);
                if (contactId != null && linkedContact == contactId) {
                    belongsToCandidate = true;
                }
            }

            if (!belongsToCandidate && opportunityField != null && !opportunityIds.isEmpty()) {
                Id linkedOpportunity = (Id) record.get(opportunityField);
                if (linkedOpportunity != null && opportunityIds.contains(linkedOpportunity)) {
                    belongsToCandidate = true;
                }
            }

            if (!belongsToCandidate) {
                continue;
            }

            DateTime interviewDate = (DateTime) record.get('Interview_Date_Time__c');
            if (interviewDate == null) {
                continue;
            }

            Long msToInterview = interviewDate.getTime() - nowDt.getTime();
            Integer minsToInterview = Integer.valueOf(msToInterview / 60000);
            String roundName = String.valueOf(record.get('Interview_Round__c'));
            if (String.isBlank(roundName)) {
                roundName = 'Interview';
            }

            Boolean isReminder = minsToInterview >= 0 && minsToInterview <= 120;
            String whenLabel = interviewDate.format('dd MMM yyyy HH:mm');
            String subject = isReminder
                ? 'Reminder: interview in less than 2 hours'
                : 'Interview scheduled - ' + roundName;
            String preview = isReminder
                ? (roundName + ' starts at ' + whenLabel)
                : ('Your ' + roundName + ' interview is scheduled on ' + whenLabel);

            result.add(new Map<String, Object>{
                'id' => String.valueOf(record.get('Id')),
                'from' => 'TalentBridge Team',
                'subject' => subject,
                'preview' => preview,
                'time' => whenLabel,
                'unread' => true,
                'category' => 'interview',
                'body' => '<p><b>' + roundName + '</b> interview is scheduled at <b>' + whenLabel + '</b>.</p>'
                    + (isReminder ? '<p>Please join 10 minutes early.</p>' : '')
            });
        }

        return result;
    }

    private static Map<String, Object> getLatestCvInfo(Id contactId, Id userId, Set<String> candidateEmails) {
        Map<String, Object> info = new Map<String, Object>{
            'cvFileName' => '',
            'cvDocumentId' => ''
        };

        List<ContentDocumentLink> links = new List<ContentDocumentLink>();
        if (contactId != null) {
            links = [
                SELECT ContentDocumentId, ContentDocument.Title
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :contactId
                ORDER BY SystemModstamp DESC
                LIMIT 1
            ];
        }

        if (links.isEmpty() && userId != null) {
            links = [
                SELECT ContentDocumentId, ContentDocument.Title
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :userId
                ORDER BY SystemModstamp DESC
                LIMIT 1
            ];
        }

        if (links.isEmpty() && contactId != null) {
            List<Lead> convertedLeads = [
                SELECT Id
                FROM Lead
                WHERE ConvertedContactId = :contactId
                ORDER BY ConvertedDate DESC
                LIMIT 20
            ];

            if (!convertedLeads.isEmpty()) {
                Set<Id> leadIds = new Set<Id>();
                for (Lead leadRecord : convertedLeads) {
                    leadIds.add(leadRecord.Id);
                }

                links = [
                    SELECT ContentDocumentId, ContentDocument.Title
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId IN :leadIds
                    ORDER BY SystemModstamp DESC
                    LIMIT 1
                ];
            }
        }

        if (links.isEmpty() && candidateEmails != null && !candidateEmails.isEmpty()) {
            List<Lead> candidateLeads = [
                SELECT Id
                FROM Lead
                WHERE Email IN :candidateEmails
                ORDER BY CreatedDate DESC
                LIMIT 20
            ];

            if (!candidateLeads.isEmpty()) {
                Set<Id> leadIds = new Set<Id>();
                for (Lead leadRecord : candidateLeads) {
                    leadIds.add(leadRecord.Id);
                }

                links = [
                    SELECT ContentDocumentId, ContentDocument.Title
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId IN :leadIds
                    ORDER BY SystemModstamp DESC
                    LIMIT 1
                ];
            }
        }

        if (!links.isEmpty()) {
            info.put('cvFileName', links[0].ContentDocument != null ? links[0].ContentDocument.Title : 'CV');
            info.put('cvDocumentId', String.valueOf(links[0].ContentDocumentId));
        }

        return info;
    }

    private static Id resolveCandidateContactId(User portalUser) {
        if (portalUser == null) {
            return null;
        }

        if (portalUser.ContactId != null) {
            return portalUser.ContactId;
        }

        Set<String> candidateEmails = collectCandidateEmails(portalUser);
        if (candidateEmails.isEmpty()) {
            return null;
        }

        try {
            List<Contact> contacts = [
                SELECT Id
                FROM Contact
                WHERE Email IN :candidateEmails
                ORDER BY LastModifiedDate DESC
                LIMIT 1
            ];
            return contacts.isEmpty() ? null : contacts[0].Id;
        } catch (Exception e) {
            return null;
        }
    }

    private static Set<String> collectCandidateEmails(User portalUser) {
        Set<String> emails = new Set<String>();
        if (portalUser == null) {
            return emails;
        }

        if (String.isNotBlank(portalUser.Email)) {
            emails.add(portalUser.Email.trim().toLowerCase());
        }

        if (String.isNotBlank(portalUser.Username) && portalUser.Username.contains('@')) {
            emails.add(portalUser.Username.trim().toLowerCase());
        }

        return emails;
    }

    private static Integer resolveStageStep(String stageName) {
        List<String> order = new List<String>{
            'Application Received',
            'CV Review',
            'Coding Test',
            'HR Interview',
            'Technical Interview',
            'Final Interview',
            'Offer Extended',
            'Offer Accepted'
        };

        Integer idx = order.indexOf(stageName);
        if (idx < 0) {
            return 0;
        }
        return idx;
    }

    private static String resolveBadgeClass(String stageName) {
        if (stageName == 'Coding Test') return 'pip-badge b-cod';
        if (stageName == 'CV Review' || stageName == 'Application Received') return 'pip-badge b-cv';
        if (stageName == 'HR Interview') return 'pip-badge b-rh';
        if (stageName == 'Technical Interview') return 'pip-badge b-tech';
        if (stageName == 'Final Interview') return 'pip-badge b-final';
        if (stageName == 'Offer Extended' || stageName == 'Offer Accepted') return 'pip-badge b-offer';
        return 'pip-badge';
    }

    private static String extractInitials(String title) {
        if (String.isBlank(title)) {
            return 'J';
        }
        return title.substring(0, 1).toUpperCase();
    }

    private static String joinMeta(String leftValue, String rightValue) {
        List<String> values = new List<String>();
        if (String.isNotBlank(leftValue)) {
            values.add(leftValue);
        }
        if (String.isNotBlank(rightValue)) {
            values.add(rightValue);
        }
        return String.join(values, ' · ');
    }

    private static String formatDate(Date value) {
        if (value == null) {
            return '';
        }

        DateTime asDateTime = DateTime.newInstance(value, Time.newInstance(0, 0, 0, 0));
        return asDateTime.format('MMM d, yyyy');
    }

    private static String buildAssistantFallbackReply(String message) {
        String normalized = message != null ? message.toLowerCase() : '';

        if (normalized.contains('next step') || normalized.contains('stage')) {
            return 'Open the Applications tab to view your exact stage per opportunity. Interview and stage updates are also available in Messages.';
        }
        if (normalized.contains('profile') || normalized.contains('completion')) {
            return 'Complete First Name, Last Name, Email, Phone, and upload your latest CV in Profile to improve completion.';
        }
        if (normalized.contains('interview') || normalized.contains('reminder')) {
            return 'Interview notifications are generated from scheduled interviews, and reminders appear automatically when the interview is within 2 hours.';
        }
        if (normalized.contains('validate') || normalized.contains('experience cloud')) {
            return ASSISTANT_VALIDATION_CHECKLIST;
        }
        return 'I can help with applications, interview notifications, profile updates, CV upload, and portal navigation.';
    }

    private static ConnectApi.WrappedValue toWrappedValue(Object rawValue) {
        ConnectApi.WrappedValue wrapped = new ConnectApi.WrappedValue();
        wrapped.value = rawValue;
        return wrapped;
    }

    private static String extractEinsteinAssistantText(ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response) {
        if (response == null || response.generations == null || response.generations.isEmpty()) {
            return '';
        }
        String text = response.generations[0].text;
        if (String.isBlank(text)) {
            return '';
        }
        return text.trim();
    }
}
