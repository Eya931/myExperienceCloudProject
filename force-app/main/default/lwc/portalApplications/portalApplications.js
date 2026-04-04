import { LightningElement, track } from 'lwc';
import getApplications from '@salesforce/apex/PortalController.getMyApplications';

const STAGE_ORDER = ['CV Review','Coding Test','RH Interview','Technical','Decision'];

export default class PortalApplications extends LightningElement {
    @track applications = [];

    connectedCallback() {
        getApplications()
            .then(data => { this.applications = this.buildApps(data); })
            .catch(() => { this.applications = this.buildApps(null); });
    }

    buildApps(data) {
        const demo = [
            { id:'1', initials:'P', title:'Senior Frontend Engineer', dept:'Engineering', location:'Remote', salary:'$120k–$160k', stage:'Coding Test', appliedDate:'Jan 15, 2025', badgeClass:'pip-badge b-cod', currentStep:1 },
            { id:'2', initials:'P', title:'Product Designer', dept:'Design', location:'Hybrid Tunis', salary:'$90k–$120k', stage:'CV Review', appliedDate:'Jan 8, 2025', badgeClass:'pip-badge b-cv', currentStep:0 },
        ];
        const apps = data || demo;
        return apps.map(app => ({
            ...app,
            steps: STAGE_ORDER.map((label, i) => ({
                key: `${app.id}-${i}`,
                label: i < (app.currentStep || 0) ? '✓' : String(i + 1),
                circleClass: `stp-c${i < (app.currentStep||0) ? ' d' : i === (app.currentStep||0) ? ' a' : ''}`,
                lineClass: `stp-line${i < (app.currentStep||0) ? ' d' : i === (app.currentStep||0) ? ' a' : ' p'}`,
                isLast: i === STAGE_ORDER.length - 1
            }))
        }));
    }

    viewDetails(event) {
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('viewapp', { detail: id, bubbles: true, composed: true }));
    }
}