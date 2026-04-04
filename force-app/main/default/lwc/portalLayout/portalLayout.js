import { LightningElement, track } from 'lwc';

export default class PortalLayout extends LightningElement {
    static LOGIN_URL = '/Core/login';

    @track activeSection = 'dashboard';
    @track userName = 'Amira Belhadj';
    @track userEmail = 'amira@example.com';
    @track userInitials = 'AB';
    @track sidebarCollapsed = false;
    @track currentApplicationStage = 'hr';
    @track applicationOutcome = 'pending';

    get navItems() {
        return [
            { id: 'dashboard',    label: 'Dashboard',    icon: 'utility:home',             badge: null },
            { id: 'jobs',         label: 'Jobs',         icon: 'utility:briefcase',        badge: null },
            { id: 'applications', label: 'Applications', icon: 'utility:opportunity',      badge: '1'  },
            { id: 'messages',     label: 'Messages',     icon: 'utility:email',            badge: '2'  },
            { id: 'profile',      label: 'Profile',      icon: 'utility:user',    badge: null },
            { id: 'statistics',   label: 'Statistics',   icon: 'utility:chart',            badge: null },
            { id: 'news',         label: 'Updates',      icon: 'utility:announcement',     badge: null },
        ].map(item => ({
            ...item,
            cssClass: `sb-item${item.id === this.activeSection ? ' is-active' : ''}`
        }));
    }

    get sidebarClass() {
        return `sidebar${this.sidebarCollapsed ? ' is-collapsed' : ''}`;
    }

    get currentTitle() {
        const map = {
            dashboard: 'Dashboard', search: 'Search Job', jobs: 'Job Opportunities',
            applications: 'My Applications', messages: 'Messages',
            profile: 'Profile', statistics: 'Statistics', news: 'News'
        };
        return map[this.activeSection] || 'Dashboard';
    }

    get sectionSubtitle() {
        const map = {
            dashboard: 'Overview of your activity and opportunities',
            jobs: 'Browse and apply for open positions',
            applications: 'Pipeline opportunity et entretiens planifies',
            messages: 'Read updates from recruiters and support',
            profile: 'Manage your personal and professional information',
            statistics: 'Insights about your candidate journey',
            news: 'Latest hiring updates and announcements'
        };
        return map[this.activeSection] || '';
    }

    get applicationTimeline() {
        const orderedStages = [
            {
                id: 'coding',
                label: 'Coding Game',
                icon: 'utility:einstein',
                note: 'Evaluation technique en ligne'
            },
            {
                id: 'phone',
                label: 'Entretien telephonique',
                icon: 'utility:call',
                note: 'Pre-qualification avec le recruteur'
            },
            {
                id: 'hr',
                label: 'Entretien RH',
                icon: 'utility:groups',
                note: 'Validation soft skills et culture'
            },
            {
                id: 'technical',
                label: 'Entretien technique',
                icon: 'utility:desktop',
                note: 'Discussion architecture et cas pratiques'
            },
            {
                id: 'final',
                label: 'Decision finale',
                icon: 'utility:check',
                note: 'Acceptee ou refusee selon evaluation complete'
            }
        ];

        const currentIndex = orderedStages.findIndex(stage => stage.id === this.currentApplicationStage);

        return orderedStages.map((stage, index) => {
            let stateClass = 'is-next';
            if (index < currentIndex) {
                stateClass = 'is-done';
            } else if (index === currentIndex) {
                stateClass = 'is-current';
            }
            if (stage.id === 'final' && this.applicationOutcome === 'accepted') {
                stateClass = 'is-accepted';
            }
            if (stage.id === 'final' && this.applicationOutcome === 'refused') {
                stateClass = 'is-refused';
            }

            return {
                ...stage,
                index: index + 1,
                className: `stage-item ${stateClass}`
            };
        });
    }

    get interviewNotifications() {
        return [
            {
                id: 'n1',
                type: 'Phone',
                icon: 'utility:call',
                message: 'Entretien telephonique confirme avec Talent Acquisition',
                whenText: '08 Avril 2026 - 10:30 (GMT+1)',
                status: 'Confirme',
                statusClass: 'notif-status is-confirmed'
            },
            {
                id: 'n2',
                type: 'RH',
                icon: 'utility:groups',
                message: 'Entretien RH programme avec HR Manager',
                whenText: '11 Avril 2026 - 14:00 (GMT+1)',
                status: 'Planifie',
                statusClass: 'notif-status is-planned'
            },
            {
                id: 'n3',
                type: 'Technical',
                icon: 'utility:desktop',
                message: 'Session technique prevue avec le lead engineer',
                whenText: '15 Avril 2026 - 09:00 (GMT+1)',
                status: 'A preparer',
                statusClass: 'notif-status is-pending'
            }
        ];
    }

    get acceptedClass() {
        return `decision-pill ${this.applicationOutcome === 'accepted' ? 'is-selected accepted' : ''}`;
    }

    get refusedClass() {
        return `decision-pill ${this.applicationOutcome === 'refused' ? 'is-selected refused' : ''}`;
    }

    get isDashboard()    { return this.activeSection === 'dashboard'; }
    get isJobs()         { return this.activeSection === 'jobs'; }
    get isApplications() { return this.activeSection === 'applications'; }
    get isMessages()     { return this.activeSection === 'messages'; }
    get isStatistics()   { return this.activeSection === 'statistics'; }
    get isNews()         { return this.activeSection === 'news'; }
    get isProfile()      { return this.activeSection === 'profile'; }

    handleNav(event) {
        this.activeSection = event.currentTarget.dataset.id;
    }

    toggleSidebar() {
        this.sidebarCollapsed = !this.sidebarCollapsed;
    }

    handleLogout() {
        const retUrl = encodeURIComponent(PortalLayout.LOGIN_URL);
        globalThis.location.href = `/secur/logout.jsp?retUrl=${retUrl}`;
    }
}