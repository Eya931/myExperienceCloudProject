import { LightningElement, api } from 'lwc';
import submitApplication from '@salesforce/apex/ApplicationController.submitApplication';

const MAX_FILE_SIZE = 5242880; // 5 MB
const ALLOWED_EXTENSIONS = new Set(['pdf', 'doc', 'docx', 'txt']);
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default class ApplicationForm extends LightningElement {
    @api job;
    @api visible = false;

    firstName = '';
    lastName = '';
    email = '';
    phone = '';

    cvFileName = '';
    cvFileSize = '';
    cvBase64 = '';

    isSubmitting = false;
    submitted = false;
    errorMessage = '';
    isDragging = false;

    /* --- Computed --- */

    get jobTitle() {
        return this.job?.Job_Title__c
            ? `${this.job.Job_Title__c} — ${this.job.Name}`
            : 'Position';
    }

    get dropZoneClass() {
        return this.isDragging ? 'drop-zone drag-over' : 'drop-zone';
    }

    /* --- Input handlers --- */

    handleFirstName(event) { this.firstName = event.target.value; }
    handleLastName(event)  { this.lastName = event.target.value; }
    handleEmail(event)     { this.email = event.target.value; }
    handlePhone(event)     { this.phone = event.target.value; }

    /* --- File handling --- */

    handleBrowse() {
        this.template.querySelector('input.file-input').click();
    }

    handleFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            this.processFile(file);
        }
    }

    handleDragOver(event) {
        event.preventDefault();
        this.isDragging = true;
    }

    handleDragLeave() {
        this.isDragging = false;
    }

    handleDrop(event) {
        event.preventDefault();
        this.isDragging = false;
        const file = event.dataTransfer.files[0];
        if (file) {
            this.processFile(file);
        }
    }

    processFile(file) {
        this.errorMessage = '';

        // Validate extension
        const ext = file.name.split('.').pop().toLowerCase();
        if (!ALLOWED_EXTENSIONS.has(ext)) {
            this.errorMessage = 'Invalid file type. Please upload PDF, DOC, DOCX, or TXT.';
            return;
        }

        // Validate size
        if (file.size > MAX_FILE_SIZE) {
            this.errorMessage = 'File is too large. Maximum size is 5 MB.';
            return;
        }

        this.cvFileName = file.name;
        this.cvFileSize = this.formatSize(file.size);

        const reader = new FileReader();
        reader.onload = () => {
            // result is "data:<mime>;base64,<data>" — keep only the base64 part
            this.cvBase64 = reader.result.split(',')[1];
        };
        reader.readAsDataURL(file);
    }

    handleRemoveFile() {
        this.cvFileName = '';
        this.cvFileSize = '';
        this.cvBase64 = '';
        // Reset the native input so the same file can be re-selected
        const input = this.template.querySelector('input.file-input');
        if (input) {
            input.value = '';
        }
    }

    /* --- Validation --- */

    validate() {
        if (!this.firstName.trim()) return 'First Name is required.';
        if (!this.lastName.trim()) return 'Last Name is required.';
        if (!this.email.trim()) return 'Email is required.';
        if (!EMAIL_REGEX.test(this.email.trim())) return 'Please enter a valid email address.';
        if (!this.cvBase64) return 'Please upload your CV / Resume.';
        return null;
    }

    /* --- Submit --- */

    async handleSubmit() {
        this.errorMessage = '';

        const validationError = this.validate();
        if (validationError) {
            this.errorMessage = validationError;
            return;
        }

        this.isSubmitting = true;

        try {
            await submitApplication({
                firstName: this.firstName.trim(),
                lastName: this.lastName.trim(),
                email: this.email.trim(),
                phone: this.phone.trim(),
                jobId: this.job?.Id,
                cvFileName: this.cvFileName,
                cvBase64: this.cvBase64
            });
            this.submitted = true;
        } catch (error) {
            this.errorMessage =
                error?.body?.message || 'Something went wrong. Please try again.';
        } finally {
            this.isSubmitting = false;
        }
    }

    /* --- Modal controls --- */

    handleClose() {
        this.resetForm();
        this.dispatchEvent(new CustomEvent('close'));
    }

    handleOverlayClick() {
        this.handleClose();
    }

    stopPropagation(event) {
        event.stopPropagation();
    }

    resetForm() {
        this.firstName = '';
        this.lastName = '';
        this.email = '';
        this.phone = '';
        this.cvFileName = '';
        this.cvFileSize = '';
        this.cvBase64 = '';
        this.isSubmitting = false;
        this.submitted = false;
        this.errorMessage = '';
    }

    /* --- Utilities --- */

    formatSize(bytes) {
        if (bytes < 1024) return bytes + ' B';
        if (bytes < 1048576) return (bytes / 1024).toFixed(1) + ' KB';
        return (bytes / 1048576).toFixed(1) + ' MB';
    }
}
