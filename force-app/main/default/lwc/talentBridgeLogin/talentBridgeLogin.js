import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import login from '@salesforce/apex/LoginController.login';

export default class TalentBridgeLogin extends NavigationMixin(LightningElement) {

    @track username      = '';
    @track password      = '';
    @track errorMessage  = '';
    @track isLoading     = false;
    @track showPassword  = false;

    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        let resetToken = urlParams.get('c');

        if (!resetToken) {
            const startUrl = urlParams.get('startURL') || urlParams.get('startUrl') || '';
            if (startUrl) {
                const decoded = decodeURIComponent(startUrl);
                const match = decoded.match(/[?&]c=([^&]+)/);
                if (match) resetToken = match[1];
            }
        }

        if (resetToken) {
            // Strip garbage appended after real token (e.g. "==/login?c=")
            const slashIdx = resetToken.indexOf('/');
            const cleanToken = slashIdx > -1 ? resetToken.substring(0, slashIdx) : resetToken;
            window.location.href = '/Core/CheckPasswordResetEmail?c=' + encodeURIComponent(cleanToken);
        }
    }

    get passwordFieldType() { return this.showPassword ? 'text' : 'password'; }

    handleUsernameChange(e) { this.username = e.target.value; this.errorMessage = ''; }
    handlePasswordChange(e) { this.password = e.target.value; this.errorMessage = ''; }
    togglePasswordVisibility() { this.showPassword = !this.showPassword; }

    handleKeyDown(e) {
        if (e.key === 'Enter') this.handleLogin();
    }

    handleLogin() {
        this.errorMessage = '';

        if (!this.username.trim()) {
            this.errorMessage = "Veuillez saisir votre nom d'utilisateur.";
            return;
        }
        if (!this.password) {
            this.errorMessage = 'Veuillez saisir votre mot de passe.';
            return;
        }

        this.isLoading = true;

        login({
            username: this.username.trim(),
            password: this.password,
            startUrl: '/Core/candidate-portal'
        })
        .then(result => {
            if (result) {
                window.location.href = result;
            } else {
                this[NavigationMixin.Navigate]({
                    type: 'comm__namedPage',
                    attributes: { name: 'Candidate_Portal__c' }
                });
            }
        })
        .catch(err => {
            this.errorMessage = err.body?.message || 'Identifiants incorrects. Veuillez réessayer.';
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    handleForgotPassword() {
        this[NavigationMixin.Navigate]({
            type: 'comm__loginPage',
            attributes: { actionName: 'forgotPassword' }
        });
    }
}