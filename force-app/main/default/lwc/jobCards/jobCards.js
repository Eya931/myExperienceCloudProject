import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getJobs from '@salesforce/apex/JobController.getJobs';

const AVATAR_COLORS = [
    'avatar-red', 'avatar-purple', 'avatar-blue',
    'avatar-orange', 'avatar-green', 'avatar-teal'
];

const ACCENT_CLASSES = [
    'accent-yellow', 'accent-coral', 'accent-blue',
    'accent-green', 'accent-purple', 'accent-teal'
];

export default class JobCards extends NavigationMixin(LightningElement) {
    @track allJobs;
    @track displayedJobs;
    error;
    searchTerm = '';
    locationTerm = '';
    selectedDepartment = '';
    selectedType = '';
    selectedJob = null;
    showDetail = false;
    selectedColorIndex = 0;
    showApplicationForm = false;
    applicationJob = null;

    /* --- Wire --- */

    @wire(getJobs)
    wiredJobs({ error, data }) {
        if (data) {
            this.allJobs = data.map((job, index) => {
                const skillsList = job.Required_Skills__c
                    ? job.Required_Skills__c.split(',').map((s, i) => ({
                          id: `${job.Id}-skill-${i}`,
                          name: s.trim()
                      }))
                    : [];

                const timeAgo = this.getTimeAgo(job.CreatedDate);
                const initial = job.Name ? job.Name.charAt(0).toUpperCase() : '?';
                const avatarClass = `avatar ${AVATAR_COLORS[index % AVATAR_COLORS.length]}`;
                const accentClass = `accent ${ACCENT_CLASSES[index % ACCENT_CLASSES.length]}`;

                const formattedSalary = job.Currency__c == null
                    ? ''
                    : this.formatCurrency(job.Currency__c);

                let descriptionPreview = '';
                if (job.Job_Description__c) {
                    const truncated = job.Job_Description__c.substring(0, 120);
                    const ellipsis = job.Job_Description__c.length > 120 ? '…' : '';
                    descriptionPreview = truncated + ellipsis;
                }

                return {
                    ...job,
                    skillsList,
                    hasSkills: skillsList.length > 0,
                    timeAgo,
                    initial,
                    avatarClass,
                    accentClass,
                    formattedSalary,
                    descriptionPreview
                };
            });
            this.error = undefined;
            console.log("err");
            
            this.applyFilters();
        } else if (error) {
            this.error = error;
            console.log("this.error" + this.error);
            this.allJobs = undefined;
            this.displayedJobs = undefined;
        }
    }

    /* --- Computed --- */


    get displayedCount() {
        return this.displayedJobs ? this.displayedJobs.length : 0;
    }

    get departmentFilters() {
        if (!this.allJobs) return [];
        const depts = [...new Set(this.allJobs.map(j => j.Department__c).filter(Boolean))];
        return depts.map(d => ({
            name: d,
            className: this.selectedDepartment === d ? 'filter-btn active' : 'filter-btn'
        }));
    }

    get typeFilters() {
        if (!this.allJobs) return [];
        const types = [...new Set(this.allJobs.map(j => j.Employment_Type__c).filter(Boolean))];
        return types.map(t => ({
            name: t,
            className: this.selectedType === t ? 'filter-btn type-btn active' : 'filter-btn type-btn'
        }));
    }

    get typeOptions() {
        if (!this.allJobs) return [];
        return [...new Set(this.allJobs.map(j => j.Employment_Type__c).filter(Boolean))];
    }

    get allFilterClass() {
        return this.selectedDepartment === '' ? 'filter-btn active' : 'filter-btn';
    }

    get noResults() {
        if (!this.allJobs || !this.displayedJobs) return false;
        return this.displayedJobs.length === 0;
    }

    /* --- Handlers --- */

    handleSearchInput(event) {
        this.searchTerm = event.target.value;
        this.applyFilters();
    }

    handleLocationInput(event) {
        this.locationTerm = event.target.value;
        this.applyFilters();
    }

    handleTypeSelect(event) {
        this.selectedType = event.target.value;
        this.applyFilters();
    }

    handleFindNow() {
        this.applyFilters();
    }

    handleFilterAll() {
        this.selectedDepartment = '';
        this.applyFilters();
    }

    handleFilterDepartment(event) {
        const val = event.currentTarget.dataset.value;
        this.selectedDepartment = this.selectedDepartment === val ? '' : val;
        this.applyFilters();
    }

    handleFilterType(event) {
        const val = event.currentTarget.dataset.value;
        this.selectedType = this.selectedType === val ? '' : val;
        this.applyFilters();
    }

    applyFilters() {
        if (!this.allJobs) return;
        const term = this.searchTerm.toLowerCase();
        const locTerm = this.locationTerm.toLowerCase();

        this.displayedJobs = this.allJobs.filter(job => {
            const searchFields = [
                job.Job_Title__c, job.Required_Skills__c,
                job.Name, job.Department__c
            ];
            const matchesSearch = term === '' ||
                searchFields.filter(Boolean).some(f => f.toLowerCase().includes(term));

            const locationLower = job.Location__c?.toLowerCase() ?? '';
            const matchesLocation = locTerm === '' || locationLower.includes(locTerm);

            const matchesDept = this.selectedDepartment === '' ||
                job.Department__c === this.selectedDepartment;

            const matchesType = this.selectedType === '' ||
                job.Employment_Type__c === this.selectedType;

            return matchesSearch && matchesLocation && matchesDept && matchesType;
        });
    }

    handleJobClick(event) {
        const jobId = event.currentTarget.dataset.id;
        if (this.allJobs) {
            const idx = this.allJobs.findIndex(j => j.Id === jobId);
            if (idx !== -1) {
                this.selectedJob = this.allJobs[idx];
                this.selectedColorIndex = idx;
                this.showDetail = true;
            }
        }
    }

    handleDetailClose() {
        this.showDetail = false;
        this.selectedJob = null;
    }

    handleApply(event) {
        const jobId = event.detail?.jobId;
        this.applicationJob = this.allJobs?.find(j => j.Id === jobId) || this.selectedJob;
        this.showDetail = false;
        this.showApplicationForm = true;
    }

    handleApplicationClose() {
        this.showApplicationForm = false;
        this.applicationJob = null;
    }

    /* --- Utilities --- */

    formatCurrency(value) {
        if (value >= 1000) {
            return `$${Math.round(value / 1000)}k`;
        }
        return `$${value}`;
    }

    getTimeAgo(dateString) {
        const now = new Date();
        const date = new Date(dateString);
        const diffMs = now - date;
        const diffDays = Math.floor(diffMs / (1000 * 60 * 60 * 24));

        if (diffDays < 1) return 'Today';
        if (diffDays === 1) return '1d ago';
        if (diffDays < 7) return `${diffDays}d ago`;
        const weeks = Math.floor(diffDays / 7);
        if (weeks < 5) return `${weeks}w ago`;
        const months = Math.floor(diffDays / 30);
        return `${months}mo ago`;
    }
}
