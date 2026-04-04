import { LightningElement, track, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

// Apex
import getDashboardStats   from '@salesforce/apex/HRDashboardController.getDashboardStats';
import getRecentApps       from '@salesforce/apex/HRDashboardController.getRecentApplications';
import getTodaysInterviews from '@salesforce/apex/HRDashboardController.getTodaysInterviews';
import getOpenJobs         from '@salesforce/apex/HRDashboardController.getOpenJobs';
import getPipelineData     from '@salesforce/apex/HRDashboardController.getPipelineData';

// Stage color map
const STAGE_COLORS = {
    'Application Received': '#4A6FA5',
    'HR Interview':         '#805AD5',
    'Technical Interview':  '#D69E2E',
    'Final Interview':      '#E53E3E',
    'Offer Extended':       '#48BB78',
    'Offer Accepted':       '#38A169',
    'Rejected':             '#718096',
};

const DEPT_ICONS = {
    'Engineering':      '⚙️',
    'Product':          '📋',
    'Data':             '🧠',
    'Design':           '🎨',
    'Customer Success': '⭐',
    'Marketing':        '📣',
    'Sales':            '💰',
};

export default class HrDashboard extends NavigationMixin(LightningElement) {

    @track isLoading = true;
    @track hasNotifications = true;
    @track stats = {};
    @track _recentApps = [];
    @track _todaysInterviews = [];
    @track _openJobs = [];
    @track _pipelineData = [];

    // ── Wires ─────────────────────────────────────────────────────────────────

    @wire(getDashboardStats)
    wiredStats({ error, data }) {
        if (data) {
            this.stats = data;
            this.isLoading = false;
        }
    }

    @wire(getRecentApps)
    wiredApps({ error, data }) {
        if (data) {
            this._recentApps = data.map(a => this._mapApplication(a));
        }
    }

    @wire(getTodaysInterviews)
    wiredInterviews({ error, data }) {
        if (data) {
            this._todaysInterviews = data.map(i => this._mapInterview(i));
        }
    }

    @wire(getOpenJobs)
    wiredJobs({ error, data }) {
        if (data) {
            this._openJobs = data;
        }
    }

    @wire(getPipelineData)
    wiredPipeline({ error, data }) {
        if (data) {
            this._pipelineData = data;
        }
    }

    // ── Computed getters ──────────────────────────────────────────────────────

    get todayFormatted() {
        return new Date().toLocaleDateString('en-GB', {
            weekday: 'long', year: 'numeric', month: 'long', day: 'numeric'
        });
    }

    get statCards() {
        return [
            {
                id: 'jobs',
                label: 'Open Positions',
                value: this.stats.openJobs || '—',
                sub: `${this.stats.urgentJobs || 0} urgent`,
                icon: '💼',
                style: '--card-accent: #4A6FA5',
                barStyle: 'background: #4A6FA5; width: 65%',
            },
            {
                id: 'candidates',
                label: 'Active Candidates',
                value: this.stats.activeCandidates || '—',
                sub: `+${this.stats.newThisWeek || 0} this week`,
                icon: '👥',
                style: '--card-accent: #805AD5',
                barStyle: 'background: #805AD5; width: 78%',
            },
            {
                id: 'interviews',
                label: 'Interviews Scheduled',
                value: this.stats.scheduledInterviews || '—',
                sub: 'This week',
                icon: '📅',
                style: '--card-accent: #D69E2E',
                barStyle: 'background: #D69E2E; width: 45%',
            },
            {
                id: 'offers',
                label: 'Offers Extended',
                value: this.stats.offersExtended || '—',
                sub: 'Pending response',
                icon: '🤝',
                style: '--card-accent: #48BB78',
                barStyle: 'background: #48BB78; width: 30%',
            },
        ];
    }

    get pipelineStages() {
        const total = this._pipelineData.reduce((s, d) => s + (d.count || 0), 0) || 1;
        return this._pipelineData.map(stage => {
            const color = STAGE_COLORS[stage.name] || '#718096';
            const pct   = Math.max(4, Math.round((stage.count / total) * 100));
            return {
                name:       stage.name,
                count:      stage.count,
                dotStyle:   `background: ${color}`,
                countStyle: `color: ${color}; background: ${color}18; border-color: ${color}30`,
                fillStyle:  `width: ${pct}%; background: ${color}`,
            };
        });
    }

    get recentApplications() {
        return this._recentApps;
    }

    get todaysInterviews() {
        return this._todaysInterviews;
    }

    get interviewsTodayCount() {
        return this._todaysInterviews.length;
    }

    get noInterviewsToday() {
        return this._todaysInterviews.length === 0;
    }

    get openJobs() {
        return this._openJobs.map(j => ({
            ...j,
            deptIcon: DEPT_ICONS[j.dept] || '📌',
        }));
    }

    // ── Data mapping helpers ──────────────────────────────────────────────────

    _mapApplication(a) {
        const score  = a.aiScore || 0;
        const color  = score >= 90 ? '#48BB78' : score >= 75 ? '#4A6FA5' : score >= 60 ? '#D69E2E' : '#E53E3E';
        const r      = 14;
        const circ   = 2 * Math.PI * r;
        const dash   = (score / 100) * circ;
        const offset = circ - dash;
        const name   = `${a.firstName || ''} ${a.lastName || ''}`.trim();
        const parts  = name.split(' ');
        const inits  = parts.length >= 2 ? parts[0][0] + parts[1][0] : name.substring(0,2).toUpperCase();
        const stageColor = STAGE_COLORS[a.stage] || '#718096';

        return {
            id:              a.id,
            name,
            email:           a.email,
            role:            a.role,
            stage:           a.stage,
            score:           score,
            initials:        inits,
            avatarStyle:     `background: linear-gradient(135deg, #4A6FA5, #6C8EBF)`,
            badgeStyle:      `background: ${stageColor}18; color: ${stageColor}; border: 1px solid ${stageColor}30`,
            scoreColor:      color,
            scoreDash:       `${circ.toFixed(2)}`,
            scoreDashOffset: `${offset.toFixed(2)}`,
        };
    }

    _mapInterview(iv) {
        const dt     = iv.dateTime ? new Date(iv.dateTime) : null;
        const hour   = dt ? dt.toLocaleTimeString('en', { hour: '2-digit', minute: '2-digit', hour12: false }) : '--:--';
        const name   = iv.candidateName || 'Unknown';
        const parts  = name.split(' ');
        const inits  = parts.length >= 2 ? parts[0][0] + parts[1][0] : name.substring(0,2).toUpperCase();

        return {
            id:            iv.id,
            candidateName: name,
            round:         iv.round,
            interviewer:   iv.interviewer || 'Unassigned',
            format:        iv.format || 'Video Call',
            initials:      inits,
            hour,
            ampm:          dt ? (dt.getHours() >= 12 ? 'PM' : 'AM') : '',
            avatarStyle:   'background: linear-gradient(135deg, #805AD5, #9F7AEA)',
        };
    }

    // ── Event handlers ────────────────────────────────────────────────────────

    handleCreateJob() {
        this[NavigationMixin.Navigate]({
            type: 'standard__navItemPage',
            attributes: { apiName: 'TalentIQ_Create_Job' },
        });
    }

    handleViewCandidate(event) {
        event.stopPropagation();
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' },
        });
    }

    handleRowClick(event) {
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' },
        });
    }

    handleJobClick(event) {
        const id = event.currentTarget.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: { recordId: id, actionName: 'view' },
        });
    }

    navigateToPipeline() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Opportunity', actionName: 'list' },
        });
    }

    navigateToCandidates() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Contact', actionName: 'list' },
        });
    }

    navigateToJobs() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Job_Offer__c', actionName: 'list' },
        });
    }

    navigateToInterviews() {
        this[NavigationMixin.Navigate]({
            type: 'standard__objectPage',
            attributes: { objectApiName: 'Interview__c', actionName: 'list' },
        });
    }

    handleSearch(event) {
        if (event.key === 'Enter') {
            const term = event.target.value;
            this[NavigationMixin.Navigate]({
                type: 'standard__search',
                state: { term },
            });
        }
    }
}