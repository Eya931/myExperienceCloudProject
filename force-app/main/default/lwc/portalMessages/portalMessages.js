import { LightningElement, track } from 'lwc';
import getMessages from '@salesforce/apex/PortalController.getMyMessages';

export default class PortalMessages extends LightningElement {
    @track allMessages = [];
    @track selectedMsg = null;
    @track searchTerm = '';

    connectedCallback() {
        getMessages()
            .then(data => { this.allMessages = data; if (data.length) this.selectedMsg = data[0]; })
            .catch(() => { this.allMessages = this.demoMessages; this.selectedMsg = this.demoMessages[0]; });
    }

    get demoMessages() {
        return [
            { id:'1', from:'TalentBridge Team', subject:'Your coding test is ready', preview:'Hi Amira, please complete...', time:'2h ago', unread:true,
              body:'<p>Hi <b>Amira</b>,</p><p>Your CV passed our initial screening for <b>Senior Frontend Engineer</b>. Please complete the coding assessment within 5 days.</p><p>Access Code: <b style="color:#e8470a">TB-2025-AMB-04</b></p><p>— TalentBridge Talent Team</p>' },
            { id:'2', from:'TalentBridge Team', subject:'Welcome — Your portal credentials', preview:'Your account has been created...', time:'3h ago', unread:true,
              body:'<p>Hi <b>Amira</b>,</p><p>Welcome to your TalentBridge Candidate Portal. Your account has been created.<br/>Username: <b>amira@example.com</b><br/>Temp Password: <b style="color:#e8470a">Talent2025!</b></p><p>Please change your password on first login.</p>' },
            { id:'3', from:'TalentBridge Team', subject:'Application received — Product Designer', preview:'Thank you for applying...', time:'1w ago', unread:false,
              body:'<p>Hi <b>Amira</b>,</p><p>Thank you for applying for the <b>Product Designer</b> role. Our team will review your application within 5 business days.</p>' },
        ];
    }

    get filteredMessages() {
        const term = this.searchTerm.toLowerCase();
        return this.allMessages
            .filter(m => !term || m.subject.toLowerCase().includes(term) || m.from.toLowerCase().includes(term))
            .map(m => ({
                ...m,
                cssClass: `msg-item${m.unread ? ' unread' : ''}${m.id === (this.selectedMsg && this.selectedMsg.id) ? ' selected' : ''}`
            }));
    }

    selectMessage(event) {
        const id = event.currentTarget.dataset.id;
        this.selectedMsg = this.allMessages.find(m => m.id === id) || null;
    }

    handleSearch(event) { this.searchTerm = event.target.value; }
}