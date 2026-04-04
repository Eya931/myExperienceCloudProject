import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

// Apex
import generateJobDescription from '@salesforce/apex/HRJobController.generateJobDescription';
import saveJobOffer           from '@salesforce/apex/HRJobController.saveJobOffer';

const DEPT_ICONS = {
    'Engineering':      '⚙️',
    'Product':          '📋',
    'Data':             '🧠',
    'Design':           '🎨',
    'Customer Success': '⭐',
    'Marketing':        '📣',
    'Sales':            '💰',
    '':                 '📌',
};

export default class HrCreateJob extends NavigationMixin(LightningElement) {

    @track currentStep = 1;
    @track isGenerating = false;
    @track isSaving = false;
    @track savedJobId = null;

    // Validation error flags
    @track titleError   = false;
    @track deptError    = false;
    @track skillsError  = false;
    @track emailError   = false;

    @track formData = {
        title:          '',
        department:     '',
        experienceLevel:'Senior',
        skills:         '',
        email:          '',
        salary:         '',
        location:       'Remote',
        employmentType: 'Full-time',
    };

    @track aiContent = {
        description:     '',
        responsibilities:'',
        requirements:    '',
    };

    // ── Step helpers ──────────────────────────────────────────────────────────
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }
    get isGenerated() { return !!this.aiContent.description; }

    get steps() {
        return [
            { id: 1, name: 'Basic Info',  label: this.currentStep > 1 ? '✓' : '1', cssClass: `step ${this.currentStep >= 1 ? 'step--done' : ''}` },
            { id: 2, name: 'AI Preview',  label: this.currentStep > 2 ? '✓' : '2', cssClass: `step ${this.currentStep >= 2 ? 'step--done' : ''} ${this.currentStep === 2 ? 'step--active' : ''}` },
            { id: 3, name: 'Published',   label: this.currentStep > 3 ? '✓' : '3', cssClass: `step ${this.currentStep >= 3 ? 'step--done' : ''} ${this.currentStep === 3 ? 'step--active' : ''}` },
        ];
    }

    // ── Computed preview ──────────────────────────────────────────────────────
    get previewTitle() { return this.formData.title || 'Job Title'; }
    get previewDept()  { return this.formData.department || 'Department'; }
    get deptIcon()     { return DEPT_ICONS[this.formData.department] || '📌'; }

    get skillTags() {
        if (!this.formData.skills) return [];
        return this.formData.skills
            .split(',')
            .map(s => s.trim())
            .filter(s => s.length > 0);
    }

    get hasSkillTags()   { return this.skillTags.length > 0; }

    // ── CSS class helpers (error state) ──────────────────────────────────────
    get titleClass()  { return `field__input${this.titleError  ? ' field__input--error' : ''}`; }
    get deptClass()   { return `field__select${this.deptError  ? ' field__select--error' : ''}`; }
    get skillsClass() { return `field__input${this.skillsError ? ' field__input--error' : ''}`; }
    get emailClass()  { return `field__input${this.emailError  ? ' field__input--error' : ''}`; }

    get generateBtnClass() {
        return `generate-btn ${(!this.formData.title || !this.formData.department) ? 'generate-btn--disabled' : ''}`;
    }

    // ── Field handlers ────────────────────────────────────────────────────────
    handleFieldChange(event) {
        const field = event.currentTarget.dataset.field;
        const value = event.target.value;
        this.formData = { ...this.formData, [field]: value };

        // Clear error on change
        if (field === 'title')      this.titleError  = false;
        if (field === 'department') this.deptError   = false;
        if (field === 'skills')     this.skillsError = false;
        if (field === 'email')      this.emailError  = false;
    }

    handleSkillsInput(event) {
        this.formData = { ...this.formData, skills: event.target.value };
    }

    handleAiContentChange(event) {
        const field = event.currentTarget.dataset.field;
        this.aiContent = { ...this.aiContent, [field]: event.target.value };
    }

    // ── Validation ────────────────────────────────────────────────────────────
    _validate() {
        let valid = true;
        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

        this.titleError   = !this.formData.title.trim();
        this.deptError    = !this.formData.department;
        this.skillsError  = !this.formData.skills.trim();
        this.emailError   = !emailRegex.test(this.formData.email);

        valid = !this.titleError && !this.deptError && !this.skillsError && !this.emailError;
        return valid;
    }

    // ── AI Generation ─────────────────────────────────────────────────────────
    async handleGenerate() {
        if (!this._validate()) {
            this._toast('Please fill in all required fields', 'error');
            return;
        }

        this.isGenerating = true;

        try {
            // Call Apex which calls Einstein Prompt Builder
            const result = await generateJobDescription({
                jobTitle:        this.formData.title,
                department:      this.formData.department,
                requiredSkills:  this.formData.skills,
                experienceLevel: this.formData.experienceLevel,
                location:        this.formData.location,
            });

            this.aiContent = {
                description:     result.description     || this._fallbackDescription(),
                responsibilities: result.responsibilities || this._fallbackResponsibilities(),
                requirements:    result.requirements    || this._fallbackRequirements(),
            };

            this.currentStep = 2;

        } catch (err) {
            console.error('AI generation error:', err);

            // Fallback: use template-based content if Einstein is not configured
            this.aiContent = {
                description:     this._fallbackDescription(),
                responsibilities: this._fallbackResponsibilities(),
                requirements:    this._fallbackRequirements(),
            };
            this.currentStep = 2;
            this._toast('AI generation used template mode. Review and edit as needed.', 'warning');

        } finally {
            this.isGenerating = false;
        }
    }

    handleRegenerate() {
        this.currentStep = 1;
        this.aiContent = { description: '', responsibilities: '', requirements: '' };
    }

    // ── Save / Publish ────────────────────────────────────────────────────────
    async handlePublish() {
        this.isSaving = true;

        try {
            const jobId = await saveJobOffer({
                title:              this.formData.title,
                department:         this.formData.department,
                location:           this.formData.location,
                employmentType:     this.formData.employmentType,
                experienceLevel:    this.formData.experienceLevel,
                salaryRange:        this.formData.salary,
                contactEmail:       this.formData.email,
                requiredSkills:     this.formData.skills,
                aiDescription:      this.aiContent.description,
                responsibilities:   this.aiContent.responsibilities,
                requirements:       this.aiContent.requirements,
                status:             'Active',
            });

            this.savedJobId = jobId;
            this.currentStep = 3;
            this._toast('Job offer published successfully!', 'success');

        } catch (err) {
            console.error('Save error:', err);
            this._toast('Error saving job offer: ' + (err.body?.message || err.message), 'error');
        } finally {
            this.isSaving = false;
        }
    }

    // ── Navigation ────────────────────────────────────────────────────────────
    handleBack() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Job__c', actionName: 'list' },
        });
    }

    handleBackToStep1() {
        this.currentStep = 1;
    }

    handleViewJob() {
        if (this.savedJobId) {
            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: { recordId: this.savedJobId, actionName: 'view' },
            });
        }
    }

    handleCreateAnother() {
        // Reset everything
        this.currentStep = 1;
        this.savedJobId  = null;
        this.formData    = { title: '', department: '', experienceLevel: 'Senior', skills: '', email: '', salary: '', location: 'Remote', employmentType: 'Full-time' };
        this.aiContent   = { description: '', responsibilities: '', requirements: '' };
    }

    // ── Toast helper ──────────────────────────────────────────────────────────
    _toast(message, variant = 'success') {
        this.dispatchEvent(new ShowToastEvent({ title: 'TalentIQ', message, variant }));
    }

    // ── Fallback content (when Einstein not configured) ───────────────────────
    _fallbackDescription() {
        return `We are seeking an exceptional ${this.formData.title} to join our ${this.formData.department} team. `
             + `In this ${this.formData.experienceLevel} role, you will leverage ${this.formData.skills} to drive significant impact. `
             + `You will collaborate with a world-class team in a fast-paced, innovative environment based in ${this.formData.location || 'our offices'}.`;
    }

    _fallbackResponsibilities() {
        return `• Lead technical strategy and architectural decisions for key ${this.formData.department} initiatives\n`
             + `• Collaborate cross-functionally with product, design, and engineering teams\n`
             + `• Drive best practices through code reviews, documentation, and mentorship\n`
             + `• Analyse requirements and translate them into scalable, elegant solutions\n`
             + `• Continuously improve team velocity and quality standards\n`
             + `• Report on progress and metrics to stakeholders`;
    }

    _fallbackRequirements() {
        const skills = this.formData.skills || 'relevant technologies';
        return `• ${this.formData.experienceLevel} experience with ${skills}\n`
             + `• Proven track record of delivering high-quality work at scale\n`
             + `• Strong problem-solving and communication skills\n`
             + `• Experience working in agile, collaborative environments\n`
             + `• Passion for innovation and continuous learning\n`
             + `• Bachelor's degree in a relevant field or equivalent experience`;
    }
}