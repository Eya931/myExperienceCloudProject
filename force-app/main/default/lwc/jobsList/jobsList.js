import { LightningElement, track } from 'lwc';
import getAllJobs from '@salesforce/apex/HRJobController.getAllJobs';
import saveJobOffer from '@salesforce/apex/HRJobController.saveJobOffer';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class JobsList extends LightningElement {
    @track showModal = false;
    @track selectedJob = null;
    @track searchTerm = '';
    @track filterDepartment = '';
    @track allJobs = [];
    @track isLoading = true;
    @track error = null;

    connectedCallback() {
        this.loadJobs();
    }

    loadJobs() {
        this.isLoading = true;
        this.error = null;

        getAllJobs()
            .then(jobs => {
                // Transform Salesforce Job__c objects to match our UI format
                this.allJobs = jobs.map(job => ({
                    id: job.Id,
                    title: job.Name,
                    department: job.Department__c,
                    location: job.Location__c,
                    salary: job.Salary_Range__c || 'Negotiable',
                    experience: job.Experience_Level__c || 'Mid-Level',
                    jobType: job.Employment_Type__c || 'Full-time',
                    description: job.Job_Description__c || 'Exciting opportunity to join our team.',
                    applicationCount: job.Number_of_Applicants__c || 0,
                    posted: this.formatDate(job.Posted_Date__c),
                    status: job.Status__c || 'Open',
                    // Store raw data for modal
                    _raw: job
                }));
                this.isLoading = false;
            })
            .catch(error => {
                this.error = error.body.message || 'Error loading jobs';
                this.allJobs = [];
                this.isLoading = false;
            });
    }

    formatDate(dateStr) {
        if (!dateStr) return 'Just now';
        const date = new Date(dateStr);
        const now = new Date();
        const diffMs = now - date;
        const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

        if (diffDays === 0) return 'Today';
        if (diffDays === 1) return 'Yesterday';
        if (diffDays < 7) return `${diffDays} days ago`;
        if (diffDays < 30) return `${Math.floor(diffDays / 7)} weeks ago`;
        return `${Math.floor(diffDays / 30)} months ago`;
    }


    get filteredJobs() {
        return this.allJobs.filter(job => {
            const matchesSearch = job.title.toLowerCase().includes(this.searchTerm.toLowerCase()) ||
                                job.department.toLowerCase().includes(this.searchTerm.toLowerCase());
            const matchesDept = !this.filterDepartment || job.department === this.filterDepartment;
            return matchesSearch && matchesDept;
        });
    }

    get departments() {
        const depts = [...new Set(this.allJobs.map(j => j.department))];
        return depts.sort();
    }

    get jobCount() {
        return this.filteredJobs.length;
    }

    openNewJobModal() {
        this.selectedJob = null;
        this.showModal = true;
    }

    openJobModal(event) {
        const jobId = event.currentTarget.dataset.jobId;
        this.selectedJob = this.allJobs.find(j => j.id === jobId);
    }

    closeModal() {
        this.showModal = false;
        this.selectedJob = null;
    }

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleDepartmentFilter(event) {
        this.filterDepartment = event.target.value;
    }

    handleJobSaved(event) {
        const newJobData = event.detail;
        
        // Save to Salesforce
        saveJobOffer({
            title: newJobData.title,
            department: newJobData.department,
            location: newJobData.location,
            employmentType: newJobData.jobType,
            experienceLevel: newJobData.experienceLevel,
            salaryRange: newJobData.salary,
            contactEmail: newJobData.email,
            requiredSkills: newJobData.skills,
            aiDescription: newJobData.description,
            responsibilities: newJobData.responsibilities?.map(r => r.text || r).join('\n'),
            requirements: newJobData.requirements?.map(r => r.text || r).join('\n'),
            status: 'Active'
        })
            .then(jobId => {
                // Reload jobs list
                this.loadJobs();
                this.closeModal();
                
                // Show success toast
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Succès',
                        message: `Job "${newJobData.title}" créé avec succès!`,
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Erreur',
                        message: error.body?.message || 'Erreur lors de la création du job',
                        variant: 'error'
                    })
                );
            });
    }
}
