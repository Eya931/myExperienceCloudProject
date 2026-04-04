import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin, CurrentPageReference } from 'lightning/navigation';
import getJobs from '@salesforce/apex/JobController.getJobs';

const AVATAR_COLORS = [
    'avatar-red', 'avatar-purple', 'avatar-blue',
    'avatar-orange', 'avatar-green', 'avatar-teal'
];

// Map employment type to badge color class
const TYPE_BADGE = {
    'Full-time':  'badge-blue',
    'Part-time':  'badge-orange',
    'Contract':   'badge-green',
    'Remote':     'badge-teal',
    'Internship': 'badge-purple',
    'Freelance':  'badge-yellow',
};

export default class JobCards extends NavigationMixin(LightningElement) {
    @track allJobs;
    @track displayedJobs;
    error;

    @track searchTerm         = '';
    @track locationTerm       = '';
    @track selectedDepartment = '';
    @track selectedType       = '';

    selectedJob         = null;
    showDetail          = false;
    selectedColorIndex  = 0;
    showApplicationForm = false;
    applicationJob      = null;

    // ── Read URL state from hero search ──────────────────
    @wire(CurrentPageReference)
    handlePageRef(pageRef) {
        if (!pageRef) return;
        const s = pageRef.state || {};
        let changed = false;
        if (s.search   !== undefined && s.search   !== this.searchTerm)   { this.searchTerm   = s.search   || ''; changed = true; }
        if (s.location !== undefined && s.location !== this.locationTerm) { this.locationTerm = s.location || ''; changed = true; }
        if (s.type     !== undefined && s.type     !== this.selectedType) { this.selectedType = s.type     || ''; changed = true; }
        if (changed && this.allJobs) this.applyFilters();
    }

    connectedCallback() { this.loadJobs(); }

    loadJobs() {
        getJobs().then(data => {
            this.allJobs = data.map((job, index) => {
                const skillsList = job.Required_Skills__c
                    ? job.Required_Skills__c.split(',').map((s, i) => ({ id: `${job.Id}-s${i}`, name: s.trim() }))
                    : [];

                const formattedSalary = job.Currency__c == null ? '' : this.formatCurrency(job.Currency__c);
                const salaryDisplay   = formattedSalary || this.getTimeAgo(job.CreatedDate);

                const typeBadgeClass = 'type-badge ' + (TYPE_BADGE[job.Employment_Type__c] || 'badge-blue');

                let descriptionPreview = '';
                if (job.Job_Description__c) {
                    descriptionPreview = job.Job_Description__c.substring(0, 130)
                        + (job.Job_Description__c.length > 130 ? '…' : '');
                }

                return {
                    ...job,
                    skillsList,
                    hasSkills:        skillsList.length > 0,
                    timeAgo:          this.getTimeAgo(job.CreatedDate),
                    initial:          job.Name ? job.Name.charAt(0).toUpperCase() : '?',
                    avatarClass:      `avatar ${AVATAR_COLORS[index % AVATAR_COLORS.length]}`,
                    typeBadgeClass,
                    formattedSalary,
                    salaryDisplay,
                    descriptionPreview,
                };
            });
            this.error = undefined;
            this.applyFilters();
        })
        .catch(err => {
            this.error = err;
            this.allJobs = undefined;
            this.displayedJobs = undefined;
        });
    }

    // ── Computed ─────────────────────────────────────────
    get displayedCount() { return this.displayedJobs ? this.displayedJobs.length : 0; }

    get hasActiveFilters() { return !!(this.searchTerm || this.locationTerm || this.selectedType); }

    get departmentFilters() {
        if (!this.allJobs) return [];
        return [...new Set(this.allJobs.map(j => j.Department__c).filter(Boolean))]
            .map(d => ({ name: d, className: this.selectedDepartment === d ? 'filter-btn active' : 'filter-btn' }));
    }

    get allFilterClass() { return this.selectedDepartment === '' ? 'filter-btn active' : 'filter-btn'; }

    get noResults() { return !!(this.allJobs && this.displayedJobs && this.displayedJobs.length === 0); }

    // ── Filter handlers ───────────────────────────────────
    handleFilterAll()           { this.selectedDepartment = ''; this.applyFilters(); }
    handleFilterDepartment(e)   { const v = e.currentTarget.dataset.value; this.selectedDepartment = this.selectedDepartment === v ? '' : v; this.applyFilters(); }
    handleRefresh()             { this.loadJobs(); }

    handleClearFilter(e) {
        const f = e.currentTarget.dataset.filter;
        if (f === 'search')   this.searchTerm   = '';
        if (f === 'location') this.locationTerm = '';
        if (f === 'type')     this.selectedType = '';
        this.applyFilters();
    }

    handleClearAll() { this.searchTerm = ''; this.locationTerm = ''; this.selectedType = ''; this.applyFilters(); }

    applyFilters() {
        if (!this.allJobs) return;
        const term    = this.searchTerm.toLowerCase();
        const locTerm = this.locationTerm.toLowerCase();

        this.displayedJobs = this.allJobs.filter(job => {
            const matchesSearch   = !term   || [job.Job_Title__c, job.Required_Skills__c, job.Name, job.Department__c].filter(Boolean).some(f => f.toLowerCase().includes(term));
            const matchesLocation = !locTerm || (job.Location__c?.toLowerCase() ?? '').includes(locTerm);
            const matchesDept     = !this.selectedDepartment || job.Department__c === this.selectedDepartment;
            const matchesType     = !this.selectedType       || job.Employment_Type__c === this.selectedType;
            return matchesSearch && matchesLocation && matchesDept && matchesType;
        });
    }

    // ── Card / modal handlers ─────────────────────────────
    handleJobClick(e) {
        const idx = this.allJobs?.findIndex(j => j.Id === e.currentTarget.dataset.id) ?? -1;
        if (idx !== -1) { this.selectedJob = this.allJobs[idx]; this.selectedColorIndex = idx; this.showDetail = true; }
    }

    handleDetailClose()   { this.showDetail = false; this.selectedJob = null; }
    handleApplicationClose() { this.showApplicationForm = false; this.applicationJob = null; }

    handleApply(e) {
        this.applicationJob      = this.allJobs?.find(j => j.Id === e.detail?.jobId) || this.selectedJob;
        this.showDetail          = false;
        this.showApplicationForm = true;
    }

    // ── Utilities ─────────────────────────────────────────
    formatCurrency(v) { return v >= 1000 ? `$${Math.round(v / 1000)}k` : `$${v}`; }

    getTimeAgo(ds) {
        const d = Math.floor((new Date() - new Date(ds)) / 86400000);
        if (d < 1) return 'Today';
        if (d === 1) return '1d ago';
        if (d < 7) return `${d}d ago`;
        const w = Math.floor(d / 7);
        return w < 5 ? `${w}w ago` : `${Math.floor(d / 30)}mo ago`;
    }
}