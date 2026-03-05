import { LightningElement, api } from 'lwc';

const AVATAR_COLORS = [
    'avatar-red', 'avatar-purple', 'avatar-blue',
    'avatar-orange', 'avatar-green', 'avatar-teal'
];

export default class JobDetails extends LightningElement {
    @api job;
    @api visible = false;
    @api colorIndex = 0;

    /* --- Computed --- */

    get initial() {
        return this.job?.Name ? this.job.Name.charAt(0).toUpperCase() : '?';
    }

    get avatarClass() {
        return `avatar ${AVATAR_COLORS[this.colorIndex % AVATAR_COLORS.length]}`;
    }

    get hasTags() {
        return this.job?.Department__c || this.job?.hasSkills;
    }

    get statusClass() {
        const base = 'status-badge';
        const status = this.job?.Status__c?.toLowerCase() ?? '';
        if (status === 'open') return `${base} status-open`;
        if (status === 'urgent') return `${base} status-urgent`;
        return base;
    }

    /* --- Handlers --- */

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleOverlayClick() {
        this.dispatchEvent(new CustomEvent('close'));
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    handleApply() {
        this.dispatchEvent(new CustomEvent('apply', {
            detail: { jobId: this.job?.Id }
        }));
    }
}
