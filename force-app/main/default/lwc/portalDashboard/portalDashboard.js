import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getApplications from '@salesforce/apex/PortalController.getMyApplications';
import getMessages from '@salesforce/apex/PortalController.getMyMessages';
import getCurrentCandidateProfile from '@salesforce/apex/PortalController.getCurrentCandidateProfile';

export default class PortalDashboard extends NavigationMixin(LightningElement) {
    @api userName = 'Candidate';
    @track applications = [];
    @track messages = [];
    @track profileCompletion = 0;
    @track loadErrorMessage = '';

    get userInitials() {
        return this.userName.split(' ').map(n => n[0]).join('').toUpperCase();
    }

    get todayDate() {
        return new Intl.DateTimeFormat('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }).format(new Date());
    }

    get stats() {
        const activeApp = this.applications[0];
        const unreadCount = this.messages.filter(msg => !!msg.unread).length;
        return [
            {
                id: '1',
                label: 'Applications',
                value: String(this.applications.length),
                sub: 'active processes'
            },
            {
                id: '2',
                label: 'Current Stage',
                value: activeApp?.stage || '-',
                sub: activeApp?.title || 'No active application'
            },
            {
                id: '3',
                label: 'Messages',
                value: String(unreadCount),
                sub: 'unread'
            },
            {
                id: '4',
                label: 'Profile Complete',
                value: `${this.profileCompletion}%`,
                sub: 'candidate profile'
            },
        ];
    }

    get hasApplications() {
        return this.applications.length > 0;
    }

    get hasMessages() {
        return this.messages.length > 0;
    }

    get heroSummary() {
        const activeApp = this.applications[0];
        const unreadCount = this.messages.filter(msg => !!msg.unread).length;
        if (!activeApp) {
            return 'Welcome to your candidate portal. Your active hiring stages and updates will appear here.';
        }
        return `You are currently at ${activeApp.stage || 'Application Received'} for ${activeApp.title}. ${unreadCount} unread message(s).`;
    }

    connectedCallback() {
        this.loadData();
    }

    async loadData() {
        try {
            const [applicationsResult, messagesResult, profileResult] = await Promise.allSettled([
                getApplications(),
                getMessages(),
                getCurrentCandidateProfile()
            ]);

            const applications = applicationsResult.status === 'fulfilled' && Array.isArray(applicationsResult.value)
                ? applicationsResult.value
                : [];
            const messages = messagesResult.status === 'fulfilled' && Array.isArray(messagesResult.value)
                ? messagesResult.value
                : [];
            const profile = profileResult.status === 'fulfilled' ? profileResult.value : null;

            this.applications = applications.slice(0, 4);
            this.messages = messages.slice(0, 4);
            this.profileCompletion = profile?.profileCompletion || 0;
            if (profile?.fullName) {
                this.userName = profile.fullName;
            }

            if (applicationsResult.status === 'rejected' || messagesResult.status === 'rejected' || profileResult.status === 'rejected') {
                const firstError = [applicationsResult, messagesResult, profileResult]
                    .find(result => result.status === 'rejected');
                const reason = firstError?.status === 'rejected' ? firstError.reason : null;
                this.loadErrorMessage = reason?.body?.message || reason?.message || 'Some dashboard data could not be loaded.';
            } else {
                this.loadErrorMessage = '';
            }
        } catch (e) {
            this.applications = [];
            this.messages = [];
            this.profileCompletion = 0;
            this.loadErrorMessage = e?.body?.message || e?.message || 'Unable to load dashboard data.';
        }
    }

    goToApplications() { this.dispatchEvent(new CustomEvent('navigate', { detail: 'applications', bubbles: true, composed: true })); }
    goToMessages()     { this.dispatchEvent(new CustomEvent('navigate', { detail: 'messages',     bubbles: true, composed: true })); }
}