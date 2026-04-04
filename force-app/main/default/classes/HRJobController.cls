/**
 * HRJobController
 * Handles Job Offer creation and AI description generation via Einstein Prompt Builder.
 */
public without sharing class HRJobController {

    // ── Generate Job Description (Einstein Prompt Builder) ────────────────────
    /**
     * Calls Einstein Generative AI via Prompt Builder to auto-generate the
     * job description, responsibilities, and requirements.
     *
     * Prerequisites in Salesforce Setup:
     *  1. Setup → Einstein → Generative AI → Enable
     *  2. Setup → Einstein → Prompt Builder → New Prompt Template
     *     - Name: "Job Description Generator"
     *     - API Name: Job_Description_Generator
     *     - Inputs: jobTitle, department, requiredSkills, experienceLevel, location
     *     - Prompt body: (see template text below)
     *  3. Add the Prompt Template to this class's invocation
     */
    @AuraEnabled
    public static Map<String, String> generateJobDescription(
        String jobTitle,
        String department,
        String requiredSkills,
        String experienceLevel,
        String location
    ) {
        Map<String, String> result = new Map<String, String>();

        try {
            // Build the prompt input map for Einstein Prompt Builder
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();

            ConnectApi.WrappedValue titleVal = new ConnectApi.WrappedValue();
            titleVal.value = jobTitle;
            inputParams.put('Input:Job_Title', titleVal);

            ConnectApi.WrappedValue deptVal = new ConnectApi.WrappedValue();
            deptVal.value = department;
            inputParams.put('Input:department', deptVal);

            ConnectApi.WrappedValue skillsVal = new ConnectApi.WrappedValue();
            skillsVal.value = requiredSkills;
            inputParams.put('Input:requiredSkills', skillsVal);

            ConnectApi.WrappedValue levelVal = new ConnectApi.WrappedValue();
            levelVal.value = experienceLevel;
            inputParams.put('Input:experienceLevel', levelVal);

            ConnectApi.WrappedValue locVal = new ConnectApi.WrappedValue();
            locVal.value = location;
            inputParams.put('Input:location', locVal);

            // Execute the Prompt Template
            // Template API name must match what you created in Prompt Builder
            ConnectApi.EinsteinPromptTemplateGenerationsInput genInput =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();
            genInput.inputParams       = inputParams;
            genInput.isPreview         = false;
            genInput.additionalConfig  = new ConnectApi.EinsteinLlmAdditionalConfigInput();
            genInput.additionalConfig.applicationName = 'TalentIQ_JobDescGen';

            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation response =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Job_desc', // ← your Prompt Template API name
                    genInput
                );

            // The response is JSON with three keys: description, responsibilities, requirements
            // Your Prompt Template should instruct Einstein to return ONLY valid JSON in this format:
            // { "description": "...", "responsibilities": "• item\n• item", "requirements": "• item\n• item" }
            String rawText = response.generations[0].text;

            // Strip any markdown code fences if present
            rawText = rawText.replace('```json', '').replace('```', '').trim();

            Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(rawText);
            result.put('description',     (String) parsed.get('description'));
            result.put('responsibilities', (String) parsed.get('responsibilities'));
            result.put('requirements',    (String) parsed.get('requirements'));

        } catch (Exception e) {
            // Let the LWC JS fallback handle it
            throw new AuraHandledException('AI generation failed: ' + e.getMessage());
        }

        return result;
    }

    // ── Save Job Offer ────────────────────────────────────────────────────────
    /**
     * Creates a new Job__c record with all fields.
     * Returns the new record ID.
     */
    @AuraEnabled
    public static Id saveJobOffer(
        String title,
        String department,
        String location,
        String employmentType,
        String experienceLevel,
        String salaryRange,
        String contactEmail,
        String requiredSkills,
        String aiDescription,
        String responsibilities,
        String requirements,
        String status
    ) {
        try {
            Job__c job = new Job__c();
            job.Name                        = title;
            job.Department__c               = department;
            job.Location__c                 = location;
            job.Employment_Type__c          = employmentType;
            job.Experience_Level__c         = experienceLevel;
            job.Salary_Range__c             = salaryRange;
            job.Contact_Email__c            = contactEmail;
            job.Required_Skills__c          = requiredSkills;
            job.Job_Description__c = aiDescription;
            job.Responsibilities__c         = responsibilities;
            job.Requirements__c             = requirements;
            job.Status__c                   = status != null ? status : 'Active';
            job.Posted_Date__c              = Date.today();

            insert job;
            return job.Id;

        } catch (DmlException e) {
            throw new AuraHandledException('Error saving job: ' + e.getDmlMessage(0));
        }
    }

    // ── Get all active jobs (for Job Management list) ─────────────────────────
    @AuraEnabled(cacheable=true)
    public static List<Job__c> getAllJobs() {
        return [
            SELECT Id, Name, Department__c, Location__c, Status__c,
                   Employment_Type__c, Experience_Level__c, Salary_Range__c,
                   Posted_Date__c, Number_of_Applicants__c
            FROM Job__c
            ORDER BY Posted_Date__c DESC NULLS LAST
            LIMIT 50
        ];
    }

    // ── Toggle job active/inactive ────────────────────────────────────────────
    @AuraEnabled
    public static void toggleJobStatus(Id jobId, String newStatus) {
        Job__c job = new Job__c(Id = jobId, Status__c = newStatus);
        update job;
    }
}


/* ═══════════════════════════════════════════════════════════════════════════════
   EINSTEIN PROMPT TEMPLATE BODY (copy this into Prompt Builder)

   Go to: Setup → Einstein → Prompt Builder → New Prompt Template
   Name: Job Description Generator
   API Name: Job_Description_Generator
   Type: Completion (non-chat)

   Paste the following as the prompt body:
   ─────────────────────────────────────────────────────────────────────────────

   You are an expert HR copywriter creating professional job postings.
   Generate a job description for the following role.

   Job Title: {!$Input:jobTitle}
   Department: {!$Input:department}
   Required Skills: {!$Input:requiredSkills}
   Experience Level: {!$Input:experienceLevel}
   Location: {!$Input:location}

   Return ONLY a valid JSON object (no markdown, no explanation) with exactly these three keys:
   - "description": A 2-3 paragraph compelling job description (plain text, no bullets)
   - "responsibilities": 6 bullet points starting each line with "• "
   - "requirements": 5 bullet points starting each line with "• "

   Make the language professional, inspiring, and specific to the role.
   ═══════════════════════════════════════════════════════════════════════════════
*/