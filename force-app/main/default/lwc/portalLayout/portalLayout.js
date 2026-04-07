import { LightningElement, track } from 'lwc';
import getCurrentCandidateProfile from '@salesforce/apex/PortalController.getCurrentCandidateProfile';
import getMyApplications from '@salesforce/apex/PortalController.getMyApplications';
import getMyMessages from '@salesforce/apex/PortalController.getMyMessages';

export default class PortalLayout extends LightningElement {
    static LOGIN_URL = '/Core/login';

    @track activeSection = 'dashboard';
    @track userName = '';
    @track userEmail = '';
    @track userPhone = '';
    @track userInitials = 'AB';
    @track sidebarCollapsed = false;
    @track unreadMessagesCount = 0;
    @track applicationsCount = 0;
    @track interviewNotifications = [];
    @track profileCompletion = 0;
    @track matchingScore = 0;
    @track cvFileName = '';
    @track firstName = '';
    @track lastName = '';
    @track loadErrorMessage = '';
    @track isUserMenuOpen = false;

    connectedCallback() {
        this.loadPortalContext();
    }

    async loadPortalContext() {
        try {
            const [profileResult, applicationsResult, messagesResult] = await Promise.allSettled([
                getCurrentCandidateProfile(),
                getMyApplications(),
                getMyMessages(),
            ]);

            const profile = profileResult.status === 'fulfilled' ? (profileResult.value || {}) : {};
            const applications = applicationsResult.status === 'fulfilled' && Array.isArray(applicationsResult.value)
                ? applicationsResult.value
                : [];
            const messageList = messagesResult.status === 'fulfilled' && Array.isArray(messagesResult.value)
                ? messagesResult.value
                : [];

            this.firstName = profile?.firstName || '';
            this.lastName = profile?.lastName || '';
            this.userName = profile?.fullName || `${this.firstName} ${this.lastName}`.trim() || 'Candidate';
            this.userEmail = profile?.email || '';
            this.userPhone = profile?.phone || '';
            this.profileCompletion = profile?.profileCompletion || 0;
            this.matchingScore = profile?.matchingScore || 0;
            this.cvFileName = profile?.cvFileName || '';

            this.userInitials = this.userName
                .split(' ')
                .filter(Boolean)
                .slice(0, 2)
                .map(part => part[0])
                .join('')
                .toUpperCase() || 'C';

            this.applicationsCount = Array.isArray(applications) ? applications.length : 0;
            this.unreadMessagesCount = messageList.filter(msg => !!msg.unread).length;
            this.interviewNotifications = messageList
                .filter(msg => msg.category === 'interview')
                .slice(0, 5)
                .map(msg => ({
                    id: msg.id,
                    message: msg.subject,
                    whenText: msg.time,
                    status: msg.subject?.toLowerCase().includes('reminder') ? 'Reminder' : 'Scheduled',
                    statusClass: msg.subject?.toLowerCase().includes('reminder')
                        ? 'notif-status is-confirmed'
                        : 'notif-status is-planned'
                }));

            if (profileResult.status === 'rejected' || applicationsResult.status === 'rejected' || messagesResult.status === 'rejected') {
                const firstError = [profileResult, applicationsResult, messagesResult]
                    .find(result => result.status === 'rejected');
                const reason = firstError?.status === 'rejected' ? firstError.reason : null;
                this.loadErrorMessage = reason?.body?.message || reason?.message || 'Some portal data could not be loaded.';
            } else {
                this.loadErrorMessage = '';
            }
        } catch (e) {
            this.userName = 'Candidate';
            this.userEmail = '';
            this.loadErrorMessage = e?.body?.message || e?.message || 'Unable to load portal context.';
        }
    }

    get navItems() {
        return [
            { id: 'dashboard',    label: 'Dashboard',    icon: '🏠', badge: null },
            { id: 'applications', label: 'Applications', icon: '🧾', badge: this.applicationsCount > 0 ? String(this.applicationsCount) : null },
            { id: 'messages',     label: 'Messages',     icon: '💬', badge: this.unreadMessagesCount > 0 ? String(this.unreadMessagesCount) : null },
            { id: 'profile',      label: 'Profile',      icon: '👤', badge: null },
            { id: 'statistics',   label: 'Statistics',   icon: '📈', badge: null },
            { id: 'news',         label: 'News',         icon: '📰', badge: null },
            { id: 'assistant',    label: 'Assistant',    icon: '🤖', badge: null },
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
            dashboard: 'Dashboard',
            applications: 'My Applications', messages: 'Messages',
            profile: 'Profile', statistics: 'Statistics', news: 'News', assistant: 'Assistant'
        };
        return map[this.activeSection] || 'Dashboard';
    }

    get sectionSubtitle() {
        const map = {
            dashboard: 'Overview of your activity and opportunities',
            applications: 'Track your real opportunities and current stages',
            messages: 'Read updates from recruiters and support',
            profile: 'Manage your personal and professional information',
            statistics: 'Insights about your candidate journey',
            news: 'Latest company announcements and new job offers',
            assistant: 'Get instant help for your candidate journey'
        };
        return map[this.activeSection] || '';
    }

    get hasInterviewNotifications() {
        return this.interviewNotifications.length > 0;
    }

    get hasUnreadMessages() {
        return this.unreadMessagesCount > 0;
    }

    get isDashboard()    { return this.activeSection === 'dashboard'; }
    get isApplications() { return this.activeSection === 'applications'; }
    get isMessages()     { return this.activeSection === 'messages'; }
    get isStatistics()   { return this.activeSection === 'statistics'; }
    get isNews()         { return this.activeSection === 'news'; }
    get isProfile()      { return this.activeSection === 'profile'; }
    get isAssistant()    { return this.activeSection === 'assistant'; }

    handleNav(event) {
        this.activeSection = event.currentTarget.dataset.id;
        this.isUserMenuOpen = false;
    }

    handleChildNavigate(event) {
        const sectionId = event.detail;
        if (sectionId) {
            this.activeSection = sectionId;
            this.isUserMenuOpen = false;
        }
    }

    goToMessages() {
        this.activeSection = 'messages';
        this.isUserMenuOpen = false;
    }

    toggleUserMenu() {
        this.isUserMenuOpen = !this.isUserMenuOpen;
    }

    handleUserMenuAction(event) {
        const action = event.currentTarget.dataset.action;
        this.isUserMenuOpen = false;

        if (action === 'profile') {
            this.activeSection = 'profile';
            return;
        }
        if (action === 'logout') {
            this.handleLogout();
        }
    }

    toggleSidebar() {
        this.sidebarCollapsed = !this.sidebarCollapsed;
    }

    handleLogout() {
        const retUrl = encodeURIComponent(PortalLayout.LOGIN_URL);
        globalThis.location.href = `/secur/logout.jsp?retUrl=${retUrl}`;
    }

    handleProfileSaved() {
        this.loadPortalContext();
    }
}