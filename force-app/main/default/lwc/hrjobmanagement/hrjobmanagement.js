import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';

import getAllJobs       from '@salesforce/apex/HRJobController.getAllJobs';
import toggleJobStatus  from '@salesforce/apex/HRJobController.toggleJobStatus';

const DEPT_ICONS = {
    'Engineering': '⚙️', 'Product': '📋', 'Data': '🧠',
    'Design': '🎨', 'Customer Success': '⭐', 'Marketing': '📣', 'Sales': '💰',
};

const STATUS_COLORS = {
    'Active':     { bg: '#F0FFF4', color: '#276749', border: '#9AE6B4' },
    'Draft':      { bg: '#EBF8FF', color: '#2C5282', border: '#90CDF4' },
    'Reviewing':  { bg: '#FFFAF0', color: '#744210', border: '#F6AD55' },
    'Closed':     { bg: '#EDF2F7', color: '#4A5568', border: '#CBD5E0' },
};

export default class HrJobManagement extends NavigationMixin(LightningElement) {

    @track searchTerm   = '';
    @track statusFilter = '';
    @track deptFilter   = '';
    @track isLoading    = true;
    @track _rawJobs     = [];
    _wiredJobsResult;

    @wire(getAllJobs)
    wiredJobs(result) {
        this._wiredJobsResult = result;
        if (result.data) {
            this._rawJobs = result.data.map(j => this._mapJob(j));
            this.isLoading = false;
        }
    }

    // ── Computed ──────────────────────────────────────────────────────────────

    get filteredJobs() {
        return this._rawJobs.filter(j => {
            const matchSearch = !this.searchTerm
                || j.title.toLowerCase().includes(this.searchTerm.toLowerCase())
                || j.department?.toLowerCase().includes(this.searchTerm.toLowerCase());
            const matchStatus = !this.statusFilter || j.status === this.statusFilter;
            const matchDept   = !this.deptFilter   || j.department === this.deptFilter;
            return matchSearch && matchStatus && matchDept;
        });
    }

    get totalLabel() {
        const total    = this._rawJobs.length;
        const filtered = this.filteredJobs.length;
        return filtered === total
            ? `${total} total positions`
            : `${filtered} of ${total} positions`;
    }

    get isEmpty() { return this.filteredJobs.length === 0 && !this.isLoading; }

    // ── Mapping ───────────────────────────────────────────────────────────────

    _mapJob(j) {
        const colors     = STATUS_COLORS[j.Status__c] || STATUS_COLORS['Closed'];
        const isActive   = j.Status__c === 'Active';
        const skillList  = j.Required_Skills__c
            ? j.Required_Skills__c.split(',').map(s => s.trim()).slice(0, 4)
            : [];
        const posted = j.Posted_Date__c
            ? this._relativeDate(new Date(j.Posted_Date__c))
            : 'Recently';

        return {
            id:             j.Id,
            title:          j.Name,
            department:     j.Department__c,
            location:       j.Location__c    || '—',
            type:           j.Employment_Type__c || 'Full-time',
            status:         j.Status__c,
            applicants:     j.Number_of_Applicants__c != null ? j.Number_of_Applicants__c : 0,
            posted,
            skillList,
            deptIcon:       DEPT_ICONS[j.Department__c] || '📌',
            statusStyle:    `background:${colors.bg}; color:${colors.color}; border:1px solid ${colors.border}`,
            toggleLabel:    isActive ? 'Pause' : 'Activate',
            toggleBtnClass: `action-btn action-btn--toggle ${isActive ? 'action-btn--pause' : 'action-btn--activate'}`,
        };
    }

    _relativeDate(date) {
        const diff = Math.floor((new Date() - date) / 86400000);
        if (diff === 0) return 'Today';
        if (diff === 1) return '1d ago';
        if (diff < 7)   return `${diff}d ago`;
        if (diff < 30)  return `${Math.floor(diff / 7)}w ago`;
        return `${Math.floor(diff / 30)}mo ago`;
    }

    // ── Handlers ──────────────────────────────────────────────────────────────

    handleSearch(event) {
        this.searchTerm = event.target.value;
    }

    handleStatusFilter(event) {
        this.statusFilter = event.target.value;
    }

    handleDeptFilter(event) {
        this.deptFilter = event.target.value;
    }

    handleJobClick(event) {
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' },
        });
    }

    handleView(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' },
        });
    }

    handleEdit(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'edit' },
        });
    }

    async handleToggleStatus(event) {
        event.stopPropagation();
        const id        = event.currentTarget.dataset.id;
        const current   = event.currentTarget.dataset.status;
        const newStatus = current === 'Active' ? 'Closed' : 'Active';

        try {
            await toggleJobStatus({ jobId: id, newStatus });
            await refreshApex(this._wiredJobsResult);
            this.dispatchEvent(new ShowToastEvent({
                title:   'Status Updated',
                message: `Job offer set to ${newStatus}`,
                variant: 'success',
            }));
        } catch (err) {
            this.dispatchEvent(new ShowToastEvent({
                title:   'Error',
                message: err.body?.message || err.message,
                variant: 'error',
            }));
        }
    }

    handleCreateJob() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'TalentIQ_Create_Job' },
        });
    }

    stopProp(event) {
        event.stopPropagation();
    }
}