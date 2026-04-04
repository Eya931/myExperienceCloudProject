import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference, NavigationMixin } from 'lightning/navigation';
import USER_ID from '@salesforce/user/Id';
import { getRecord, getFieldValue } from 'lightning/uiRecordApi';
import NAME_FIELD from '@salesforce/schema/User.Name';

// Apex methods
import getOpenJobsCount from '@salesforce/apex/HRDashboardController.getOpenJobsCount';
import getActiveCandidatesCount from '@salesforce/apex/HRDashboardController.getActiveCandidatesCount';
import getInterviewsTodayCount from '@salesforce/apex/HRDashboardController.getInterviewsTodayCount';

export default class HrSidebar extends NavigationMixin(LightningElement) {

    @track activeNavId = 'dashboard';

    userId = USER_ID;

    // ── Wire: current user name ──────────────────────────────────────────────
    @wire(getRecord, { recordId: '$userId', fields: [NAME_FIELD] })
    currentUser;

    get currentUserName() {
        return getFieldValue(this.currentUser.data, NAME_FIELD) || 'HR User';
    }

    get userInitials() {
        const name = this.currentUserName;
        const parts = name.split(' ');
        return parts.length >= 2
            ? parts[0][0] + parts[parts.length - 1][0]
            : name.substring(0, 2).toUpperCase();
    }

    // ── Wire: stats ───────────────────────────────────────────────────────────
    @wire(getOpenJobsCount)
    openJobsCount;

    @wire(getActiveCandidatesCount)
    activeCandidatesCount;

    @wire(getInterviewsTodayCount)
    interviewsTodayCount;

    // ── Nav link definitions ──────────────────────────────────────────────────
    get overviewLinks() {
        return [
            { id: 'dashboard',  label: 'Dashboard',  icon: '⬛', badge: null },
            { id: 'analytics',  label: 'Analytics',  icon: '📈', badge: null },
        ].map(l => this._withClass(l));
    }

    get recruitmentLinks() {
        return [
            { id: 'create-job',   label: 'Create Job',   icon: '✦',  badge: null },
            { id: 'jobs',         label: 'Job Management', icon: '💼', badge: this.openJobsCount.data || null },
            { id: 'candidates',   label: 'Candidates',   icon: '👥', badge: this.activeCandidatesCount.data || null },
            { id: 'interviews',   label: 'Interviews',   icon: '📅', badge: this.interviewsTodayCount.data || null },
            { id: 'pipeline',     label: 'Pipeline',     icon: '⚡', badge: null },
        ].map(l => this._withClass(l));
    }

    get settingsLinks() {
        return [
            { id: 'settings', label: 'Settings', icon: '⚙️', badge: null },
        ].map(l => this._withClass(l));
    }

    // Adds the correct CSS class based on active state
    _withClass(link) {
        const isActive = link.id === this.activeNavId;
        return {
            ...link,
            cssClass: `nav-item ${isActive ? 'nav-item--active' : ''}`,
        };
    }

    // ── Navigation click ──────────────────────────────────────────────────────
    handleNavClick(event) {
        const id = event.currentTarget.dataset.id;
        this.activeNavId = id;

        // Fire event so parent / other components can react
        const navEvent = new CustomEvent('navigate', { detail: { page: id } });
        this.dispatchEvent(navEvent);

        // Also navigate using NavigationMixin for standard Salesforce pages
        const pageMap = {
            'dashboard':    { type: 'standard__navItemPage', attributes: { apiName: 'TalentIQ_HR_Home' } },
            'create-job':   { type: 'standard__navItemPage', attributes: { apiName: 'TalentIQ_Create_Job' } },
            'jobs':         { type: 'standard__objectPage',  attributes: { objectApiName: 'Job_Offer__c', actionName: 'list' } },
            'candidates':   { type: 'standard__objectPage',  attributes: { objectApiName: 'Contact',      actionName: 'list' } },
            'interviews':   { type: 'standard__objectPage',  attributes: { objectApiName: 'Interview__c', actionName: 'list' } },
            'pipeline':     { type: 'standard__objectPage',  attributes: { objectApiName: 'Opportunity',  actionName: 'list' } },
            'analytics':    { type: 'standard__navItemPage', attributes: { apiName: 'TalentIQ_Analytics' } },
            'settings':     { type: 'standard__navItemPage', attributes: { apiName: 'TalentIQ_Settings'  } },
        };

        if (pageMap[id]) {
            this[NavigationMixin.Navigate](pageMap[id]);
        }
    }

    // ── Current page reference (keeps active state in sync on page load) ──────
    @wire(CurrentPageReference)
    setCurrentPageReference(ref) {
        if (!ref) return;
        const apiName = ref?.attributes?.apiName || '';
        const objectApiName = ref?.attributes?.objectApiName || '';

        if (apiName.includes('Create_Job'))        this.activeNavId = 'create-job';
        else if (objectApiName === 'Job_Offer__c') this.activeNavId = 'jobs';
        else if (objectApiName === 'Contact')      this.activeNavId = 'candidates';
        else if (objectApiName === 'Interview__c') this.activeNavId = 'interviews';
        else if (objectApiName === 'Opportunity')  this.activeNavId = 'pipeline';
        else if (apiName.includes('Analytics'))    this.activeNavId = 'analytics';
        else if (apiName.includes('Settings'))     this.activeNavId = 'settings';
        else                                        this.activeNavId = 'dashboard';
    }
}