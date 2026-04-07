import { LightningElement, track } from 'lwc';
import getApplications from '@salesforce/apex/PortalController.getMyApplications';

const STAGE_ORDER = [
    'Application Received',
    'CV Review',
    'Coding Test',
    'HR Interview',
    'Technical Interview',
    'Final Interview',
    'Offer Extended',
    'Offer Accepted'
];

export default class PortalApplications extends LightningElement {
    @track applications = [];

    get hasApplications() {
        return this.applications.length > 0;
    }

    connectedCallback() {
        getApplications()
            .then(data => { this.applications = this.buildApps(data); })
            .catch(() => { this.applications = []; });
    }

    buildApps(data) {
        const apps = Array.isArray(data) ? data : [];
        return apps.map(app => ({
            ...app,
            currentStep: Number.isInteger(app.currentStep) ? app.currentStep : 0,
            steps: STAGE_ORDER.map((label, i) => {
                const currentStep = app.currentStep || 0;
                const isDone = i < currentStep;
                const isActive = i === currentStep;

                let circleClass = 'stp-c';
                if (isDone) {
                    circleClass += ' d';
                } else if (isActive) {
                    circleClass += ' a';
                }

                let lineClass = 'stp-line p';
                if (isDone) {
                    lineClass = 'stp-line d';
                } else if (isActive) {
                    lineClass = 'stp-line a';
                }

                return {
                    key: `${app.id}-${i}`,
                    circleKey: `${app.id}-${i}-circle`,
                    lineKey: `${app.id}-${i}-line`,
                    label: isDone ? '✓' : String(i + 1),
                    circleClass,
                    lineClass,
                    isLast: i === STAGE_ORDER.length - 1
                };
            })
        }));
    }

    viewDetails(event) {
        const id = event.currentTarget.dataset.id;
        this.dispatchEvent(new CustomEvent('viewapp', { detail: id, bubbles: true, composed: true }));
    }
}