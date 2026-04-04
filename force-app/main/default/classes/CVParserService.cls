    /**
     * CVParserService  (Queueable + Callouts)
     * Professional ATS-grade CV analysis powered by AI.
     *
     * Runs asynchronously after a Lead is created with a CV attachment.
     * 1. Extracts text from the attached CV.
     * 2. Performs ATS-style analysis using a generative AI model.
     *    The AI handles cross-language matching (e.g. French job + English CV).
     * 3. Rates the Lead: Hot (≥ 40 %), Warm (≥ 20 %), Cold (< 20 %).
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
            System.debug('>>> CVParserService INIT <<<');
            System.debug('AI_MODEL: ' + AI_MODEL);
            System.debug('AI_TIMEOUT: ' + AI_TIMEOUT);
            System.debug('FALLBACK_RATING: ' + FALLBACK_RATING);
            System.debug('FALLBACK_NOTE: ' + FALLBACK_REPORT_NOTE);
        }

        /* ═══════════════════════════════════════════════════════
        * Queueable entry point
        * ═══════════════════════════════════════════════════════ */

        public void execute(QueueableContext ctx) {
            System.debug(LoggingLevel.INFO, '=== START CVParserService ===');
            try {
                String cvText = extractCVText();

                if (String.isBlank(cvText)) {
                    System.debug(LoggingLevel.ERROR, '❌ CV EXTRACTION FAILED → fallback Cold');
                    Lead lead = [SELECT Id, Description FROM Lead WHERE Id = :leadId LIMIT 1];
                    lead.Rating = 'Cold';
                    lead.Description = '[ATS] Could not extract text from CV.\n'
                        + (lead.Description != null ? lead.Description : '');
                    update lead;
                    return;
                }

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

                Lead lead = [SELECT Id, Description, Rating, AI_Match_Score__c, Conversion_Triggered__c FROM Lead WHERE Id = :leadId LIMIT 1];

                String header = '=== ATS Analysis — ' + job.Job_Title__c + ' ===\n';
                lead.Description = header + analysisReport + '\n\n'
                    + (lead.Description != null ? lead.Description : '');
                
                if (aiSucceeded) {
                    lead.AI_Match_Score__c = matchScore;
                    lead.Rating = matchScore >= 40 ? 'Hot'
                                : matchScore >= 20 ? 'Warm'
                                : 'Cold';
                    lead.Status = 'Candidature - IA Parsing CV';
                    if (aiSucceeded && matchScore >= 40) {
                        lead.Conversion_Triggered__c = true;  // ← signal explicite pour le Flow
                    }
                } else {
                    lead.Rating = FALLBACK_RATING;
                    lead.AI_Match_Score__c = null;
                }

                update lead;

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR,
                    'CVParserService failed: ' + e.getMessage() + '\n' + e.getStackTraceString());
                try {
                    Lead lead = [SELECT Id, Description, AI_Match_Score__c FROM Lead WHERE Id = :leadId LIMIT 1];
                    lead.Rating = 'Cold';
                    lead.AI_Match_Score__c = null;
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
                'File: ' + cv.Title + ' (' + cv.FileExtension + ', ' + cv.ContentSize + ' bytes)');

            String ext = cv.FileExtension?.toLowerCase();

            // TXT → lecture directe, pas besoin du service externe
            if (ext == 'txt' || ext == 'csv') {
                return cv.VersionData.toString();
            }

            // PDF / DOCX → microservice externe
            if (ext == 'pdf' || ext == 'docx' || ext == 'doc') {
                String extracted = extractTextViaExternalService(cv.VersionData, cv.Title + '.' + ext);
                if (String.isNotBlank(extracted)) return extracted;
            }

            // Dernier recours : titre du fichier uniquement
            return cv.Title != null ? cv.Title : '';
        }

        /**
         * Appelle le microservice Python pour extraire le texte du PDF/DOCX.
         */
        private String extractTextViaExternalService(Blob fileBlob, String fileName) {
            try {

                String base64File = EncodingUtil.base64Encode(fileBlob);

                HttpRequest req = new HttpRequest();
                req.setEndpoint('https://cv-extractor.onrender.com/extract');
                req.setMethod('POST');
                req.setHeader('Content-Type', 'application/json');
                req.setTimeout(120000); // ✅ 120s — couvre cold start (30s) + extraction

                // Sérialisation propre via Map pour éviter les problèmes d'échappement
                Map<String, Object> payload = new Map<String, Object>{
                    'base64'   => base64File,
                    'filename' => fileName
                };
                req.setBody(JSON.serialize(payload));

                HttpResponse res = new Http().send(req);

                System.debug(LoggingLevel.INFO, 'Extractor status: ' + res.getStatusCode());
                System.debug(LoggingLevel.INFO, 'Extractor body: ' + res.getBody().left(300));

                if (res.getStatusCode() == 200) {
                    Map<String, Object> result =
                        (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                    String extracted = (String) result.get('text');

                    if (String.isNotBlank(extracted) && extracted.length() > 50) {
                        System.debug(LoggingLevel.INFO, 'Extraction OK: ' + extracted.length() + ' chars');
                        return extracted;
                    }
                }

                System.debug(LoggingLevel.ERROR, 'Extractor returned error: ' + res.getBody());
                return null;

            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'extractTextViaExternalService failed: ' + e.getMessage());
                return null;
            }
        }
        

        /* ═══════════════════════════════════════════════════════
        * AI-Powered ATS Analysis
        * ═══════════════════════════════════════════════════════ */

        private Map<String, Object> performATSAnalysis(String cvText, Job__c job) {
            System.debug(LoggingLevel.INFO, '=== ENTER performATSAnalysis ===');
            try {
                String prompt     = buildATSPrompt(cvText, job);
                System.debug(LoggingLevel.INFO, 'Prompt length: ' + prompt.length());
                String aiResponse = callAI(prompt, 1200);

                System.debug(LoggingLevel.INFO, '=== AI RESPONSE RECEIVED ===');
                System.debug(LoggingLevel.INFO, 'AI RESPONSE NULL ? ' + (aiResponse == null));
                System.debug(LoggingLevel.INFO, 'AI RESPONSE LENGTH: ' + (aiResponse != null ? aiResponse.length() : 0));

                if (String.isBlank(aiResponse)) {
                    System.debug(LoggingLevel.ERROR, '❌ AI RESPONSE EMPTY → fallback');
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
            System.debug(LoggingLevel.INFO, '=== CALL AI START ===');

            API_Configuration__c config = API_Configuration__c.getInstance();
            System.debug(LoggingLevel.INFO, 'API CONFIG NULL ? ' + (config == null));
            System.debug(LoggingLevel.INFO, 'API KEY PRESENT ? ' + (config != null && !String.isBlank(config.api_groq__c)));

            if (config == null || String.isBlank(config.api_groq__c)) {
                System.debug(LoggingLevel.ERROR, '❌ API key not found in Custom Setting → fallback');
                return null;
            }
            
            HttpRequest req = new HttpRequest();
            req.setEndpoint('https://api.groq.com/openai/v1/chat/completions');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setHeader('Authorization', 'Bearer ' + config.api_groq__c);
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

            System.debug('>>> GROQ CALL START <<<');
            System.debug(LoggingLevel.INFO, '=== HTTP REQUEST ===');
            System.debug(LoggingLevel.INFO, 'Endpoint: ' + req.getEndpoint());
            System.debug(LoggingLevel.INFO, 'Body size: ' + req.getBody().length());    

            HttpResponse res = new Http().send(req);

            System.debug('>>> GROQ RESPONSE <<<');
            System.debug(LoggingLevel.INFO, 'Status: ' + res.getStatusCode());
            System.debug(LoggingLevel.INFO, 'StatusText: ' + res.getStatus());
            System.debug(LoggingLevel.INFO, 'Body: ' + res.getBody());

            if (res.getStatusCode() != 200) {
                System.debug(LoggingLevel.ERROR, '❌ ERROR CALLING GROQ');
                System.debug(LoggingLevel.ERROR, 'Response: ' + res.getBody());
            }

            if (res.getStatusCode() == 200) {
                Map<String, Object> resMap =
                    (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
                List<Object> choices = (List<Object>) resMap.get('choices');

                System.debug(LoggingLevel.INFO, 'Choices NULL ? ' + (choices == null));
                System.debug(LoggingLevel.INFO, 'Choices size: ' + (choices != null ? choices.size() : 0));

                if (choices != null && !choices.isEmpty()) {
                    Map<String, Object> first = (Map<String, Object>) choices[0];
                    Map<String, Object> msg   = (Map<String, Object>) first.get('message');
                    String content = (String) msg.get('content');

                    System.debug(LoggingLevel.INFO, 'AI CONTENT LENGTH: ' + (content != null ? content.length() : 0));
                    System.debug(LoggingLevel.INFO, 'AI CONTENT PREVIEW: ' + (content != null ? content.left(300) : 'NULL'));

                    return content;
                }
            }

            System.debug(LoggingLevel.ERROR,'❌ AI CALL FAILED → fallback. Status: ' + res.getStatusCode());
            return null;
        }

        /* ═══════════════════════════════════════════════════════
        * ATS Response Parser
        * ═══════════════════════════════════════════════════════ */

        private Map<String, Object> parseATSResponse(String aiResponse) {
            System.debug(LoggingLevel.INFO, '=== PARSE START ===');
            System.debug(LoggingLevel.INFO, 'RAW AI RESPONSE: ' + aiResponse);

            String cleaned = aiResponse.trim();

            if (cleaned.startsWith('```')) {
                Integer firstNewline = cleaned.indexOf('\n');
                if (firstNewline != -1) {
                    cleaned = cleaned.substring(firstNewline + 1);
                }

                if (cleaned.endsWith('```')) {
                    cleaned = cleaned.substring(0, cleaned.lastIndexOf('```'));
                }
            }

            cleaned = cleaned.trim();
            System.debug(LoggingLevel.INFO, 'CLEANED JSON: ' + cleaned);

            Map<String, Object> parsed;
            try {
                parsed = (Map<String, Object>) JSON.deserializeUntyped(cleaned);
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'JSON parse failed: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Cleaned string was: ' + cleaned);
                return null; // ← sera géré proprement par l'appelant
            }

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