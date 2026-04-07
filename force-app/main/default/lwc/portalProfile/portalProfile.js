import { LightningElement, api, track } from 'lwc';
import saveProfile from '@salesforce/apex/PortalController.saveProfile';
import uploadProfileCv from '@salesforce/apex/PortalController.uploadProfileCv';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class PortalProfile extends LightningElement {
    @api userName = 'Candidate';
    @api userEmail = '';
    @api userPhone = '';
    @api firstName = '';
    @api lastName = '';
    @api matchingScore = 0;
    @api profileCompletion = 0;
    @api cvFileName = '';

    @track firstNameValue = '';
    @track lastNameValue = '';
    @track email = '';
    @track phone = '';
    @track available = true;
    @track isSaving = false;
    @track isUploadingCv = false;
    @track newCvFileName = '';
    @track newCvBase64 = '';

    connectedCallback() {
        this.firstNameValue = this.firstName || '';
        this.lastNameValue = this.lastName || '';
        this.email = this.userEmail || '';
        this.phone = this.userPhone || '';
    }

    renderedCallback() {
        if (this.firstNameValue !== this.firstName && this.firstName !== undefined) {
            this.firstNameValue = this.firstName;
        }
        if (this.lastNameValue !== this.lastName && this.lastName !== undefined) {
            this.lastNameValue = this.lastName;
        }
        if (this.email !== this.userEmail && this.userEmail !== undefined) {
            this.email = this.userEmail;
        }
        if (this.phone !== this.userPhone && this.userPhone !== undefined) {
            this.phone = this.userPhone;
        }
    }

    get userInitials() { return this.userName.split(' ').map(n => n[0]).join('').toUpperCase(); }
    get matchingLabel() { return `${this.matchingScore || 0}%`; }
    get completionLabel() { return `${this.profileCompletion || 0}%`; }
    get displayedCvName() { return this.newCvFileName || this.cvFileName || 'No CV uploaded yet'; }

    handleFirstName(e) { this.firstNameValue = e.target.value; }
    handleLastName(e)  { this.lastNameValue  = e.target.value; }
    handleEmail(e)     { this.email = e.target.value; }
    handlePhone(e)     { this.phone = e.target.value; }
    toggleAvail()      { this.available = !this.available; }
    handleCancel()     { this.dispatchEvent(new CustomEvent('cancel', { bubbles:true, composed:true })); }

    handleBrowseCv() {
        const input = this.template.querySelector('.cv-input');
        if (input) {
            input.click();
        }
    }

    handleCvFileChange(event) {
        const file = event.target.files[0];
        if (!file) {
            return;
        }

        this.newCvFileName = file.name;
        const reader = new FileReader();
        reader.onload = () => {
            this.newCvBase64 = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    async handleUploadCv() {
        if (!this.newCvBase64 || !this.newCvFileName) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing file',
                message: 'Select a CV file first.',
                variant: 'warning'
            }));
            return;
        }

        this.isUploadingCv = true;
        try {
            await uploadProfileCv({ cvFileName: this.newCvFileName, cvBase64: this.newCvBase64 });
            this.cvFileName = this.newCvFileName;
            this.newCvBase64 = '';
            this.dispatchEvent(new ShowToastEvent({
                title: 'CV updated',
                message: 'Your CV has been uploaded successfully.',
                variant: 'success'
            }));
            this.dispatchEvent(new CustomEvent('profilesaved', { bubbles: true, composed: true }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Upload failed',
                message: e?.body?.message || 'Could not upload CV.',
                variant: 'error'
            }));
        } finally {
            this.isUploadingCv = false;
        }
    }

    async handleSave() {
        this.isSaving = true;
        try {
            await saveProfile({
                firstName: this.firstNameValue,
                lastName: this.lastNameValue,
                email: this.email,
                phone: this.phone,
                available: this.available
            });
            this.dispatchEvent(new ShowToastEvent({
                title: 'Saved',
                message: 'Profile updated successfully.',
                variant: 'success'
            }));
            this.dispatchEvent(new CustomEvent('profilesaved', { bubbles: true, composed: true }));
        } catch (e) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Error',
                message: e?.body?.message || 'Could not save profile.',
                variant: 'error'
            }));
        } finally {
            this.isSaving = false;
        }
    }
}