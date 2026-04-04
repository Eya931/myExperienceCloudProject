import { LightningElement, api, track } from 'lwc';

// Prompt Buffer for AI-generated descriptions
const PROMPT_BUFFER = {
    generateDescription: (jobTitle, department, skills, experienceLevel) => {
        const templates = {
            'Engineering': `Join our {department} team as a {experienceLevel} {jobTitle}. You'll work with cutting-edge technologies including {skills}. Collaborate with talented engineers to build scalable solutions that impact millions of users worldwide.`,
            'Product': `We're looking for a {jobTitle} to drive product strategy and innovation. With expertise in {skills}, you'll lead cross-functional teams and shape the future of our platform.`,
            'Data': `Looking for a {jobTitle} to unlock insights from data. You'll leverage {skills} to build ML models and data pipelines that power our decision-making.`,
            'Design': `Seeking a {jobTitle} to create beautiful user experiences. With skills in {skills}, you'll collaborate with product and engineering to design intuitive interfaces.`,
            'Sales': `We need a {jobTitle} to drive revenue growth. With expertise in {skills}, you'll build relationships and close deals with enterprise clients.`,
            'Marketing': `Join as a {jobTitle} to amplify our brand. You'll leverage {skills} to create campaigns that resonate with our target audience.`,
            'Customer Success': `Become a {jobTitle} and delight our customers. With knowledge of {skills}, you'll ensure client success and drive retention.`,
        };

        const template = templates[department] || templates['Engineering'];
        return template
            .replace('{jobTitle}', jobTitle)
            .replace('{department}', department)
            .replace('{skills}', skills || 'relevant technologies')
            .replace('{experienceLevel}', experienceLevel || 'experienced');
    },

    generateResponsibilities: (jobTitle, department) => {
        const baseResponsibilities = [
            `Drive the success of {department} initiatives and projects`,
            `Lead technical discussions and architectural decisions`,
            `Mentor and support your team members`,
            `Collaborates with cross-functional teams on product roadmap`,
            `Contribute to code reviews and maintain high quality standards`,
            `Document and share knowledge with the team`
        ];
        return baseResponsibilities.map(r => r.replace('{department}', department));
    },

    generateRequirements: (experienceLevel, skills) => {
        const baseRequirements = [
            `${experienceLevel} level experience with relevant technologies`,
            `Strong problem-solving and analytical skills`,
            `Excellent communication and collaboration abilities`,
            `Experience with ${skills || 'modern development practices'}`,
            `Passion for continuous learning and growth`,
            `Bachelor's degree in Computer Science or related field (or equivalent experience)`
        ];
        return baseRequirements;
    }
};

export default class JobModal extends LightningElement {
    @api job = null;
    @track isGenerating = false;
    @track isSaving = false;
    @track currentStep = 1;

    @track formData = {
        title: '',
        department: 'Engineering',
        experienceLevel: 'Senior',
        skills: '',
        location: 'Remote',
        jobType: 'Full-time',
        salary: '',
        email: '',
    };

    @track aiContent = {
        description: '',
        responsibilities: [],
        requirements: [],
    };

    @track errors = {};

    // Getters
    get isStep1() { return this.currentStep === 1; }
    get isStep2() { return this.currentStep === 2; }
    get isStep3() { return this.currentStep === 3; }

    get departmentOptions() {
        return [
            { label: 'Engineering', value: 'Engineering' },
            { label: 'Product', value: 'Product' },
            { label: 'Data', value: 'Data' },
            { label: 'Design', value: 'Design' },
            { label: 'Sales', value: 'Sales' },
            { label: 'Marketing', value: 'Marketing' },
            { label: 'Customer Success', value: 'Customer Success' },
        ];
    }

    get experienceLevelOptions() {
        return [
            { label: 'Junior', value: 'Junior' },
            { label: 'Mid-Level', value: 'Mid-Level' },
            { label: 'Senior', value: 'Senior' },
            { label: 'Staff', value: 'Staff' },
        ];
    }

    get jobTypeOptions() {
        return [
            { label: 'Full-time', value: 'Full-time' },
            { label: 'Part-time', value: 'Part-time' },
            { label: 'Contract', value: 'Contract' },
            { label: 'Freelance', value: 'Freelance' },
        ];
    }

