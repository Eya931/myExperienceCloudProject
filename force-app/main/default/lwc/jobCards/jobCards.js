import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getJobs from '@salesforce/apex/JobController.getJobs';

const AVATAR_COLORS = [
    'avatar-red', 'avatar-purple', 'avatar-blue',
    'avatar-orange', 'avatar-green', 'avatar-teal'
];

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

    _lastTs        = 0;
    _pollInterval  = null;

    // ─────────────────────────────────────────────
    // Lifecycle
    // ─────────────────────────────────────────────
    connectedCallback() {
        this.loadJobs();
        this._readStoredFilters(); // apply on first load
    }

    renderedCallback() {
        // Start polling after first render — 100ms feels instant
        if (!this._pollInterval) {
            this._pollInterval = setInterval(() => {
                this._checkFilters();
            }, 100);
        }
    }

    disconnectedCallback() {
        if (this._pollInterval) {
            clearInterval(this._pollInterval);
            this._pollInterval = null;
        }
    }

    // ─────────────────────────────────────────────
    // Poll localStorage for new filters from hero
    // ─────────────────────────────────────────────
    _checkFilters() {
        try {
            const raw = localStorage.getItem('tbFilters');
            if (!raw) return;
            const f = JSON.parse(raw);
            // Only react when hero writes a new timestamp
            if (!f.ts || f.ts === this._lastTs) return;
            this._lastTs      = f.ts;
            this.searchTerm   = f.search   || '';
            this.locationTerm = f.location || '';
            this.selectedType = f.type     || '';
            this.applyFilters();
        } catch(e) { /* localStorage unavailable */ }
    }

    _readStoredFilters() {
        try {
            const raw = localStorage.getItem('tbFilters');
            if (!raw) return;
            const f = JSON.parse(raw);
            if (f.ts) this._lastTs = f.ts; // mark as seen
            if (f.search)   this.searchTerm   = f.search;
            if (f.location) this.locationTerm = f.location;
            if (f.type)     this.selectedType = f.type;
        } catch(e) { /* unavailable */ }
    }

    // ─────────────────────────────────────────────
    // Data
    // ─────────────────────────────────────────────
    loadJobs() {
        getJobs().then(data => {
            this.allJobs = data.map((job, index) => {
                const skillsList = job.Required_Skills__c
                    ? job.Required_Skills__c.split(',').map((s, i) => ({
                          id: `${job.Id}-s${i}`, name: s.trim()
                      }))
                    : [];
                const formattedSalary = job.Currency__c == null
                    ? '' : this.formatCurrency(job.Currency__c);
                return {
                    ...job, skillsList,
                    hasSkills:      skillsList.length > 0,
                    timeAgo:        this.getTimeAgo(job.CreatedDate),
                    initial:        (job.Name || '?').charAt(0).toUpperCase(),
                    avatarClass:    `avatar ${AVATAR_COLORS[index % AVATAR_COLORS.length]}`,
                    typeBadgeClass: 'type-badge ' + (TYPE_BADGE[job.Employment_Type__c] || 'badge-green'),
                    formattedSalary,
                    salaryDisplay:  formattedSalary || this.getTimeAgo(job.CreatedDate),
                    descriptionPreview: job.Job_Description__c
                        ? job.Job_Description__c.substring(0, 130) + (job.Job_Description__c.length > 130 ? '…' : '')
                        : '',
                };
            });
            this.error = undefined;
            this.applyFilters();
        })
        .catch(err => {
            this.error = err;
            this.allJobs = this.displayedJobs = undefined;
        });
    }

    // ─────────────────────────────────────────────
    // Core filter
    // ─────────────────────────────────────────────
    applyFilters() {
        if (!this.allJobs) return;
        const term    = (this.searchTerm   || '').toLowerCase().trim();
        const locTerm = (this.locationTerm || '').toLowerCase().trim();
        const type    = (this.selectedType || '').toLowerCase().trim();
        const dept    = this.selectedDepartment || '';

        this.displayedJobs = this.allJobs.filter(job => {
            const matchesSearch   = !term    || [job.Job_Title__c, job.Required_Skills__c, job.Name, job.Department__c].filter(Boolean).some(f => f.toLowerCase().includes(term));
            const matchesLocation = !locTerm || (job.Location__c || '').toLowerCase().includes(locTerm);
            const matchesDept     = !dept    || job.Department__c === dept;
            const matchesType     = !type    || (job.Employment_Type__c || '').toLowerCase().includes(type);
            return matchesSearch && matchesLocation && matchesDept && matchesType;
        });
    }

    // ─────────────────────────────────────────────
    // Computed
    // ─────────────────────────────────────────────
    get displayedCount()   { return this.displayedJobs ? this.displayedJobs.length : 0; }
    get hasActiveFilters() { return !!(this.searchTerm || this.locationTerm || this.selectedType); }
    get noResults()        { return !!(this.allJobs && this.displayedJobs && !this.displayedJobs.length); }

    get departmentFilters() {
        if (!this.allJobs) return [];
        return [...new Set(this.allJobs.map(j => j.Department__c).filter(Boolean))]
            .map(d => ({ name: d, className: `filter-btn${this.selectedDepartment === d ? ' active' : ''}` }));
    }

    get allFilterClass() {
        return `filter-btn${this.selectedDepartment === '' ? ' active' : ''}`;
    }

    // ─────────────────────────────────────────────
    // Handlers
    // ─────────────────────────────────────────────
    handleFilterAll()  { this.selectedDepartment = ''; this.applyFilters(); }
    handleRefresh()    { this.loadJobs(); }

    handleFilterDepartment(e) {
        const v = e.currentTarget.dataset.value;
        this.selectedDepartment = this.selectedDepartment === v ? '' : v;
        this.applyFilters();
    }

    handleClearFilter(e) {
        const f = e.currentTarget.dataset.filter;
        if (f === 'search')   this.searchTerm   = '';
        if (f === 'location') this.locationTerm = '';
        if (f === 'type')     this.selectedType = '';
        try { localStorage.removeItem('tbFilters'); } catch(err) { /* ignore */ }
        this.applyFilters();
    }

    handleClearAll() {
        this.searchTerm = this.locationTerm = this.selectedType = '';
        this.selectedDepartment = '';
        try { localStorage.removeItem('tbFilters'); } catch(err) { /* ignore */ }
        this.applyFilters();
    }

    handleJobClick(e) {
        const idx = this.allJobs?.findIndex(j => j.Id === e.currentTarget.dataset.id) ?? -1;
        if (idx !== -1) { this.selectedJob = this.allJobs[idx]; this.selectedColorIndex = idx; this.showDetail = true; }
    }

    handleDetailClose()      { this.showDetail = false; this.selectedJob = null; }
    handleApplicationClose() { this.showApplicationForm = false; this.applicationJob = null; }

    handleApply(e) {
        this.applicationJob      = this.allJobs?.find(j => j.Id === e.detail?.jobId) || this.selectedJob;
        this.showDetail          = false;
        this.showApplicationForm = true;
    }

    formatCurrency(v) { return v >= 1000 ? `$${Math.round(v / 1000)}k` : `$${v}`; }

    getTimeAgo(ds) {
        const d = Math.floor((Date.now() - new Date(ds)) / 86400000);
        if (d < 1) return 'Today';
        if (d === 1) return '1d ago';
        if (d < 7) return `${d}d ago`;
        const w = Math.floor(d / 7);
        return w < 5 ? `${w}w ago` : `${Math.floor(d / 30)}mo ago`;
    }
}