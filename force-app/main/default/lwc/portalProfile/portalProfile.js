import { LightningElement, api, track } from 'lwc';
import saveProfile from '@salesforce/apex/PortalController.saveProfile';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PortalProfile extends LightningElement {
    @api userName  = 'Amira Belhadj';
    @api userEmail = 'amira@example.com';
    @track firstName = 'Amira';
    @track lastName  = 'Belhadj';
    @track available = true;

    get userInitials() { return this.userName.split(' ').map(n => n[0]).join('').toUpperCase(); }

    handleFirstName(e) { this.firstName = e.target.value; }
    handleLastName(e)  { this.lastName  = e.target.value; }
    toggleAvail()      { this.available = !this.available; }
    handleCancel()     { this.dispatchEvent(new CustomEvent('cancel', { bubbles:true, composed:true })); }

    handleSave() {
        saveProfile({ firstName: this.firstName, lastName: this.lastName, available: this.available })
            .then(() => {
                this.dispatchEvent(new ShowToastEvent({ title:'Saved', message:'Profile updated successfully.', variant:'success' }));
            })
            .catch(() => {
                this.dispatchEvent(new ShowToastEvent({ title:'Error', message:'Could not save profile.', variant:'error' }));
            });
    }
}