    get locationOptions() {
        return [
            { label: 'Remote', value: 'Remote' },
            { label: 'On-site', value: 'On-site' },
            { label: 'Hybrid', value: 'Hybrid' },
        ];
    }

    connectedCallback() {
        if (this.job) {
            // When editing existing job
            this.formData = {
                title: this.job.title || '',
                department: this.job.department || 'Engineering',
                experienceLevel: this.job.experience || 'Senior',
                skills: this.job._raw?.Required_Skills__c || this.job.skills || '',
                location: this.job.location || 'Remote',
                jobType: this.job.jobType || 'Full-time',
                salary: this.job.salary || '',
                email: this.job._raw?.Contact_Email__c || this.job.email || '',
            };

            // Pre-populate AI content if available
            if (this.job._raw?.Job_Description__c) {
                this.aiContent.description = this.job._raw.Job_Description__c;
            }
            if (this.job._raw?.Responsibilities__c) {
                this.aiContent.responsibilities = this.job._raw.Responsibilities__c
                    .split('\n')
                    .map((r, i) => ({ id: `resp_${i}`, text: r }));
            }
            if (this.job._raw?.Requirements__c) {
                this.aiContent.requirements = this.job._raw.Requirements__c
                    .split('\n')
                    .map((r, i) => ({ id: `req_${i}`, text: r }));
            }
        }
    }

    // Handlers
    handleInputChange(event) {
        const { name, value } = event.target;
        this.formData = { ...this.formData, [name]: value };
        this.errors[name] = null;
    }

    handleGenerateDescription() {
        this.isGenerating = true;
        
        // Simulate API call with setTimeout
        setTimeout(() => {
            // Generate description
            this.aiContent.description = PROMPT_BUFFER.generateDescription(
                this.formData.title,
                this.formData.department,
                this.formData.skills,
                this.formData.experienceLevel
            );

            // Generate responsibilities
            const responsibilities = PROMPT_BUFFER.generateResponsibilities(
                this.formData.title,
                this.formData.department
            );
            this.aiContent.responsibilities = responsibilities.map((r, i) => ({
                id: `resp_${i}`,
                text: r
            }));

            // Generate requirements
            const requirements = PROMPT_BUFFER.generateRequirements(
                this.formData.experienceLevel,
                this.formData.skills
            );
            this.aiContent.requirements = requirements.map((r, i) => ({
                id: `req_${i}`,
                text: r
            }));

            this.isGenerating = false;
        }, 800);
    }

    handleEditDescription(event) {
        this.aiContent.description = event.target.value;
    }

    handleEditResponsibility(event) {
        const index = event.target.dataset.index;
        this.aiContent.responsibilities[index].text = event.target.value;
        this.aiContent.responsibilities = [...this.aiContent.responsibilities];
    }

    handleEditRequirement(event) {
        const index = event.target.dataset.index;
        this.aiContent.requirements[index].text = event.target.value;
        this.aiContent.requirements = [...this.aiContent.requirements];
    }

    nextStep() {
        if (this.validateStep()) {
            this.currentStep++;
        }
    }

    previousStep() {
        this.currentStep--;
    }

    validateStep() {
        this.errors = {};

        if (this.isStep1) {
            if (!this.formData.title?.trim()) {
                this.errors.title = 'Job title is required';
            }
            if (!this.formData.email?.trim()) {
                this.errors.email = 'Email is required';
            } else if (!this.isValidEmail(this.formData.email)) {
                this.errors.email = 'Invalid email format';
            }
            if (!this.formData.skills?.trim()) {
                this.errors.skills = 'Required skills are required';
            }
        }

        return Object.keys(this.errors).length === 0;
    }

    isValidEmail(email) {
        const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
        return regex.test(email);
    }

    handleSave() {
        if (this.validateStep()) {
            this.isSaving = true;

            // Simulate save
            setTimeout(() => {
                const jobData = {
                    ...this.formData,
                    ...this.aiContent
                };

                this.dispatchEvent(new CustomEvent('jobsaved', {
                    detail: jobData,
                    bubbles: true,
                    composed: true
                }));

                this.isSaving = false;
            }, 600);
        }
    }

    handleCancel() {
        this.dispatchEvent(new CustomEvent('cancel', {
            bubbles: true,
            composed: true
        }));
    }
}
