import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import changePassword from '@salesforce/apex/CoreChangePasswordController.changePassword';

export default class ChangePassword extends NavigationMixin(LightningElement) {

    static CANDIDATE_PORTAL_URL = '/Core/candidate-portal';

    @track newPassword     = '';
    @track confirmPassword = '';
    @track errorMessage    = '';
    @track isLoading       = false;
    @track isSuccess       = false;
    @track showPassword    = false;
    @track showConfirm     = false;

    // ── Récupérer le token depuis l'URL ────────────────
    connectedCallback() {
        const urlParams = new URLSearchParams(window.location.search);
        let rawToken = urlParams.get('c') || '';
        // Strip any URL garbage appended after the real token (e.g. "==/login?c=")
        const slashIdx = rawToken.indexOf('/');
        this.resetToken = slashIdx > -1 ? rawToken.substring(0, slashIdx) : rawToken;

        if (!this.resetToken) {
            this.errorMessage = 'Lien invalide ou expiré. Veuillez redemander un accès.';
        }
    }

    // ── Field type getters ─────────────────────────────
    get passwordFieldType() { return this.showPassword ? 'text' : 'password'; }
    get confirmFieldType()  { return this.showConfirm  ? 'text' : 'password'; }

    // ── Password strength ──────────────────────────────
    get strengthScore() {
        const p = this.newPassword;
        let score = 0;
        if (p.length >= 8)              score++;
        if (/[A-Z]/.test(p))            score++;
        if (/[0-9]/.test(p))            score++;
        if (/[^A-Za-z0-9]/.test(p))     score++;
        return score;
    }

    get strengthText() {
        const s = this.strengthScore;
        if (s <= 1) return 'Faible';
        if (s === 2) return 'Moyen';
        if (s === 3) return 'Bon';
        return 'Excellent';
    }

    get strengthBarFill() {
        const s = this.strengthScore;
        if (s <= 1) return 'strength-fill strength-weak';
        if (s === 2) return 'strength-fill strength-fair';
        if (s === 3) return 'strength-fill strength-good';
        return 'strength-fill strength-strong';
    }

    get strengthLabel() {
        const s = this.strengthScore;
        if (s <= 1) return 'strength-text weak';
        if (s === 2) return 'strength-text fair';
        if (s === 3) return 'strength-text good';
        return 'strength-text strong';
    }

    // ── Rules ──────────────────────────────────────────
    get ruleMinLength() { return this._rule(this.newPassword.length >= 8); }
    get ruleUppercase() { return this._rule(/[A-Z]/.test(this.newPassword)); }
    get ruleNumber()    { return this._rule(/[0-9]/.test(this.newPassword)); }
    get ruleSpecial()   { return this._rule(/[^A-Za-z0-9]/.test(this.newPassword)); }

    _rule(passed) { return passed ? 'rule rule-pass' : 'rule'; }

    // ── Validation ─────────────────────────────────────
    get isPasswordValid() { return this.strengthScore >= 3; }

    get showMismatch() {
        return this.confirmPassword.length > 0 && this.newPassword !== this.confirmPassword;
    }

    get confirmInputClass() {
        return this.showMismatch ? 'input input-error' : 'input';
    }

    get submitBtnClass() {
        return this.isPasswordValid ? 'submit-btn' : 'submit-btn submit-btn-disabled';
    }

    // ── Handlers ───────────────────────────────────────
    handleNewPasswordChange(e)     { this.newPassword     = e.target.value; this.errorMessage = ''; }
    handleConfirmPasswordChange(e) { this.confirmPassword = e.target.value; this.errorMessage = ''; }
    togglePasswordVisibility()     { this.showPassword = !this.showPassword; }
    toggleConfirmVisibility()      { this.showConfirm  = !this.showConfirm;  }

    handleSubmit() {
        this.errorMessage = '';

        if (!this.isPasswordValid) {
            this.errorMessage = 'Le mot de passe ne respecte pas les critères de sécurité.';
            return;
        }

        if (this.newPassword !== this.confirmPassword) {
            this.errorMessage = 'Les mots de passe ne correspondent pas.';
            return;
        }

        this.isLoading = true;

        changePassword({
            newPassword: this.newPassword,
            confirmPassword: this.confirmPassword,
            token: this.resetToken
        })
            .then(() => {
                this.isSuccess = true;
                setTimeout(() => {
                    window.location.href = ChangePassword.CANDIDATE_PORTAL_URL;
                }, 1200);
            })
            .catch(err => {
                this.errorMessage = err.body?.message || 'Une erreur est survenue. Veuillez réessayer.';
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    handleGoToPortal() {
        window.location.href = ChangePassword.CANDIDATE_PORTAL_URL;
    }
}