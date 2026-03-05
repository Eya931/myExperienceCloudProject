import { LightningElement, wire } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import HERO_IMAGE from '@salesforce/resourceUrl/heroImage';
import getJobs from '@salesforce/apex/JobController.getJobs';
import isGuestUser from '@salesforce/user/isGuest';

export default class JobHeader extends NavigationMixin(LightningElement) {
    jobs;
    _heroRendered = false;
    isGuest = isGuestUser;

    @wire(getJobs)
    wiredJobs({ data }) {
        if (data) {
            this.jobs = data;
        }
    }

    get totalJobs() {
        return this.jobs ? this.jobs.length : 0;
    }

    get totalDepartments() {
        if (!this.jobs) return 0;
        return new Set(this.jobs.map(j => j.Department__c).filter(Boolean)).size;
    }

    get totalLocations() {
        if (!this.jobs) return 0;
        return new Set(this.jobs.map(j => j.Location__c).filter(Boolean)).size;
    }

    handleLogin() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'Login' }
        });
    }

    handleRegister() {
        this[NavigationMixin.Navigate]({
            type: 'comm__namedPage',
            attributes: { name: 'SelfRegister' }
        });
    }

    handleLogout() {
        // Experience Cloud standard logout
        const sitePrefix = globalThis.location.pathname.replace(/\/s\/.*/i, '');
        globalThis.location.href = `${sitePrefix}/secur/logout.jsp`;
    }

    renderedCallback() {
        if (!this._heroRendered) {
            const hero = this.refs.heroSection;
            if (hero) {
                hero.style.backgroundImage = `url(${HERO_IMAGE})`;
                hero.style.backgroundSize = 'cover';
                hero.style.backgroundPosition = 'center';
                this._heroRendered = true;
            }
        }
    }
}
