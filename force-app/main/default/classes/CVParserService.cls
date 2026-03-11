/**
 * CVParserService  (Queueable + Callouts)
 * Professional ATS-grade CV analysis powered by AI.
 *
 * Runs asynchronously after a Lead is created with a CV attachment.
 * 1. Extracts text from the attached CV.
 * 2. Performs ATS-style analysis using a generative AI model.
 *    The AI handles cross-language matching (e.g. French job + English CV).
 * 3. Rates the Lead: Hot (≥ 70 %), Warm (≥ 40 %), Cold (< 40 %).
 * 4. Stores a detailed ATS report in the Lead Description.
 * 5. Auto-converts Hot leads via LeadConversionService.
 */
public without sharing class CVParserService implements Queueable, Database.AllowsCallouts {

    private static final String  AI_MODEL   = 'llama-3.3-70b-versatile';
    private static final Integer AI_TIMEOUT = 60000;

    private static final String FALLBACK_RATING      = 'Warm';
    private static final String FALLBACK_REPORT_NOTE =
        '[NOTE] AI service was unavailable. This lead has been rated Warm pending manual review.\n'
      + 'Cross-language matching (French job / English CV) requires AI — keyword fallback is not reliable.\n';

    private Id leadId;
    private Id jobId;

    public CVParserService(Id leadId, Id jobId) {
        this.leadId = leadId;
        this.jobId  = jobId;
    }

    /* ═══════════════════════════════════════════════════════
     * Queueable entry point
     * ═══════════════════════════════════════════════════════ */

    public void execute(QueueableContext ctx) {
        try {
            String cvText = extractCVText();

            if (String.isBlank(cvText)) {
                Lead lead = [SELECT Id, Description FROM Lead WHERE Id = :leadId LIMIT 1];
                lead.Rating = 'Cold';
                lead.Description = '[ATS] Could not extract text from CV.\n'
                    + (lead.Description != null ? lead.Description : '');
                update lead;
                return;
            }

            System.debug(LoggingLevel.INFO, 'CV text extracted, length: ' + cvText.length());
            System.debug(LoggingLevel.INFO, 'CV preview: ' + cvText.left(300));

            Job__c job = [
                SELECT Required_Skills__c, Department__c, Job_Title__c, Job_Description__c
                FROM Job__c
                WHERE Id = :jobId
                LIMIT 1
            ];

            Integer matchScore;
            String  analysisReport;
            Boolean aiSucceeded = false;

            Map<String, Object> atsResult = performATSAnalysis(cvText, job);

            if (atsResult != null) {
                matchScore     = (Integer) atsResult.get('score');
                analysisReport = (String)  atsResult.get('report');
                aiSucceeded    = true;
            } else {
                matchScore     = null;
                analysisReport = FALLBACK_REPORT_NOTE + buildDiagnosticInfo(cvText, job);
            }

            Lead lead = [SELECT Id, Description, Rating FROM Lead WHERE Id = :leadId LIMIT 1];

            if (aiSucceeded) {
                lead.Rating = matchScore >= 30 ? 'Hot'
                            : matchScore >= 10 ? 'Warm'
                            : 'Cold';
            } else {
                lead.Rating = FALLBACK_RATING;
            }

            String header = '=== ATS Analysis — ' + job.Job_Title__c + ' ===\n';
            lead.Description = header + analysisReport + '\n\n'
                + (lead.Description != null ? lead.Description : '');
            update lead;

            if (aiSucceeded && matchScore >= 30) {
                LeadConversionService.convertLead(leadId, jobId);
            }

        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'CVParserService failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            try {
                Lead lead = [SELECT Id, Description FROM Lead WHERE Id = :leadId LIMIT 1];
                lead.Rating = 'Cold';
                lead.Description = '[ATS Error] ' + e.getMessage() + '\n'
                    + (lead.Description != null ? lead.Description : '');
                update lead;
            } catch (Exception ex) {
                System.debug(LoggingLevel.ERROR, 'Could not update Lead: ' + ex.getMessage());
            }
        }
    }

    /* ═══════════════════════════════════════════════════════
     * CV Text Extraction
     * ═══════════════════════════════════════════════════════ */

    private String extractCVText() {
        List<ContentDocumentLink> cdls = [
            SELECT ContentDocumentId
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :leadId
            LIMIT 1
        ];
        if (cdls.isEmpty()) {
            System.debug(LoggingLevel.WARN, 'No file attached to Lead: ' + leadId);
            return null;
        }

        ContentVersion cv = [
            SELECT VersionData, FileExtension, Title, ContentSize
            FROM ContentVersion
            WHERE ContentDocumentId = :cdls[0].ContentDocumentId
              AND IsLatest = true
            LIMIT 1
        ];

        System.debug(LoggingLevel.INFO,
            'Processing file: ' + cv.Title + ' (' + cv.FileExtension + ', ' + cv.ContentSize + ' bytes)');

        String ext = cv.FileExtension?.toLowerCase();

        // Plain text — read directly
        if (ext == 'txt' || ext == 'csv') {
            return cv.VersionData.toString();
        }

        // PDF/DOCX — extract readable text layer directly (no AI base64)
        if (ext == 'pdf' || ext == 'docx' || ext == 'doc') {
            try {
                String rawText  = cv.VersionData.toString();
                String cleaned  = extractReadableText(rawText);
                if (String.isNotBlank(cleaned) && cleaned.length() > 100) {
                    System.debug(LoggingLevel.INFO,
                        'PDF text-layer extraction successful, length: ' + cleaned.length());
                    return cleaned;
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'Direct PDF read failed: ' + e.getMessage());
            }
        }

        return cv.Title != null ? cv.Title : '';
    }

    /**
     * Extracts readable ASCII text from raw PDF binary content.
     * Strips binary noise, keeps real words.
     */
    private String extractReadableText(String raw) {
        if (String.isBlank(raw)) return '';

        String cleaned = raw.replaceAll('[^\\x20-\\x7E\\n\\r\\t]', ' ');
        cleaned = cleaned.replaceAll('\\s+', ' ');

        List<String> words = new List<String>();
        for (String token : cleaned.split(' ')) {
            if (token.length() >= 3 && token.replaceAll('[^a-zA-Z0-9]', '').length() >= 2) {
                words.add(token);
            }
        }

        if (words.size() >= 50) {
            return String.join(words, ' ').trim();
        }
        return '';
    }

    /* ═══════════════════════════════════════════════════════
     * AI-Powered ATS Analysis
     * ═══════════════════════════════════════════════════════ */

    private Map<String, Object> performATSAnalysis(String cvText, Job__c job) {
        try {
            String prompt     = buildATSPrompt(cvText, job);
            String aiResponse = callAI(prompt, 1200);

            if (String.isBlank(aiResponse)) {
                System.debug(LoggingLevel.WARN, 'AI returned blank response.');
                return null;
            }
            return parseATSResponse(aiResponse);
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR,
                'AI ATS analysis failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
            return null;
        }
    }

    /**
     * STRICT ATS prompt with explicit anti-hallucination rules.
     *
     * The previous prompt was too permissive — the AI was inventing
     * experience ("8 years in sales") that didn't exist in the CV,
     * causing student CVs to score 80% for Senior roles.
     *
     * Key additions:
     * - NEVER invent or assume experience not explicitly written
     * - Penalise seniority gaps (student/intern vs Senior role)
     * - Score based ONLY on what is literally present in the CV text
     * - Internships count as partial experience, not full years
     */
    @TestVisible
    private String buildATSPrompt(String cvText, Job__c job) {
        return 'You are a strict, accurate ATS (Applicant Tracking System) used by professional recruiters.\n'
             + 'Your job is to evaluate the candidate CV against the job posting HONESTLY and PRECISELY.\n\n'

             + '=== CRITICAL ANTI-HALLUCINATION RULES ===\n'
             + '1. NEVER invent, assume, or infer experience not explicitly written in the CV.\n'
             + '2. NEVER guess years of experience — only count what is explicitly dated in the CV.\n'
             + '3. If the candidate is a student or recent graduate, their experience is LIMITED — score accordingly.\n'
             + '4. Internships (stage, intern) are NOT equivalent to full professional experience.\n'
             + '5. If the job requires SENIOR level (5+ years) and the CV shows internships only, the score MUST be below 40%.\n'
             + '6. Do NOT give benefit of the doubt — only score what is explicitly demonstrated.\n'
             + '7. Cross-language matching IS allowed (French CV vs English job), but ONLY for skills clearly present.\n\n'

             + '=== SCORING WEIGHTS ===\n'
             + '- Required skills match: 50% of score\n'
             + '- Years of relevant experience vs required seniority: 30% of score\n'
             + '- Education relevance: 20% of score\n\n'

             + '=== SENIORITY CALIBRATION ===\n'
             + 'If the job title contains "Senior", "Lead", "Principal", or "Director":\n'
             + '  - Candidate needs 5+ years of PROFESSIONAL (non-intern) experience to score above 60%\n'
             + '  - Students or candidates with only internships should score 15-35% MAX for Senior roles\n'
             + 'If the job is "Junior", "Intern", or "Entry Level":\n'
             + '  - Students and recent graduates can score higher\n\n'

             + '--- JOB POSTING ---\n'
             + 'Title: '           + job.Job_Title__c + '\n'
             + 'Department: '      + (job.Department__c      != null ? job.Department__c      : 'N/A') + '\n'
             + 'Required Skills: ' + (job.Required_Skills__c != null ? job.Required_Skills__c : 'N/A') + '\n'
             + 'Job Description: ' + (job.Job_Description__c != null
                                        ? job.Job_Description__c.left(2000)
                                        : 'N/A') + '\n\n'

             + '--- CANDIDATE CV ---\n'
             + cvText.left(4000) + '\n\n'

             + '--- EVALUATION STEPS ---\n'
             + 'Step 1: List every required skill from the job posting.\n'
             + 'Step 2: For each skill, check if it is EXPLICITLY present in the CV (cross-language OK).\n'
             + 'Step 3: Count actual professional years (exclude internships from seniority calculation).\n'
             + 'Step 4: Check if the candidate\'s level (student/junior/senior) matches the job\'s seniority.\n'
             + 'Step 5: Compute score using the weights above. Be strict and realistic.\n\n'

             + '--- OUTPUT FORMAT ---\n'
             + 'Respond ONLY with valid JSON. No markdown, no code fences, no extra text.\n'
             + '{\n'
             + '  "score": <integer 0-100>,\n'
             + '  "matched_skills": ["skill1", "skill2"],\n'
             + '  "missing_skills": ["skill3"],\n'
             + '  "experience_years": <number — ONLY count explicitly dated professional roles, 0 if student/intern only>,\n'
             + '  "seniority_match": "overqualified|good_fit|junior_for_role|student_for_senior_role",\n'
             + '  "education_match": "strong|moderate|weak|unknown",\n'
             + '  "summary": "<2-3 sentence HONEST assessment — state clearly if candidate is underqualified>"\n'
             + '}';
    }

    /* ═══════════════════════════════════════════════════════
     * AI HTTP Client
     * ═══════════════════════════════════════════════════════ */

    private String callAI(String prompt, Integer maxTokens) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:AI_Service/v1/chat/completions');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(AI_TIMEOUT);

        Map<String, Object> body = new Map<String, Object>{
            'model'      => AI_MODEL,
            'messages'   => new List<Object>{
                new Map<String, Object>{ 'role' => 'user', 'content' => prompt }
            },
            'max_tokens'  => maxTokens,
            'temperature' => 0.1
        };

        req.setBody(JSON.serialize(body));
        HttpResponse res = new Http().send(req);

        if (res.getStatusCode() == 200) {
            Map<String, Object> resMap =
                (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> choices = (List<Object>) resMap.get('choices');
            if (choices != null && !choices.isEmpty()) {
                Map<String, Object> first = (Map<String, Object>) choices[0];
                Map<String, Object> msg   = (Map<String, Object>) first.get('message');
                return (String) msg.get('content');
            }
        }

        System.debug(LoggingLevel.WARN,
            'AI_Service HTTP ' + res.getStatusCode() + ' — Body: ' + res.getBody());
        return null;
    }

    /* ═══════════════════════════════════════════════════════
     * ATS Response Parser
     * ═══════════════════════════════════════════════════════ */

    private Map<String, Object> parseATSResponse(String aiResponse) {
        String cleaned = aiResponse.trim();
        if (cleaned.startsWith('```')) {
            cleaned = cleaned.substringAfter('\n');
            if (cleaned.contains('```')) {
                cleaned = cleaned.substringBeforeLast('```');
            }
        }

        Map<String, Object> parsed =
            (Map<String, Object>) JSON.deserializeUntyped(cleaned.trim());

        Integer score = Integer.valueOf(String.valueOf(parsed.get('score')));
        score = Math.max(0, Math.min(100, score));

        String report = 'Overall Score: ' + score + '%\n';

        List<Object> matched = (List<Object>) parsed.get('matched_skills');
        if (matched != null && !matched.isEmpty()) {
            report += 'Matched Skills: ' + String.join(toStringList(matched), ', ') + '\n';
        }

        List<Object> missing = (List<Object>) parsed.get('missing_skills');
        if (missing != null && !missing.isEmpty()) {
            report += 'Missing Skills: ' + String.join(toStringList(missing), ', ') + '\n';
        }

        Object expYears = parsed.get('experience_years');
        if (expYears != null) {
            report += 'Experience: ~' + String.valueOf(expYears) + ' years\n';
        }

        // New field: seniority match
        String seniorityMatch = (String) parsed.get('seniority_match');
        if (String.isNotBlank(seniorityMatch)) {
            report += 'Seniority Match: ' + seniorityMatch + '\n';
        }

        String eduMatch = (String) parsed.get('education_match');
        if (String.isNotBlank(eduMatch)) {
            report += 'Education Fit: ' + eduMatch + '\n';
        }

        String summary = (String) parsed.get('summary');
        if (String.isNotBlank(summary)) {
            report += '\n' + summary;
        }

        return new Map<String, Object>{
            'score'  => score,
            'report' => report
        };
    }

    private List<String> toStringList(List<Object> items) {
        List<String> result = new List<String>();
        for (Object item : items) result.add(String.valueOf(item));
        return result;
    }

    /* ═══════════════════════════════════════════════════════
     * Fallback diagnostic info
     * ═══════════════════════════════════════════════════════ */

    private String buildDiagnosticInfo(String cvText, Job__c job) {
        List<String> requiredTerms = extractRequiredSkillTerms(job.Required_Skills__c);
        List<String> found   = new List<String>();
        List<String> missing = new List<String>();

        String normalizedCv = normalizeText(cvText);
        for (String term : requiredTerms) {
            if (normalizedCv.contains(normalizeText(term))) {
                found.add(term);
            } else {
                missing.add(term);
            }
        }

        String info = 'Job: ' + job.Job_Title__c + '\n';
        if (!found.isEmpty()) {
            info += 'Skills found in CV (exact match only): ' + String.join(found, ', ') + '\n';
        }
        if (!missing.isEmpty()) {
            info += 'Skills not found via exact match: ' + String.join(missing, ', ') + '\n';
        }
        info += '\n[Cross-language skills may still match — please review manually or fix AI_Service credential.]\n';
        return info;
    }

    private List<String> extractRequiredSkillTerms(String requiredSkills) {
        List<String> terms = new List<String>();
        if (String.isBlank(requiredSkills)) return terms;

        for (String raw : requiredSkills.split('[,;|\n\r]+')) {
            String c = raw.trim()
                .replaceAll('^[^A-Za-z0-9]+', '')
                .replaceAll('[^A-Za-z0-9+#./ -]+$', '')
                .trim();
            if (c.length() >= 2 && c.length() <= 40 && !isGenericToken(normalizeText(c))) {
                terms.add(c);
            }
        }
        return terms;
    }

    /* ═══════════════════════════════════════════════════════
     * Test-visible helpers
     * ═══════════════════════════════════════════════════════ */

    @TestVisible
    private Integer calculateMatchScore(String cvText, String requiredSkills) {
        List<String> keywords = extractRequiredSkillTerms(requiredSkills);
        if (keywords.isEmpty() || String.isBlank(cvText)) return 0;

        String normalizedCv = normalizeText(cvText);
        Integer matched = 0;
        for (String kw : keywords) {
            if (normalizedCv.contains(normalizeText(kw))) matched++;
        }
        return (matched * 100) / keywords.size();
    }

    /* ═══════════════════════════════════════════════════════
     * Text normalization
     * ═══════════════════════════════════════════════════════ */

    private Boolean isGenericToken(String token) {
        return new Set<String>{
            'and', 'the', 'for', 'with', 'from', 'into', 'our',
            'des', 'les', 'dans', 'avec', 'vous', 'une', 'sur',
            'par', 'aux', 'nos', 'notre', 'vos', 'leur', 'leurs',
            'que', 'qui', 'est', 'son', 'ses', 'cette', 'ces',
            'plus', 'tout', 'bien', 'lors', 'dont',
            'job', 'role', 'open', 'posted', 'contract',
            'stage', 'cdi', 'cdd', 'senior', 'junior',
            'poste', 'projet', 'projets', 'mission', 'missions'
        }.contains(token);
    }

    private String normalizeText(String value) {
        if (String.isBlank(value)) return '';

        String n = value.toLowerCase();
        n = n.replace('à','a').replace('á','a').replace('â','a').replace('ä','a').replace('ã','a').replace('å','a');
        n = n.replace('ç','c');
        n = n.replace('è','e').replace('é','e').replace('ê','e').replace('ë','e');
        n = n.replace('ì','i').replace('í','i').replace('î','i').replace('ï','i');
        n = n.replace('ñ','n');
        n = n.replace('ò','o').replace('ó','o').replace('ô','o').replace('ö','o').replace('õ','o');
        n = n.replace('ù','u').replace('ú','u').replace('û','u').replace('ü','u');
        n = n.replace('ý','y').replace('ÿ','y');
        n = n.replace('œ','oe').replace('æ','ae');
        n = n.replaceAll('[^a-z0-9+#./ -]+',' ');
        n = n.replaceAll('\\s+',' ').trim();
        return n;
    }
}