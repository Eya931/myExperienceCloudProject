import { LightningElement, track } from 'lwc';
import getMessages from '@salesforce/apex/PortalController.getMyMessages';

export default class PortalMessages extends LightningElement {
    @track allMessages = [];
    @track selectedMsg = null;
    @track searchTerm = '';

    connectedCallback() {
        getMessages()
                        .then(data => {
                                this.allMessages = Array.isArray(data) ? data : [];
                                this.selectedMsg = this.allMessages.length ? this.allMessages[0] : null;
                        })
                        .catch(() => {
                                this.allMessages = [];
                                this.selectedMsg = null;
                        });
    }

    get filteredMessages() {
        const term = this.searchTerm.toLowerCase();
        return this.allMessages
            .filter(m => !term || m.subject.toLowerCase().includes(term) || m.from.toLowerCase().includes(term))
            .map(m => ({
                ...m,
                cssClass: `msg-item${m.unread ? ' unread' : ''}${m.id === this.selectedMsg?.id ? ' selected' : ''}`
            }));
    }

    selectMessage(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedMsg = this.allMessages.find(m => m.id === id) || null;
    }

    handleSearch(event) { this.searchTerm = event.target.value; }
}