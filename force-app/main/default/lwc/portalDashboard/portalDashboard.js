import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getApplications from '@salesforce/apex/PortalController.getMyApplications';
import getMessages    from '@salesforce/apex/PortalController.getMyMessages';

export default class PortalDashboard extends NavigationMixin(LightningElement) {
    @api userName = 'Amira Belhadj';
    @track applications = [];
    @track messages = [];

    get userInitials() {
        return this.userName.split(' ').map(n => n[0]).join('').toUpperCase();
    }

    get todayDate() {
        return new Intl.DateTimeFormat('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' }).format(new Date());
    }

    get stats() {
        return [
            { id: '1', label: 'Applications',  value: this.applications.length || '2', sub: 'active processes' },
            { id: '2', label: 'Current Stage',  value: 'Coding Test',                  sub: 'Sr. Frontend Eng.' },
            { id: '3', label: 'Messages',        value: '2',                            sub: 'unread' },
            { id: '4', label: 'Profile Complete',value: '85%',                          sub: '3 fields missing' },
        ];
    }

    connectedCallback() {
        this.loadData();
    }

    loadData() {
        // Load from Apex or use demo data
        getApplications()
            .then(data => { this.applications = data; })
            .catch(() => { this.applications = this.demoApplications; });

        getMessages()
            .then(data => { this.messages = data.slice(0, 3); })
            .catch(() => { this.messages = this.demoMessages; });
    }

    get demoApplications() {
        return [
            { id: '1', initials: 'P', iconClass: 'app-ico', title: 'Senior Frontend Engineer', meta: 'Engineering · Remote', stage: 'Coding Test', badgeClass: 'app-badge b-cod' },
            { id: '2', initials: 'P', iconClass: 'app-ico ico-b', title: 'Product Designer', meta: 'Design · Hybrid Tunis', stage: 'CV Review', badgeClass: 'app-badge b-cv' },
        ];
    }

    get demoMessages() {
        return [
            { id: '1', subject: 'Your coding test is ready — Senior Frontend', unread: true },
            { id: '2', subject: 'Welcome to your Candidate Portal',             unread: true },
            { id: '3', subject: 'Application received — Product Designer',      unread: false },
        ];
    }

    goToApplications() { this.dispatchEvent(new CustomEvent('navigate', { detail: 'applications', bubbles: true, composed: true })); }
    goToMessages()     { this.dispatchEvent(new CustomEvent('navigate', { detail: 'messages',     bubbles: true, composed: true })); }
}